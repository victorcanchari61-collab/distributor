using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class NovedadService : INovedadService
{
    private readonly AppDbContext _context;
    private readonly INotificador _notificador;

    public NovedadService(AppDbContext context, INotificador notificador)
    {
        _context = context;
        _notificador = notificador;
    }

    // ------------------------------------------------------------------
    // Motivos
    // ------------------------------------------------------------------

    public async Task<IEnumerable<MotivoNovedadResponse>> GetMotivosAsync() =>
        await _context.MotivosNovedad
            .AsNoTracking()
            .OrderByDescending(m => m.Activo)
            .ThenBy(m => m.Nombre)
            .Select(m => new MotivoNovedadResponse
            {
                Id = m.Id,
                Nombre = m.Nombre,
                Descripcion = m.Descripcion,
                RegresaAlAlmacen = m.RegresaAlAlmacen,
                Activo = m.Activo,
                Usos = _context.NovedadesEntrega.Count(n => n.MotivoId == m.Id),
            })
            .ToListAsync();

    public async Task<IEnumerable<MotivoNovedadOpcionResponse>> GetOpcionesAsync() =>
        await _context.MotivosNovedad
            .AsNoTracking()
            .Where(m => m.Activo)
            .OrderBy(m => m.Nombre)
            .Select(m => new MotivoNovedadOpcionResponse
            {
                Id = m.Id,
                Nombre = m.Nombre,
                Descripcion = m.Descripcion,
            })
            .ToListAsync();

    public async Task<MotivoNovedadResponse> CrearMotivoAsync(MotivoNovedadRequest request)
    {
        var nombre = Exigir(request.Nombre, "Ponle un nombre al motivo");

        if (await _context.MotivosNovedad.AnyAsync(m => m.Nombre == nombre))
            throw new ConflictException("Ya existe un motivo con ese nombre");

        var motivo = new MotivoNovedad
        {
            Nombre = nombre,
            Descripcion = Limpiar(request.Descripcion),
            RegresaAlAlmacen = request.RegresaAlAlmacen,
            Activo = request.Activo,
        };

        _context.MotivosNovedad.Add(motivo);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "motivoCreado", new { motivo.Id });

        return (await GetMotivosAsync()).First(m => m.Id == motivo.Id);
    }

    public async Task<MotivoNovedadResponse> ActualizarMotivoAsync(int id, MotivoNovedadRequest request)
    {
        var motivo = await _context.MotivosNovedad.FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException("Motivo no encontrado");

        var nombre = Exigir(request.Nombre, "Ponle un nombre al motivo");

        if (await _context.MotivosNovedad.AnyAsync(m => m.Nombre == nombre && m.Id != id))
            throw new ConflictException("Ya existe un motivo con ese nombre");

        motivo.Nombre = nombre;
        motivo.Descripcion = Limpiar(request.Descripcion);
        motivo.RegresaAlAlmacen = request.RegresaAlAlmacen;
        motivo.Activo = request.Activo;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "motivoActualizado", new { motivo.Id });

        return (await GetMotivosAsync()).First(m => m.Id == id);
    }

    // ------------------------------------------------------------------
    // Registro
    // ------------------------------------------------------------------

    public async Task<Dictionary<int, MotivoNovedad>> ExigirMotivosAsync(IEnumerable<int> ids)
    {
        var pedidos = ids.Distinct().ToList();
        var motivos = await _context.MotivosNovedad
            .Where(m => pedidos.Contains(m.Id))
            .ToDictionaryAsync(m => m.Id);

        foreach (var id in pedidos)
        {
            if (!motivos.TryGetValue(id, out var motivo))
                throw new BadRequestException("El motivo elegido ya no existe.");

            if (!motivo.Activo)
                throw new BadRequestException($"El motivo \"{motivo.Nombre}\" está desactivado. Elige otro.");
        }

        return motivos;
    }

    public async Task RegistrarLineasAsync(
        Pedido pedido, int notaVentaId, IReadOnlyList<CambioEntrega> cambios,
        IReadOnlyDictionary<int, MotivoNovedad> motivos, int? usuarioId)
    {
        if (cambios.Count == 0) return;

        var despachoId = await DespachoVigenteAsync(pedido.Id);
        var ahora = DateTime.UtcNow;

        foreach (var cambio in cambios)
        {
            var linea = cambio.Linea;
            _context.NovedadesEntrega.Add(new NovedadEntrega
            {
                Tipo = TipoNovedad.Linea,
                PedidoId = pedido.Id,
                PedidoDetalleId = linea.Id,
                NotaVentaId = notaVentaId,
                DespachoId = despachoId,
                ProductoId = linea.ProductoId,
                PresentacionId = linea.PresentacionId,
                CantidadPedida = linea.Cantidad,
                CantidadEntregada = cambio.Entregada,
                Importe = cambio.Importe,
                MotivoId = cambio.MotivoId,
                Observacion = Limpiar(cambio.Observacion),
                UsuarioId = usuarioId,
                Fecha = ahora,
                Estado = EstadoInicial(motivos[cambio.MotivoId]),
            });
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "registradas", new { PedidoId = pedido.Id, despachoId });
    }

    public async Task RegistrarNoEntregadoAsync(
        Pedido pedido, MotivoNovedad motivo, string? observacion, int? usuarioId)
    {
        var despachoId = await DespachoVigenteAsync(pedido.Id);

        // Una sola marca por pedido y camión: dos toques seguidos, o dos
        // personas a la vez, no deben duplicar lo que se tiene que revisar.
        var yaMarcado = await _context.NovedadesEntrega.AnyAsync(n =>
            n.PedidoId == pedido.Id
            && n.Tipo == TipoNovedad.Pedido
            && n.Estado != EstadoNovedad.Anulada
            && n.DespachoId == despachoId);

        if (yaMarcado)
            throw new ConflictException("Este pedido ya está marcado como no entregado.");

        var lineas = pedido.Detalle.Where(d => !d.Anulado).ToList();
        if (lineas.Count == 0)
            throw new BadRequestException("Este pedido no tiene productos.");

        var ahora = DateTime.UtcNow;

        foreach (var linea in lineas)
        {
            _context.NovedadesEntrega.Add(new NovedadEntrega
            {
                Tipo = TipoNovedad.Pedido,
                PedidoId = pedido.Id,
                PedidoDetalleId = linea.Id,
                DespachoId = despachoId,
                ProductoId = linea.ProductoId,
                PresentacionId = linea.PresentacionId,
                CantidadPedida = linea.Cantidad,
                CantidadEntregada = 0,
                Importe = Math.Round(linea.CantidadPresentacion * linea.PrecioPresentacion, 2),
                MotivoId = motivo.Id,
                Observacion = Limpiar(observacion),
                UsuarioId = usuarioId,
                Fecha = ahora,
                Estado = EstadoInicial(motivo),
            });
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "noEntregado", new { PedidoId = pedido.Id, despachoId });
    }

    public async Task<Dictionary<int, NoEntregadoInfo>> GetNoEntregadosAsync(IEnumerable<int> pedidoIds)
    {
        var ids = pedidoIds.Distinct().ToList();
        if (ids.Count == 0) return [];

        var marcas = await _context.NovedadesEntrega
            .AsNoTracking()
            .Where(n => ids.Contains(n.PedidoId)
                        && n.Tipo == TipoNovedad.Pedido
                        && n.Estado != EstadoNovedad.Anulada)
            .OrderByDescending(n => n.Id)
            .Select(n => new { n.PedidoId, Motivo = n.Motivo!.Nombre, n.Observacion })
            .ToListAsync();

        // Todas las líneas de una marca comparten motivo: basta la primera.
        return marcas
            .GroupBy(m => m.PedidoId)
            .ToDictionary(g => g.Key, g => new NoEntregadoInfo(g.First().Motivo, g.First().Observacion));
    }

    public async Task DeshacerNoEntregadoAsync(int pedidoId)
    {
        var marcas = await _context.NovedadesEntrega
            .Where(n => n.PedidoId == pedidoId
                        && n.Tipo == TipoNovedad.Pedido
                        && n.Estado != EstadoNovedad.Anulada)
            .ToListAsync();

        if (marcas.Count == 0)
            throw new BadRequestException("Este pedido no está marcado como no entregado.");

        // Ya contada por el encargado: deshacerla borraría un rastro que
        // alguien revisó. Si se marcó mal, se corrige desde la revisión.
        if (marcas.Any(n => n.Estado is EstadoNovedad.Recibida or EstadoNovedad.Faltante))
            throw new BadRequestException(
                "El encargado ya revisó esa mercadería: no se puede quitar la marca.");

        foreach (var marca in marcas) marca.Estado = EstadoNovedad.Anulada;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "noEntregadoQuitado", new { PedidoId = pedidoId });
    }

    public Task AnularDeVentaAsync(int notaVentaId) =>
        AnularAsync(_context.NovedadesEntrega.Where(n => n.NotaVentaId == notaVentaId));

    public Task AnularNoEntregadoAsync(int pedidoId) =>
        AnularAsync(_context.NovedadesEntrega.Where(n => n.PedidoId == pedidoId && n.Tipo == TipoNovedad.Pedido));

    public Task AnularDePedidoAsync(int pedidoId) =>
        AnularAsync(_context.NovedadesEntrega.Where(n => n.PedidoId == pedidoId));

    /// <summary>
    /// Deja sin efecto lo que sigue abierto. Lo que el encargado ya contó
    /// (recibida o faltante) se respeta: ahí hubo una revisión de verdad y no
    /// se reescribe por un cambio posterior en el documento.
    /// </summary>
    private async Task AnularAsync(IQueryable<NovedadEntrega> consulta)
    {
        var abiertas = await consulta
            .Where(n => n.Estado == EstadoNovedad.Pendiente || n.Estado == EstadoNovedad.SinRetorno)
            .ToListAsync();

        if (abiertas.Count == 0) return;

        foreach (var novedad in abiertas) novedad.Estado = EstadoNovedad.Anulada;
        await _context.SaveChangesAsync();
    }

    // ------------------------------------------------------------------
    // Auxiliares
    // ------------------------------------------------------------------

    /// <summary>
    /// El camión en el que va el pedido ahora, si va en uno: el despacho armado
    /// más reciente que lo lleva. Uno anulado ya no cuenta.
    /// </summary>
    private async Task<int?> DespachoVigenteAsync(int pedidoId) =>
        await _context.Despachos
            .Where(d => d.Estado == EstadoDespacho.Armado && d.Detalle.Any(x => x.PedidoId == pedidoId))
            .OrderByDescending(d => d.Id)
            .Select(d => (int?)d.Id)
            .FirstOrDefaultAsync();

    /// <summary>
    /// Si la mercadería tiene que volver, queda pendiente de que el encargado
    /// la cuente; si nunca salió del almacén, no hay nada que revisar.
    /// </summary>
    private static string EstadoInicial(MotivoNovedad motivo) =>
        motivo.RegresaAlAlmacen ? EstadoNovedad.Pendiente : EstadoNovedad.SinRetorno;

    private static string Exigir(string valor, string mensaje)
    {
        var limpio = valor.Trim();
        if (limpio.Length == 0) throw new BadRequestException(mensaje);
        return limpio;
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();
}
