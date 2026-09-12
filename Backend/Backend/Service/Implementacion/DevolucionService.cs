using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Lo que un cliente devuelve de una venta.
///
/// Nace Solicitada y no mueve nada. Al aprobarla entra la mercadería y la
/// venta baja de importe, con lo que la deuda del cliente baja sola: el saldo
/// se calcula como lo vendido menos lo devuelto menos lo pagado.
/// </summary>
public class DevolucionService : IDevolucionService
{
    private readonly AppDbContext _context;
    private readonly IInventarioService _inventario;
    private readonly INotificador _notificador;

    public DevolucionService(
        AppDbContext context, IInventarioService inventario, INotificador notificador)
    {
        _context = context;
        _inventario = inventario;
        _notificador = notificador;
    }

    private IQueryable<Devolucion> Completas() =>
        _context.Devoluciones
            .Include(d => d.NotaVenta!).ThenInclude(n => n.Cliente)
            .Include(d => d.Almacen)
            .Include(d => d.Usuario)
            .Include(d => d.AprobadoPor)
            .Include(d => d.Detalle).ThenInclude(x => x.NotaVentaDetalle!).ThenInclude(l => l.Producto!)
                .ThenInclude(p => p.UnidadBase)
            .Include(d => d.Detalle).ThenInclude(x => x.NotaVentaDetalle!).ThenInclude(l => l.Presentacion);

    public async Task<IEnumerable<DevolucionResponse>> GetAllAsync(string? estado = null) =>
        (await Completas()
            .AsNoTracking()
            .Where(d => estado == null || d.Estado == estado)
            .OrderByDescending(d => d.Fecha)
            .ThenByDescending(d => d.Id)
            .Take(300)
            .ToListAsync())
        .Select(Map);

    public async Task<DevolucionResponse> GetAsync(int id) => Map(await BuscarAsync(id));

    public async Task<ResumenDevolucionesResponse> GetResumenAsync()
    {
        var devoluciones = await Completas().AsNoTracking().ToListAsync();

        return new ResumenDevolucionesResponse
        {
            Total = devoluciones.Count,
            Solicitadas = devoluciones.Count(d => d.Estado == EstadoDevolucion.Solicitada),
            Aprobadas = devoluciones.Count(d => d.Estado == EstadoDevolucion.Aprobada),
            Importe = devoluciones
                .Where(d => d.Estado == EstadoDevolucion.Aprobada)
                .Sum(d => d.Detalle.Sum(l => l.Cantidad * l.PrecioUnitario)),
        };
    }

    public async Task<IEnumerable<LineaDevolvibleResponse>> DevolvibleAsync(int notaVentaId)
    {
        var nota = await _context.NotasVenta
            .AsNoTracking()
            .Include(n => n.Detalle).ThenInclude(d => d.Producto!).ThenInclude(p => p.UnidadBase)
            .Include(n => n.Detalle).ThenInclude(d => d.Presentacion)
            .FirstOrDefaultAsync(n => n.Id == notaVentaId)
            ?? throw new NotFoundException($"No existe la nota de venta {notaVentaId}");

        if (nota.Estado == EstadoNotaVenta.Anulada)
        {
            throw new BadRequestException("Esta venta está anulada: no hay nada que devolver.");
        }

        var devueltas = await DevueltasAsync(notaVentaId);

        return nota.Detalle
            .Where(d => !d.Anulado)
            .Select(d =>
            {
                var devuelta = devueltas.GetValueOrDefault(d.Id);
                var factor = d.CantidadPresentacion > 0 ? d.Cantidad / d.CantidadPresentacion : 1m;

                return new LineaDevolvibleResponse
                {
                    NotaVentaDetalleId = d.Id,
                    ProductoId = d.ProductoId,
                    Codigo = d.Producto?.Codigo ?? string.Empty,
                    Producto = d.Producto?.Nombre ?? string.Empty,
                    UnidadBase = d.Producto?.UnidadBase?.Codigo ?? string.Empty,
                    Presentacion = d.Presentacion?.Nombre,
                    Vendida = d.CantidadPresentacion,
                    Devuelta = factor > 0 ? devuelta / factor : devuelta,
                    Disponible = d.CantidadPresentacion - (factor > 0 ? devuelta / factor : devuelta),
                    PrecioUnitario = d.PrecioUnitario * factor,
                };
            })
            .ToList();
    }

    public async Task<DevolucionResponse> CrearAsync(DevolucionRequest request, int? usuarioId)
    {
        var nota = await _context.NotasVenta
            .Include(n => n.Detalle)
            .FirstOrDefaultAsync(n => n.Id == request.NotaVentaId)
            ?? throw new NotFoundException($"No existe la nota de venta {request.NotaVentaId}");

        if (nota.Estado == EstadoNotaVenta.Anulada)
        {
            throw new BadRequestException("Esta venta está anulada: no hay nada que devolver.");
        }

        var lineas = request.Detalle.Where(l => l.Cantidad > 0).ToList();
        if (lineas.Count == 0)
        {
            throw new BadRequestException("Marca al menos una línea para devolver");
        }

        var devueltas = await DevueltasAsync(nota.Id);

        var devolucion = new Devolucion
        {
            Numero = await SiguienteNumeroAsync(),
            NotaVentaId = nota.Id,
            AlmacenId = nota.AlmacenId,
            Motivo = Limpiar(request.Motivo),
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId,
        };

        foreach (var linea in lineas)
        {
            var venta = nota.Detalle.FirstOrDefault(d => d.Id == linea.NotaVentaDetalleId && !d.Anulado)
                ?? throw new BadRequestException("Una de las líneas no pertenece a esta venta.");

            // Presentaciones a unidad base: el stock se mueve en base.
            var factor = venta.CantidadPresentacion > 0
                ? venta.Cantidad / venta.CantidadPresentacion
                : 1m;

            var cantidadBase = linea.Cantidad * factor;
            var yaDevuelta = devueltas.GetValueOrDefault(venta.Id);

            /*
             * No se puede devolver mas de lo vendido.
             *
             * Cuenta tambien lo que espera aprobacion: si no, se podrian
             * registrar dos devoluciones del total y al aprobar las dos
             * entraria el doble de mercaderia de la que salio.
             */
            if (cantidadBase + yaDevuelta > venta.Cantidad + 0.0001m)
            {
                var resto = venta.Cantidad - yaDevuelta;
                throw new BadRequestException(
                    $"De esa línea solo quedan {resto / (factor > 0 ? factor : 1m):0.####} por devolver.");
            }

            devolucion.Detalle.Add(new DevolucionDetalle
            {
                NotaVentaDetalleId = venta.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidadBase,
                PrecioUnitario = venta.PrecioUnitario,
                ReingresaStock = linea.ReingresaStock,
            });
        }

        _context.Devoluciones.Add(devolucion);
        await _context.SaveChangesAsync();

        var creada = Map(await BuscarAsync(devolucion.Id));
        await _notificador.AvisarAsync("devoluciones", "creada", creada);
        return creada;
    }

    public async Task<DevolucionResponse> AprobarAsync(int id, int? usuarioId)
    {
        var devolucion = await BuscarAsync(id);
        ExigirPendiente(devolucion);

        // El movimiento de inventario es lo que de verdad mueve la mercaderia:
        // si falla, la devolucion se queda como estaba.
        var documento = await _inventario.CrearDevolucionClienteAsync(devolucion, usuarioId);

        devolucion.Estado = EstadoDevolucion.Aprobada;
        devolucion.AprobadoPorId = usuarioId;
        devolucion.ResueltaEn = DateTime.UtcNow;
        devolucion.DocumentoInventarioId = documento.Id;

        await _context.SaveChangesAsync();

        var aprobada = Map(await BuscarAsync(id));
        await _notificador.AvisarAsync("devoluciones", "aprobada", aprobada);
        // La deuda del cliente baja al aprobarse: las cuentas por cobrar
        // tienen que enterarse.
        await _notificador.AvisarAsync("notasventa", "actualizada", new { id = devolucion.NotaVentaId });
        return aprobada;
    }

    public async Task<DevolucionResponse> RechazarAsync(int id, string motivo, int? usuarioId)
    {
        if (string.IsNullOrWhiteSpace(motivo))
        {
            throw new BadRequestException("Di por qué se rechaza: sin motivo nadie puede explicarlo después.");
        }

        var devolucion = await BuscarAsync(id);
        ExigirPendiente(devolucion);

        devolucion.Estado = EstadoDevolucion.Rechazada;
        devolucion.MotivoRechazo = motivo.Trim();
        devolucion.AprobadoPorId = usuarioId;
        devolucion.ResueltaEn = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        var rechazada = Map(await BuscarAsync(id));
        await _notificador.AvisarAsync("devoluciones", "rechazada", rechazada);
        return rechazada;
    }

    // ------------------------------------------------------------- Auxiliares

    private static void ExigirPendiente(Devolucion devolucion)
    {
        if (devolucion.Estado != EstadoDevolucion.Solicitada)
        {
            throw new BadRequestException(
                devolucion.Estado == EstadoDevolucion.Aprobada
                    ? "Esta devolución ya fue aprobada."
                    : "Esta devolución ya fue rechazada.");
        }
    }

    private async Task<Devolucion> BuscarAsync(int id) =>
        await Completas().FirstOrDefaultAsync(d => d.Id == id)
        ?? throw new NotFoundException($"No existe la devolución {id}");

    /// <summary>
    /// Lo ya devuelto de cada línea de una venta, en unidad base.
    ///
    /// Cuenta lo aprobado Y lo que espera aprobación: una solicitud pendiente
    /// ya reserva esa cantidad, o se podrían registrar dos por el total.
    /// </summary>
    private async Task<Dictionary<int, decimal>> DevueltasAsync(int notaVentaId) =>
        await _context.Devoluciones
            .AsNoTracking()
            .Where(d => d.NotaVentaId == notaVentaId && d.Estado != EstadoDevolucion.Rechazada)
            .SelectMany(d => d.Detalle)
            .GroupBy(l => l.NotaVentaDetalleId)
            .ToDictionaryAsync(g => g.Key, g => g.Sum(l => l.Cantidad));

    private async Task<string> SiguienteNumeroAsync()
    {
        var ultimo = await _context.Devoluciones
            .OrderByDescending(d => d.Id)
            .Select(d => d.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"DV-{correlativo:0000}";
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static DevolucionResponse Map(Devolucion d) => new()
    {
        Id = d.Id,
        Numero = d.Numero,
        Fecha = d.Fecha,
        NotaVentaId = d.NotaVentaId,
        NotaVenta = d.NotaVenta?.Numero ?? string.Empty,
        ClienteId = d.NotaVenta?.ClienteId ?? 0,
        Cliente = d.NotaVenta?.Cliente?.Nombre ?? string.Empty,
        AlmacenId = d.AlmacenId,
        Almacen = d.Almacen?.Nombre ?? string.Empty,
        Estado = d.Estado,
        Motivo = d.Motivo,
        Observacion = d.Observacion,
        MotivoRechazo = d.MotivoRechazo,
        Usuario = d.Usuario?.Nombre,
        AprobadoPor = d.AprobadoPor?.Nombre,
        ResueltaEn = d.ResueltaEn,
        Total = d.Detalle.Sum(l => l.Cantidad * l.PrecioUnitario),
        Detalle = [.. d.Detalle.Select(l => new LineaDevolucionResponse
        {
            Id = l.Id,
            NotaVentaDetalleId = l.NotaVentaDetalleId,
            ProductoId = l.NotaVentaDetalle?.ProductoId ?? 0,
            Codigo = l.NotaVentaDetalle?.Producto?.Codigo ?? string.Empty,
            Producto = l.NotaVentaDetalle?.Producto?.Nombre ?? string.Empty,
            UnidadBase = l.NotaVentaDetalle?.Producto?.UnidadBase?.Codigo ?? string.Empty,
            Presentacion = l.NotaVentaDetalle?.Presentacion?.Nombre,
            CantidadPresentacion = l.CantidadPresentacion,
            Cantidad = l.Cantidad,
            PrecioUnitario = l.PrecioUnitario,
            Importe = l.Cantidad * l.PrecioUnitario,
            ReingresaStock = l.ReingresaStock,
        })],
    };
}
