using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Categoría de los clientes según lo que compraron en el ciclo anterior.
///
/// La categoría se calcula una vez por ciclo y queda fija hasta el siguiente: no se mueve con cada
/// venta. Cada cálculo guarda lo que se evaluó y lo que compró cada cliente, así queda el historial
/// aunque después se cambien los tramos.
///
/// Un cliente es de la categoría más alta cuyo "desde" no pasa de lo que compró. Los activos sin
/// compras en el ciclo quedan en la última (F · Inactivo), que arranca en cero.
/// </summary>
public class CategorizacionService : ICategorizacionService
{
    private static readonly string[] Codigos = ["A", "B", "C", "D", "E", "F"];

    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;
    private readonly IValidator<GuardarCategorizacionRequest> _validator;
    private readonly INotificador _notificador;

    public CategorizacionService(
        AppDbContext context,
        IPermisoService permisos,
        IUsuarioActual usuarioActual,
        IValidator<GuardarCategorizacionRequest> validator,
        INotificador notificador)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
        _validator = validator;
        _notificador = notificador;
    }

    // ------------------------------------------------------------- Configuración

    public async Task<CategorizacionResponse> ObtenerAsync()
    {
        var config = await ConfiguracionAsync();
        var categorias = await _context.CategoriasCliente.AsNoTracking()
            .OrderBy(c => c.Codigo)
            .ToListAsync();

        var hoy = Zona.Hoy;
        var vigente = await CategorizacionConsultas.VigenteAsync(_context, hoy);

        var conteo = vigente is null
            ? []
            : await _context.ClientesCategoria.AsNoTracking()
                .Where(c => c.CalculoId == vigente.Id)
                .GroupBy(c => c.Codigo)
                .Select(g => new { Codigo = g.Key, Clientes = g.Count() })
                .ToDictionaryAsync(x => x.Codigo, x => x.Clientes);

        var respuesta = new CategorizacionResponse
        {
            Ciclo = config.Ciclo,
            Ventana = Ventana(CicloCategorizacion.Ventana(config.Ciclo, hoy)),
            // "Hasta" es el "desde" de la categoría de arriba, menos un sol.
            Categorias = categorias.Select((c, i) => new CategoriaClienteResponse
            {
                Codigo = c.Codigo,
                Nombre = c.Nombre,
                Color = c.Color,
                Desde = c.Desde,
                Hasta = i == 0 ? null : categorias[i - 1].Desde - 1,
                Clientes = conteo.GetValueOrDefault(c.Codigo),
            }).ToList(),
        };

        if (vigente is not null)
        {
            var usuario = vigente.UsuarioId is int uid
                ? await _context.Usuarios.AsNoTracking().Where(u => u.Id == uid).Select(u => u.Nombre).FirstOrDefaultAsync()
                : null;

            respuesta.Vigente = new CalculoVigenteResponse
            {
                Id = vigente.Id,
                Ciclo = vigente.Ciclo,
                Ventana = new CategorizacionVentanaResponse
                {
                    EvaluadoDesde = vigente.EvaluadoDesde,
                    EvaluadoHasta = vigente.EvaluadoHasta,
                    VigenteDesde = vigente.VigenteDesde,
                    VigenteHasta = vigente.VigenteHasta,
                },
                CalculadoEn = vigente.CalculadoEn,
                Automatico = vigente.Automatico,
                Usuario = usuario,
                Clientes = vigente.Clientes,
                Vencido = vigente.VigenteHasta < hoy,
            };
            respuesta.CicloDistinto = vigente.Ciclo != config.Ciclo;
        }

        return respuesta;
    }

    public async Task<CategorizacionResponse> GuardarAsync(GuardarCategorizacionRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        // Con un código repetido ToDictionary reventaría: se revisa antes.
        var letras = request.Categorias.Select(c => c.Codigo.Trim().ToUpperInvariant()).ToList();
        if (letras.Distinct().Count() != Codigos.Length || !Codigos.All(letras.Contains))
            throw new BadRequestException("Tienen que ser las seis categorías, de la A a la F");

        var enviadas = request.Categorias.ToDictionary(c => c.Codigo.Trim().ToUpperInvariant());

        // De la A a la F el monto baja: si no, un cliente podría caer en una categoría "más alta" con
        // menos compras. La última arranca en cero para que nadie se quede sin categoría.
        for (var i = 1; i < Codigos.Length; i++)
        {
            if (enviadas[Codigos[i]].Desde >= enviadas[Codigos[i - 1]].Desde)
                throw new BadRequestException(
                    $"El monto de la {Codigos[i]} tiene que ser menor que el de la {Codigos[i - 1]}");
        }
        if (enviadas["F"].Desde != 0)
            throw new BadRequestException("La última categoría tiene que empezar en cero");

        var categorias = await _context.CategoriasCliente.ToListAsync();
        foreach (var categoria in categorias)
        {
            var nueva = enviadas[categoria.Codigo];
            categoria.Nombre = nueva.Nombre.Trim();
            categoria.Color = nueva.Color;
            categoria.Desde = nueva.Desde;
        }

        var config = await ConfiguracionAsync(rastrear: true);
        config.Ciclo = request.Ciclo;
        config.ActualizadoEn = DateTime.UtcNow;
        config.UsuarioId = _usuarioActual.Id;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("categorizacion", "configurada");
        return await ObtenerAsync();
    }

    // ------------------------------------------------------------- Cálculo

    public async Task<CategorizacionResponse> CalcularAsync()
    {
        await CalcularCicloAsync(automatico: false);
        return await ObtenerAsync();
    }

    public async Task<bool> CalcularSiCorrespondeAsync()
    {
        // Antes del primer cálculo no se hace nada solo: ponerlo en marcha lo decide una persona.
        if (!await _context.CalculosCategorizacion.AnyAsync()) return false;

        var config = await ConfiguracionAsync();
        var ventana = CicloCategorizacion.Ventana(config.Ciclo, Zona.Hoy);

        var yaCalculado = await _context.CalculosCategorizacion.AnyAsync(
            c => c.Ciclo == config.Ciclo && c.VigenteDesde == ventana.VigenteDesde);
        if (yaCalculado) return false;

        await CalcularCicloAsync(automatico: true);
        return true;
    }

    private async Task CalcularCicloAsync(bool automatico)
    {
        var config = await ConfiguracionAsync();
        var hoy = Zona.Hoy;
        var ventana = CicloCategorizacion.Ventana(config.Ciclo, hoy);

        // De la más alta a la más baja: la primera cuyo "desde" no pasa de lo comprado.
        var categorias = await _context.CategoriasCliente.AsNoTracking()
            .OrderByDescending(c => c.Desde)
            .ToListAsync();

        var ventas = await CategorizacionConsultas.VentasNetasAsync(
            _context, Zona.AUtc(ventana.EvaluadoDesde), Zona.AUtc(ventana.EvaluadoHasta.AddDays(1)));
        var clientes = await _context.Clientes.AsNoTracking().Where(c => c.Activo).Select(c => c.Id).ToListAsync();

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        // Calcular de nuevo en el mismo ciclo reemplaza al anterior en vez de dejar dos.
        var previos = await _context.CalculosCategorizacion
            .Where(c => c.Ciclo == config.Ciclo && c.VigenteDesde == ventana.VigenteDesde)
            .ToListAsync();
        _context.CalculosCategorizacion.RemoveRange(previos);

        var calculo = new CalculoCategorizacion
        {
            Ciclo = config.Ciclo,
            EvaluadoDesde = ventana.EvaluadoDesde,
            EvaluadoHasta = ventana.EvaluadoHasta,
            VigenteDesde = ventana.VigenteDesde,
            VigenteHasta = ventana.VigenteHasta,
            CalculadoEn = DateTime.UtcNow,
            Automatico = automatico,
            UsuarioId = automatico ? null : _usuarioActual.Id,
            Clientes = clientes.Count,
        };
        _context.CalculosCategorizacion.Add(calculo);
        await _context.SaveChangesAsync();

        _context.ClientesCategoria.AddRange(clientes.Select(id =>
        {
            // Una devolución grande puede dejar el neto en negativo: cuenta como cero.
            var monto = Math.Round(Math.Max(0m, ventas.GetValueOrDefault(id)), 2);
            return new ClienteCategoria
            {
                CalculoId = calculo.Id,
                ClienteId = id,
                Monto = monto,
                Codigo = categorias.First(c => c.Desde <= monto).Codigo,
            };
        }));
        await _context.SaveChangesAsync();

        await transaccion.CommitAsync();
        await _notificador.AvisarAsync("categorizacion", "calculada", new { calculoId = calculo.Id });
    }

    // ------------------------------------------------------------- Clientes

    public async Task<List<ClienteCategoriaResponse>> ClientesAsync()
    {
        var vigente = await CategorizacionConsultas.VigenteAsync(_context, Zona.Hoy);
        if (vigente is null) return [];

        // El cálculo anterior: el que regía antes que el vigente. Puede tener la misma fecha de inicio si se
        // cambió el ciclo a mitad de camino y se calculó de nuevo.
        var anterior = await _context.CalculosCategorizacion.AsNoTracking()
            .Where(c => c.Id != vigente.Id && c.VigenteDesde <= vigente.VigenteDesde)
            .OrderByDescending(c => c.VigenteDesde).ThenByDescending(c => c.CalculadoEn)
            .FirstOrDefaultAsync();

        var previas = anterior is null
            ? []
            : await _context.ClientesCategoria.AsNoTracking()
                .Where(c => c.CalculoId == anterior.Id)
                .ToDictionaryAsync(c => c.ClienteId, c => c.Codigo);

        var visibles = await ClientesVisiblesAsync();

        var filas = await (
                from cc in _context.ClientesCategoria.AsNoTracking()
                where cc.CalculoId == vigente.Id
                join c in visibles on cc.ClienteId equals c.Id
                select new
                {
                    c.Id,
                    c.Documento,
                    c.Nombre,
                    Ruta = c.Ruta != null ? c.Ruta.Nombre : null,
                    Mercado = c.Mercado != null ? c.Mercado.Nombre : null,
                    cc.Codigo,
                    cc.Monto,
                })
            .ToListAsync();

        return filas
            .Select(f => new ClienteCategoriaResponse
            {
                ClienteId = f.Id,
                Codigo = $"CLI{f.Id:D5}",
                Documento = f.Documento,
                Nombre = f.Nombre,
                Ruta = f.Ruta,
                Mercado = f.Mercado,
                Categoria = f.Codigo,
                Monto = f.Monto,
                CategoriaAnterior = previas.GetValueOrDefault(f.Id),
                Movimiento = Movimiento(anterior is not null, previas.GetValueOrDefault(f.Id), f.Codigo),
            })
            .OrderByDescending(f => f.Monto)
            .ThenBy(f => f.Nombre)
            .ToList();
    }

    /// <summary>A es la más alta: una letra "menor" es una categoría mejor.</summary>
    private static string Movimiento(bool hayAnterior, string? antes, string ahora)
    {
        if (!hayAnterior) return string.Empty;
        if (antes is null) return "NUEVO";

        var comparacion = string.CompareOrdinal(ahora, antes);
        return comparacion == 0 ? "IGUAL" : comparacion < 0 ? "SUBE" : "BAJA";
    }

    // ------------------------------------------------------------- Ayudas

    private async Task<ConfiguracionCategorizacion> ConfiguracionAsync(bool rastrear = false)
    {
        var consulta = rastrear ? _context.ConfiguracionesCategorizacion : _context.ConfiguracionesCategorizacion.AsNoTracking();
        return await consulta.OrderBy(c => c.Id).FirstOrDefaultAsync()
            ?? throw new NotFoundException("Falta la configuración de categorización: aplica las migraciones.");
    }

    private static CategorizacionVentanaResponse Ventana(VentanaCiclo v) => new()
    {
        EvaluadoDesde = v.EvaluadoDesde,
        EvaluadoHasta = v.EvaluadoHasta,
        VigenteDesde = v.VigenteDesde,
        VigenteHasta = v.VigenteHasta,
    };

    /// <summary>Los clientes que quien pregunta puede ver: el mismo alcance que la Cartera en riesgo.</summary>
    private async Task<IQueryable<Cliente>> ClientesVisiblesAsync()
    {
        var clientes = _context.Clientes.AsNoTracking();
        if (_usuarioActual.Id is not int uid) return clientes;

        var alcance = await _permisos.AlcanceFiltroAsync(uid, "crm.cartera");
        if (alcance.SinRestriccion) return clientes;

        var rutas = alcance.RutaIds;
        var propio = alcance.UsuarioId;
        return clientes.Where(c => c.VendedorId == propio || (c.RutaId != null && rutas.Contains(c.RutaId.Value)));
    }
}
