using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

public class GastoOperativoService : IGastoOperativoService
{
    private readonly AppDbContext _context;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IValidator<CategoriaMovimientoRequest> _categoriaValidator;
    private readonly IValidator<GastoRecurrenteRequest> _recurrenteValidator;
    private readonly IValidator<MovimientoOperativoRequest> _movimientoValidator;
    private readonly INotificador _notificador;

    public GastoOperativoService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IValidator<CategoriaMovimientoRequest> categoriaValidator,
        IValidator<GastoRecurrenteRequest> recurrenteValidator,
        IValidator<MovimientoOperativoRequest> movimientoValidator,
        INotificador notificador)
    {
        _context = context;
        _cuentas = cuentas;
        _categoriaValidator = categoriaValidator;
        _recurrenteValidator = recurrenteValidator;
        _movimientoValidator = movimientoValidator;
        _notificador = notificador;
    }

    // ---------------------------------------------------------- Categorías

    public async Task<IEnumerable<CategoriaMovimientoResponse>> GetCategoriasAsync()
    {
        var categorias = await _context.MotivosGasto
            .AsNoTracking()
            .OrderBy(m => m.Tipo).ThenBy(m => m.Nombre)
            .ToListAsync();

        var respuesta = new List<CategoriaMovimientoResponse>();
        foreach (var c in categorias)
        {
            respuesta.Add(MapCategoria(c, await ContarUsosCategoriaAsync(c.Id)));
        }

        return respuesta;
    }

    public async Task<IEnumerable<CategoriaOpcionResponse>> GetCategoriasOpcionesAsync(string? tipo)
    {
        var query = _context.MotivosGasto.AsNoTracking().Where(m => m.Activo && !m.EsSistema);
        if (!string.IsNullOrWhiteSpace(tipo)) query = query.Where(m => m.Tipo == tipo);

        return await query
            .OrderBy(m => m.Nombre)
            .Select(m => new CategoriaOpcionResponse { Id = m.Id, Nombre = m.Nombre, Tipo = m.Tipo, Origen = m.Origen })
            .ToListAsync();
    }

    public async Task<CategoriaMovimientoResponse> CrearCategoriaAsync(CategoriaMovimientoRequest request)
    {
        await _categoriaValidator.ValidateAndThrowAsync(request);

        var nombre = request.Nombre.Trim();
        if (await _context.MotivosGasto.AnyAsync(m => m.Nombre == nombre))
        {
            throw new ConflictException("Ya existe una categoría con ese nombre");
        }

        var categoria = new MotivoGasto();
        AplicarCategoria(categoria, request);

        _context.MotivosGasto.Add(categoria);
        await _context.SaveChangesAsync();

        var response = MapCategoria(categoria, 0);
        await _notificador.AvisarAsync("gastosoperativos", "categoriaCreada", response);
        return response;
    }

    public async Task<CategoriaMovimientoResponse> ActualizarCategoriaAsync(int id, CategoriaMovimientoRequest request)
    {
        await _categoriaValidator.ValidateAndThrowAsync(request);

        var categoria = await _context.MotivosGasto.FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException($"No existe la categoría {id}");
        ExigirNoSistema(categoria);

        var nombre = request.Nombre.Trim();
        if (await _context.MotivosGasto.AnyAsync(m => m.Nombre == nombre && m.Id != id))
        {
            throw new ConflictException("Ya existe una categoría con ese nombre");
        }

        var usos = await ContarUsosCategoriaAsync(id);

        // Lo ya registrado quedaría con una categoría de ingreso en un egreso
        // (o al revés). El origen sí se puede corregir: solo reclasifica.
        if (usos > 0 && categoria.Tipo != request.Tipo)
        {
            throw new BadRequestException(
                "Esta categoría ya se usa: no se le puede cambiar el tipo. Crea otra.");
        }

        AplicarCategoria(categoria, request);
        await _context.SaveChangesAsync();

        var response = MapCategoria(categoria, usos);
        await _notificador.AvisarAsync("gastosoperativos", "categoriaActualizada", response);
        return response;
    }

    public async Task EliminarCategoriaAsync(int id)
    {
        var categoria = await _context.MotivosGasto.FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException($"No existe la categoría {id}");
        ExigirNoSistema(categoria);

        var usos = await ContarUsosCategoriaAsync(id);
        if (usos > 0)
        {
            throw new BadRequestException(
                $"La categoría se usa en {usos} registro(s). Desactívala en vez de eliminarla.");
        }

        _context.MotivosGasto.Remove(categoria);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("gastosoperativos", "categoriaEliminada", new { id });
    }

    // ---------------------------------------------------------- Plantillas

    public async Task<IEnumerable<GastoRecurrenteResponse>> GetRecurrentesAsync()
    {
        var recurrentes = await _context.GastosRecurrentes
            .AsNoTracking()
            .Include(g => g.MotivoGasto)
            .Include(g => g.CuentaFinancieraSugerida)
            .OrderByDescending(g => g.Activo)
            .ThenBy(g => g.Nombre)
            .ToListAsync();

        return recurrentes.Select(MapRecurrente);
    }

    public async Task<GastoRecurrenteResponse> CrearRecurrenteAsync(GastoRecurrenteRequest request)
    {
        await _recurrenteValidator.ValidateAndThrowAsync(request);
        await ValidarCategoriaAsync(request.MotivoGastoId, TipoMovimientoOperativo.Egreso);
        await ValidarCuentaSugeridaAsync(request.CuentaFinancieraSugeridaId);

        var recurrente = new GastoRecurrente();
        AplicarRecurrente(recurrente, request);

        _context.GastosRecurrentes.Add(recurrente);
        await _context.SaveChangesAsync();

        var response = await GetRecurrenteOrThrowAsync(recurrente.Id);
        await _notificador.AvisarAsync("gastosoperativos", "recurrenteCreado", response);
        return response;
    }

    public async Task<GastoRecurrenteResponse> ActualizarRecurrenteAsync(int id, GastoRecurrenteRequest request)
    {
        await _recurrenteValidator.ValidateAndThrowAsync(request);
        await ValidarCategoriaAsync(request.MotivoGastoId, TipoMovimientoOperativo.Egreso);
        await ValidarCuentaSugeridaAsync(request.CuentaFinancieraSugeridaId);

        var recurrente = await _context.GastosRecurrentes.FirstOrDefaultAsync(g => g.Id == id)
            ?? throw new NotFoundException($"No existe el gasto recurrente {id}");

        AplicarRecurrente(recurrente, request);
        await _context.SaveChangesAsync();

        var response = await GetRecurrenteOrThrowAsync(id);
        await _notificador.AvisarAsync("gastosoperativos", "recurrenteActualizado", response);
        return response;
    }

    public async Task EliminarRecurrenteAsync(int id)
    {
        var recurrente = await _context.GastosRecurrentes.FirstOrDefaultAsync(g => g.Id == id)
            ?? throw new NotFoundException($"No existe el gasto recurrente {id}");

        if (await _context.MovimientosOperativos.AnyAsync(m => m.GastoRecurrenteId == id))
        {
            throw new BadRequestException(
                "Ya tiene pagos registrados. Desactívalo en vez de eliminarlo.");
        }

        _context.GastosRecurrentes.Remove(recurrente);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("gastosoperativos", "recurrenteEliminado", new { id });
    }

    public async Task<IEnumerable<GastoPendienteResponse>> GetPendientesAsync()
    {
        var hoy = Zona.Hoy;
        var diasEnMes = DateTime.DaysInMonth(hoy.Year, hoy.Month);

        var recurrentes = await _context.GastosRecurrentes
            .AsNoTracking()
            .Include(g => g.MotivoGasto)
            .Where(g => g.Activo)
            .ToListAsync();

        var pendientes = new List<GastoPendienteResponse>();

        foreach (var g in recurrentes)
        {
            var yaPagado = await _context.MovimientosOperativos.AnyAsync(m =>
                m.GastoRecurrenteId == g.Id && !m.Anulado
                && m.Fecha.Year == hoy.Year && m.Fecha.Month == hoy.Month);

            if (yaPagado) continue;

            var dia = Math.Min(g.DiaVencimiento, diasEnMes);
            var vencimiento = new DateTime(hoy.Year, hoy.Month, dia);

            pendientes.Add(new GastoPendienteResponse
            {
                GastoRecurrenteId = g.Id,
                Nombre = g.Nombre,
                MotivoGastoId = g.MotivoGastoId,
                MotivoGasto = g.MotivoGasto?.Nombre ?? string.Empty,
                MontoEstimado = g.MontoEstimado,
                CuentaFinancieraSugeridaId = g.CuentaFinancieraSugeridaId,
                ProximoVencimiento = vencimiento,
                Vencido = vencimiento < hoy,
            });
        }

        return pendientes.OrderBy(p => p.ProximoVencimiento).ToList();
    }

    // ---------------------------------------------------------- Movimientos

    public async Task<IEnumerable<MovimientoOperativoResponse>> ListarAsync(DateTime desde, DateTime hasta)
    {
        var movimientos = await _context.MovimientosOperativos
            .AsNoTracking()
            .Include(m => m.CuentaFinanciera)
            .Include(m => m.MotivoGasto)
            .Include(m => m.Usuario)
            .Where(m => m.Fecha >= desde.Date && m.Fecha < hasta.Date.AddDays(1))
            .OrderByDescending(m => m.Fecha).ThenByDescending(m => m.Id)
            .ToListAsync();

        return movimientos.Select(Map);
    }

    public async Task<MovimientoOperativoResponse> CrearAsync(MovimientoOperativoRequest request, int? usuarioId, bool delSistema = false)
    {
        await _movimientoValidator.ValidateAndThrowAsync(request);
        await ValidarCategoriaAsync(request.MotivoGastoId, request.Tipo, delSistema);

        var cuenta = await _cuentas.GetOrThrowAsync(request.CuentaFinancieraId);
        if (!cuenta.Activo) throw new BadRequestException("Esa cuenta está desactivada");

        GastoRecurrente? plantilla = null;
        if (request.GastoRecurrenteId is int recurrenteId)
        {
            plantilla = await _context.GastosRecurrentes.FirstOrDefaultAsync(g => g.Id == recurrenteId)
                ?? throw new BadRequestException("Ese gasto recurrente no existe");
        }

        var fecha = request.Fecha ?? DateTime.UtcNow;

        var movimiento = new MovimientoOperativo
        {
            CuentaFinancieraId = cuenta.Id,
            Tipo = request.Tipo,
            MotivoGastoId = request.MotivoGastoId,
            Monto = request.Monto,
            Fecha = fecha,
            Descripcion = request.Descripcion?.Trim(),
            GastoRecurrenteId = plantilla?.Id,
            UsuarioId = usuarioId,
        };

        _context.MovimientosOperativos.Add(movimiento);
        await _context.SaveChangesAsync();

        var tipoLedger = request.Tipo == TipoMovimientoOperativo.Ingreso
            ? TipoMovimientoCuenta.Ingreso
            : TipoMovimientoCuenta.Egreso;

        var posteo = await _cuentas.PostearAsync(
            cuenta.Id, tipoLedger, request.Monto,
            DocumentoOrigenMovimiento.MovimientoOperativo, movimiento.Id, usuarioId, fecha,
            movimiento.Descripcion);

        movimiento.MovimientoCuentaId = posteo.Id;
        await _context.SaveChangesAsync();

        var response = await GetOrThrowAsync(movimiento.Id);
        await _notificador.AvisarAsync("gastosoperativos", "creado", response);
        await _notificador.AvisarAsync("cuentasfinancieras", "movimiento", new { cuenta.Id });
        return response;
    }

    public async Task<MovimientoOperativoResponse> AnularAsync(int id, int? usuarioId, bool delSistema = false)
    {
        var movimiento = await _context.MovimientosOperativos
            .Include(m => m.MotivoGasto)
            .FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException($"No existe el movimiento {id}");

        if (movimiento.Anulado) throw new BadRequestException("Ese movimiento ya está anulado");

        // Anularlo aquí dejaría la planilla como pagada sin su egreso.
        if (movimiento.MotivoGasto is { EsSistema: true } categoria && !delSistema)
        {
            throw new BadRequestException(
                $"Este movimiento lo registró el sistema ({categoria.Nombre}): se anula desde su módulo.");
        }

        if (movimiento.MovimientoCuentaId is int movimientoCuentaId)
        {
            await _cuentas.ReversarAsync(movimientoCuentaId, usuarioId);
        }

        movimiento.Anulado = true;
        await _context.SaveChangesAsync();

        var response = await GetOrThrowAsync(id);
        await _notificador.AvisarAsync("gastosoperativos", "anulado", response);
        return response;
    }

    // ---------------------------------------------------------- Auxiliares

    private async Task<GastoRecurrenteResponse> GetRecurrenteOrThrowAsync(int id) =>
        MapRecurrente(await _context.GastosRecurrentes
            .AsNoTracking()
            .Include(g => g.MotivoGasto)
            .Include(g => g.CuentaFinancieraSugerida)
            .FirstOrDefaultAsync(g => g.Id == id)
            ?? throw new NotFoundException($"No existe el gasto recurrente {id}"));

    private async Task<MovimientoOperativoResponse> GetOrThrowAsync(int id) =>
        Map(await _context.MovimientosOperativos
            .AsNoTracking()
            .Include(m => m.CuentaFinanciera)
            .Include(m => m.MotivoGasto)
            .Include(m => m.Usuario)
            .FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException($"No existe el movimiento {id}"));

    /// <summary>
    /// Que exista, esté activa y sea del mismo tipo que el movimiento: un egreso
    /// no va con una categoría de ingreso. Una del sistema solo la usa el sistema.
    /// </summary>
    private async Task ValidarCategoriaAsync(int motivoGastoId, string tipo, bool delSistema = false)
    {
        var categoria = await _context.MotivosGasto.AsNoTracking().FirstOrDefaultAsync(m => m.Id == motivoGastoId)
            ?? throw new BadRequestException("Esa categoría no existe");

        if (categoria.EsSistema && !delSistema)
        {
            throw new BadRequestException(
                $"{categoria.Nombre} es una categoría del sistema: se registra sola, no a mano");
        }

        if (!categoria.Activo)
        {
            throw new BadRequestException($"La categoría {categoria.Nombre} está desactivada");
        }

        if (categoria.Tipo != tipo)
        {
            throw new BadRequestException(tipo == TipoMovimientoOperativo.Ingreso
                ? $"{categoria.Nombre} es una categoría de egreso: elige una de ingreso"
                : $"{categoria.Nombre} es una categoría de ingreso: elige una de egreso");
        }
    }

    private async Task ValidarCuentaSugeridaAsync(int? cuentaFinancieraSugeridaId)
    {
        if (cuentaFinancieraSugeridaId is int id)
        {
            await _cuentas.GetOrThrowAsync(id);
        }
    }

    private static void ExigirNoSistema(MotivoGasto categoria)
    {
        if (categoria.EsSistema)
        {
            throw new BadRequestException(
                $"{categoria.Nombre} es una categoría del sistema: no se edita ni se elimina");
        }
    }

    private async Task<int> ContarUsosCategoriaAsync(int id) =>
        await _context.MovimientosOperativos.CountAsync(m => m.MotivoGastoId == id)
        + await _context.GastosRecurrentes.CountAsync(g => g.MotivoGastoId == id);

    private static void AplicarCategoria(MotivoGasto categoria, CategoriaMovimientoRequest request)
    {
        categoria.Nombre = request.Nombre.Trim();
        categoria.Descripcion = string.IsNullOrWhiteSpace(request.Descripcion) ? null : request.Descripcion.Trim();
        categoria.Tipo = request.Tipo;
        categoria.Origen = request.Origen;
        categoria.Activo = request.Activo;
    }

    private static CategoriaMovimientoResponse MapCategoria(MotivoGasto m, int usos) => new()
    {
        Id = m.Id,
        Nombre = m.Nombre,
        Descripcion = m.Descripcion,
        Tipo = m.Tipo,
        Origen = m.Origen,
        Activo = m.Activo,
        EsSistema = m.EsSistema,
        Usos = usos,
    };

    private static void AplicarRecurrente(GastoRecurrente recurrente, GastoRecurrenteRequest request)
    {
        recurrente.Nombre = request.Nombre.Trim();
        recurrente.MotivoGastoId = request.MotivoGastoId;
        recurrente.MontoEstimado = request.MontoEstimado;
        recurrente.DiaVencimiento = request.DiaVencimiento;
        recurrente.CuentaFinancieraSugeridaId = request.CuentaFinancieraSugeridaId;
        recurrente.Activo = request.Activo;
    }

    private static GastoRecurrenteResponse MapRecurrente(GastoRecurrente g) => new()
    {
        Id = g.Id,
        Nombre = g.Nombre,
        MotivoGastoId = g.MotivoGastoId,
        MotivoGasto = g.MotivoGasto?.Nombre ?? string.Empty,
        MontoEstimado = g.MontoEstimado,
        DiaVencimiento = g.DiaVencimiento,
        CuentaFinancieraSugeridaId = g.CuentaFinancieraSugeridaId,
        CuentaFinancieraSugerida = g.CuentaFinancieraSugerida?.Nombre,
        Activo = g.Activo,
    };

    private static MovimientoOperativoResponse Map(MovimientoOperativo m) => new()
    {
        Id = m.Id,
        CuentaFinancieraId = m.CuentaFinancieraId,
        CuentaFinanciera = m.CuentaFinanciera?.Nombre ?? string.Empty,
        Tipo = m.Tipo,
        MotivoGastoId = m.MotivoGastoId,
        MotivoGasto = m.MotivoGasto?.Nombre ?? string.Empty,
        Origen = m.MotivoGasto?.Origen ?? string.Empty,
        EsSistema = m.MotivoGasto?.EsSistema ?? false,
        Monto = m.Monto,
        Fecha = m.Fecha,
        Descripcion = m.Descripcion,
        GastoRecurrenteId = m.GastoRecurrenteId,
        Usuario = m.Usuario?.Nombre,
        Anulado = m.Anulado,
    };
}
