using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class SolicitudCompraService : ISolicitudCompraService
{
    /// <summary>El submódulo de permisos, para el alcance: quien solo ve lo suyo, solo ve sus solicitudes.</summary>
    private const string Submodulo = "compras.solicitudes";

    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;
    private readonly IInventarioService _inventario;
    private readonly INotificador _notificador;
    private readonly IValidator<CrearSolicitudCompraRequest> _crearValidator;
    private readonly IValidator<RechazarSolicitudCompraRequest> _rechazarValidator;

    public SolicitudCompraService(
        AppDbContext context,
        IPermisoService permisos,
        IUsuarioActual usuarioActual,
        IInventarioService inventario,
        INotificador notificador,
        IValidator<CrearSolicitudCompraRequest> crearValidator,
        IValidator<RechazarSolicitudCompraRequest> rechazarValidator)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
        _inventario = inventario;
        _notificador = notificador;
        _crearValidator = crearValidator;
        _rechazarValidator = rechazarValidator;
    }

    /// <summary>
    /// Si quien pide solo ve lo suyo: devuelve su id para acotar. Null si ve todas.
    ///
    /// El almacenero ve sus solicitudes y no las de otro almacén; Compras y administración ven todas. Se decide por
    /// el alcance configurado en Accesos: cualquier alcance distinto de "todos" se lee como "solo las mías", porque
    /// una solicitud no tiene clientes de por medio.
    /// </summary>
    private async Task<int?> SoloDeAsync()
    {
        if (_usuarioActual.Id is not int uid) return -1;

        var alcance = await _permisos.AlcanceAsync(uid, Submodulo);
        return alcance == AlcanceDatos.Todos ? null : uid;
    }

    private IQueryable<SolicitudCompra> Consulta() =>
        _context.SolicitudesCompra
            .Include(s => s.Almacen)
            .Include(s => s.Usuario)
            .Include(s => s.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(s => s.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<IEnumerable<SolicitudCompraFilaResponse>> GetAllAsync(string? estado)
    {
        var consulta = _context.SolicitudesCompra.AsNoTracking()
            .Include(s => s.Almacen)
            .Include(s => s.Usuario)
            .AsQueryable();

        if (await SoloDeAsync() is int solo) consulta = consulta.Where(s => s.UsuarioId == solo);
        if (!string.IsNullOrWhiteSpace(estado)) consulta = consulta.Where(s => s.Estado == estado);

        var solicitudes = await consulta
            // Lo pendiente y lo urgente primero: es lo que Compras tiene que mirar.
            .OrderBy(s => s.Estado == EstadoSolicitudCompra.Pendiente ? 0 : 1)
            .ThenByDescending(s => s.Urgencia == UrgenciaSolicitudCompra.Urgente)
            .ThenByDescending(s => s.Fecha)
            .Take(500)
            .Select(s => new
            {
                Solicitud = s,
                Lineas = s.Detalle.Count,
            })
            .ToListAsync();

        var ordenes = await OrdenesDeAsync(solicitudes.Select(s => s.Solicitud.Id).ToList());

        return solicitudes
            .Select(s => MapFila(s.Solicitud, s.Lineas, ordenes.GetValueOrDefault(s.Solicitud.Id) ?? []))
            .ToList();
    }

    public async Task<SolicitudCompraResponse> GetAsync(int id)
    {
        var solicitud = await GetOrThrowAsync(id, rastrear: false);
        return await MapAsync(solicitud);
    }

    public async Task<SolicitudCompraResponse> CrearAsync(CrearSolicitudCompraRequest request, int? usuarioId)
    {
        await _crearValidator.ValidateAndThrowAsync(request);
        await ExigirAlmacenAsync(request.AlmacenId);

        var solicitud = new SolicitudCompra
        {
            Numero = await SiguienteNumeroAsync(),
            AlmacenId = request.AlmacenId,
            Urgencia = UrgenciaDe(request.Urgencia),
            Estado = EstadoSolicitudCompra.Pendiente,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId,
            Detalle = await ResolverLineasAsync(request.Detalle),
        };

        _context.SolicitudesCompra.Add(solicitud);
        await _context.SaveChangesAsync();

        var creada = await GetAsync(solicitud.Id);
        await _notificador.AvisarAsync("solicitudescompra", "creado", creada);
        return creada;
    }

    public async Task<SolicitudCompraResponse> ActualizarAsync(int id, CrearSolicitudCompraRequest request)
    {
        await _crearValidator.ValidateAndThrowAsync(request);

        var solicitud = await GetOrThrowAsync(id, rastrear: true);
        ExigirPendiente(solicitud, "corregir");
        await ExigirAlmacenAsync(request.AlmacenId);

        solicitud.AlmacenId = request.AlmacenId;
        solicitud.Urgencia = UrgenciaDe(request.Urgencia);
        solicitud.Observacion = Limpiar(request.Observacion);

        // Las líneas se reemplazan enteras: una solicitud es corta y esto evita cuadrar quién se quedó y quién no.
        _context.SolicitudCompraDetalles.RemoveRange(solicitud.Detalle);
        solicitud.Detalle = await ResolverLineasAsync(request.Detalle);

        await _context.SaveChangesAsync();

        var actualizada = await GetAsync(id);
        await _notificador.AvisarAsync("solicitudescompra", "actualizado", actualizada);
        return actualizada;
    }

    public async Task AnularAsync(int id)
    {
        var solicitud = await GetOrThrowAsync(id, rastrear: true);
        ExigirPendiente(solicitud, "anular");

        solicitud.Estado = EstadoSolicitudCompra.Anulada;
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("solicitudescompra", "anulado", new { id });
    }

    public async Task<SolicitudCompraResponse> RechazarAsync(int id, RechazarSolicitudCompraRequest request)
    {
        await _rechazarValidator.ValidateAndThrowAsync(request);

        var solicitud = await GetOrThrowAsync(id, rastrear: true);
        ExigirPendiente(solicitud, "rechazar");

        solicitud.Estado = EstadoSolicitudCompra.Rechazada;
        solicitud.MotivoRechazo = request.Motivo.Trim();
        await _context.SaveChangesAsync();

        var rechazada = await GetAsync(id);
        await _notificador.AvisarAsync("solicitudescompra", "rechazado", rechazada);
        return rechazada;
    }

    public async Task<IEnumerable<SugerenciaSolicitudResponse>> SugerenciasAsync(int almacenId)
    {
        await ExigirAlmacenAsync(almacenId);

        var stock = await _inventario.GetStockAsync(almacenId);

        return stock
            .Where(s => s.BajoMinimo && s.StockMinimo > 0)
            .OrderBy(s => s.Stock)
            .Select(s => new SugerenciaSolicitudResponse
            {
                ProductoId = s.ProductoId,
                Codigo = s.Codigo,
                Producto = s.Producto,
                UnidadBase = s.UnidadBase,
                Stock = s.Stock,
                StockMinimo = s.StockMinimo,
                // Llegar al doble del mínimo, en números enteros hacia arriba: pedir 2.3 sacos no tiene sentido.
                CantidadSugerida = Math.Max(1, Math.Ceiling(s.StockMinimo * 2 - Math.Max(0, s.Stock))),
            })
            .ToList();
    }

    public async Task ExigirAtendibleAsync(int id)
    {
        var solicitud = await _context.SolicitudesCompra.AsNoTracking().FirstOrDefaultAsync(s => s.Id == id)
            ?? throw new NotFoundException($"No existe la solicitud de compra {id}");

        // Atendida también vale: de una misma solicitud se pueden hacer varias órdenes, una por proveedor.
        if (solicitud.Estado is not (EstadoSolicitudCompra.Pendiente or EstadoSolicitudCompra.Atendida))
        {
            throw new BadRequestException(
                $"La solicitud {solicitud.Numero} está {solicitud.Estado.ToLowerInvariant()}: ya no se puede hacer una orden con ella.");
        }
    }

    public async Task MarcarAtendidaAsync(int id)
    {
        var solicitud = await _context.SolicitudesCompra.FirstOrDefaultAsync(s => s.Id == id);
        if (solicitud is null || solicitud.Estado != EstadoSolicitudCompra.Pendiente) return;

        solicitud.Estado = EstadoSolicitudCompra.Atendida;
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("solicitudescompra", "atendido", new { id });
    }

    // ---------------------------------------------------------------- apoyo

    private async Task<SolicitudCompra> GetOrThrowAsync(int id, bool rastrear)
    {
        var consulta = rastrear ? Consulta() : Consulta().AsNoTracking();
        var solicitud = await consulta.FirstOrDefaultAsync(s => s.Id == id)
            ?? throw new NotFoundException($"No existe la solicitud de compra {id}");

        // Quien solo ve lo suyo no distingue una ajena de una que no existe.
        if (await SoloDeAsync() is int solo && solicitud.UsuarioId != solo)
            throw new NotFoundException($"No existe la solicitud de compra {id}");

        return solicitud;
    }

    private static void ExigirPendiente(SolicitudCompra solicitud, string accion)
    {
        if (solicitud.Estado != EstadoSolicitudCompra.Pendiente)
        {
            throw new BadRequestException(
                $"Solo se puede {accion} una solicitud Pendiente. La {solicitud.Numero} está {solicitud.Estado.ToLowerInvariant()}.");
        }
    }

    private async Task ExigirAlmacenAsync(int almacenId)
    {
        var almacen = await _context.Almacenes.AsNoTracking().FirstOrDefaultAsync(a => a.Id == almacenId)
            ?? throw new BadRequestException("El almacén indicado no existe");

        if (!almacen.Activo) throw new BadRequestException("El almacén está desactivado");
    }

    private async Task<string> SiguienteNumeroAsync()
    {
        var ultimo = await _context.SolicitudesCompra
            .OrderByDescending(s => s.Id)
            .Select(s => s.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n)) correlativo = n + 1;

        return $"SC-{correlativo:D4}";
    }

    private async Task<List<SolicitudCompraDetalle>> ResolverLineasAsync(List<LineaSolicitudCompraRequest> detalle)
    {
        var productoIds = detalle.Select(l => l.ProductoId).Distinct().ToList();
        var productos = await _context.Productos.AsNoTracking()
            .Include(p => p.Presentaciones)
            .Where(p => productoIds.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id);

        var lineas = new List<SolicitudCompraDetalle>();

        foreach (var linea in detalle)
        {
            if (!productos.TryGetValue(linea.ProductoId, out var producto))
                throw new BadRequestException($"No existe el producto {linea.ProductoId}");

            if (!producto.Activo)
                throw new BadRequestException($"'{producto.Nombre}' está desactivado: no se puede pedir.");

            var factor = 1m;
            if (linea.PresentacionId is int presentacionId)
            {
                var presentacion = producto.Presentaciones.FirstOrDefault(p => p.Id == presentacionId)
                    ?? throw new BadRequestException($"La presentación indicada no es de '{producto.Nombre}'.");
                factor = presentacion.Factor;
            }

            lineas.Add(new SolicitudCompraDetalle
            {
                ProductoId = producto.Id,
                PresentacionId = linea.PresentacionId,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = linea.Cantidad * factor,
                Nota = Limpiar(linea.Nota),
            });
        }

        return lineas;
    }

    private async Task<Dictionary<int, List<OrdenDeSolicitudResponse>>> OrdenesDeAsync(List<int> solicitudIds)
    {
        if (solicitudIds.Count == 0) return [];

        var ordenes = await _context.OrdenesCompra.AsNoTracking()
            .Where(o => o.SolicitudCompraId != null && solicitudIds.Contains(o.SolicitudCompraId.Value))
            .OrderBy(o => o.Id)
            .Select(o => new { SolicitudId = o.SolicitudCompraId!.Value, o.Id, o.Numero, o.Estado })
            .ToListAsync();

        return ordenes
            .GroupBy(o => o.SolicitudId)
            .ToDictionary(
                g => g.Key,
                g => g.Select(o => new OrdenDeSolicitudResponse { Id = o.Id, Numero = o.Numero, Estado = o.Estado }).ToList());
    }

    private static string UrgenciaDe(string? urgencia) =>
        string.IsNullOrWhiteSpace(urgencia) ? UrgenciaSolicitudCompra.Normal : urgencia.Trim().ToUpperInvariant();

    private static string? Limpiar(string? texto) => string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static T Fila<T>(T fila, SolicitudCompra s, int lineas, List<OrdenDeSolicitudResponse> ordenes)
        where T : SolicitudCompraFilaResponse
    {
        fila.Id = s.Id;
        fila.Numero = s.Numero;
        fila.Fecha = s.Fecha;
        fila.AlmacenId = s.AlmacenId;
        fila.Almacen = s.Almacen?.Nombre ?? string.Empty;
        fila.Urgencia = s.Urgencia;
        fila.Estado = s.Estado;
        fila.Observacion = s.Observacion;
        fila.MotivoRechazo = s.MotivoRechazo;
        fila.UsuarioId = s.UsuarioId;
        fila.Solicitante = s.Usuario?.Nombre;
        fila.Lineas = lineas;
        fila.Ordenes = ordenes;
        return fila;
    }

    private static SolicitudCompraFilaResponse MapFila(
        SolicitudCompra s, int lineas, List<OrdenDeSolicitudResponse> ordenes) =>
        Fila(new SolicitudCompraFilaResponse(), s, lineas, ordenes);

    private async Task<SolicitudCompraResponse> MapAsync(SolicitudCompra s)
    {
        var ordenes = (await OrdenesDeAsync([s.Id])).GetValueOrDefault(s.Id) ?? [];

        var respuesta = Fila(new SolicitudCompraResponse(), s, s.Detalle.Count, ordenes);
        respuesta.Detalle = s.Detalle
            .OrderBy(d => d.Id)
            .Select(d =>
            {
                var factor = d.CantidadPresentacion > 0 ? d.Cantidad / d.CantidadPresentacion : 1m;
                return new LineaSolicitudCompraResponse
                {
                    Id = d.Id,
                    ProductoId = d.ProductoId,
                    Codigo = d.Producto?.Codigo ?? string.Empty,
                    Producto = d.Producto?.Nombre ?? string.Empty,
                    UnidadBase = d.Producto?.UnidadBase?.Codigo ?? string.Empty,
                    PresentacionId = d.PresentacionId,
                    Presentacion = d.Presentacion?.Nombre,
                    Factor = factor,
                    CantidadPresentacion = d.CantidadPresentacion,
                    Cantidad = d.Cantidad,
                    Nota = d.Nota,
                    CostoSugerido = d.Producto?.CostoReferencia is decimal costo
                        ? Math.Round(costo * factor, 4)
                        : null,
                };
            })
            .ToList();

        return respuesta;
    }
}
