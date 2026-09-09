using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// Junta lo que ya calculan Inventario, Compras y Ventas y arma la lista de
/// alertas — sin tabla propia: es una consulta, no un registro. Cada tipo
/// tiene su umbral hardcodeado; si algún día se vuelven configurables, ese es
/// el momento de moverlos a una tabla de parámetros.
/// </summary>
public class AlertasService : IAlertasService
{
    private const int DiasPorVencerAviso = 30;
    private const int DiasCompraPendiente = 5;
    private const int DiasCreditoPendiente = 15;
    private const int DiasReservaVencida = 3;
    private const int HorasStockRepuesto = 48;
    private const int DiasProductoNuevo = 7;

    private readonly IInventarioService _inventario;
    private readonly IInventarioRepository _inventarioRepo;
    private readonly IComprasRepository _compras;
    private readonly IVentasRepository _ventas;
    private readonly IFlotaService _flota;

    public AlertasService(
        IInventarioService inventario,
        IInventarioRepository inventarioRepo,
        IComprasRepository compras,
        IVentasRepository ventas,
        IFlotaService flota)
    {
        _inventario = inventario;
        _inventarioRepo = inventarioRepo;
        _compras = compras;
        _ventas = ventas;
        _flota = flota;
    }

    public async Task<IEnumerable<AlertaResponse>> GetAsync()
    {
        var alertas = new List<AlertaResponse>();
        var ahora = DateTime.UtcNow;

        alertas.AddRange(await StockBajoAsync());
        alertas.AddRange(await LotesPorVencerAsync(ahora));
        alertas.AddRange(await ComprasPendientesAsync(ahora));
        alertas.AddRange(await CreditosPendientesAsync(ahora));
        alertas.AddRange(await ReservasVencidasAsync(ahora));
        alertas.AddRange(await StockRepuestoAsync(ahora));
        alertas.AddRange(await DocumentosVehiculoAsync());
        alertas.AddRange(await LicenciasConductorAsync());

        return alertas
            .OrderBy(a => Peso(a.Severidad))
            .ThenByDescending(a => a.Fecha);
    }

    /// <summary>Crítica primero, luego advertencia, y al final las buenas noticias.</summary>
    private static int Peso(string severidad) => severidad switch
    {
        SeveridadAlerta.Critica => 0,
        SeveridadAlerta.Advertencia => 1,
        _ => 2
    };

    /// <summary>
    /// SOAT, revisión técnica y permiso a punto de vencer o ya vencidos.
    ///
    /// Solo de los vehículos activos: uno dado de baja no sale a repartir, y
    /// avisar de su SOAT es ruido que tapa el del camión que sí sale mañana.
    ///
    /// Vencido es crítico y no advertencia porque no es un trámite pendiente:
    /// es que esa unidad no puede circular hoy.
    /// </summary>
    private async Task<List<AlertaResponse>> DocumentosVehiculoAsync()
    {
        var vehiculos = await _flota.GetVehiculosAsync();

        return vehiculos
            .Where(v => v.Activo)
            .SelectMany(v => v.Vencimientos
                .Where(d => d.Estado is EstadoVencimiento.Vencido or EstadoVencimiento.PorVencer)
                .Select(d => new AlertaResponse
                {
                    Id = $"vehiculo-{v.Id}-{d.Nombre}",
                    Tipo = TipoAlerta.DocumentoVehiculo,
                    Severidad = d.Estado == EstadoVencimiento.Vencido
                        ? SeveridadAlerta.Critica
                        : SeveridadAlerta.Advertencia,
                    Titulo = d.Estado == EstadoVencimiento.Vencido
                        ? $"{d.Nombre} vencido: {v.Placa}"
                        : $"{d.Nombre} por vencer: {v.Placa}",
                    Detalle = Plazo(d)
                              + (v.Conductor != null ? $" · {v.Conductor}" : string.Empty),
                    Ruta = "tms.flota",
                    Fecha = d.Vence,
                }))
            .OrderBy(a => a.Fecha)
            .Take(20)
            .ToList();
    }

    /// <summary>Licencias de conducir vencidas o a punto de vencer.</summary>
    private async Task<List<AlertaResponse>> LicenciasConductorAsync()
    {
        var conductores = await _flota.GetConductoresAsync();

        return conductores
            .Where(c => c.Activo)
            .SelectMany(c => c.Vencimientos
                .Where(d => d.Estado is EstadoVencimiento.Vencido or EstadoVencimiento.PorVencer)
                .Select(d => new AlertaResponse
                {
                    Id = $"conductor-{c.Id}-{d.Nombre}",
                    Tipo = TipoAlerta.LicenciaConductor,
                    Severidad = d.Estado == EstadoVencimiento.Vencido
                        ? SeveridadAlerta.Critica
                        : SeveridadAlerta.Advertencia,
                    Titulo = d.Estado == EstadoVencimiento.Vencido
                        ? $"Licencia vencida: {c.Nombre}"
                        : $"Licencia por vencer: {c.Nombre}",
                    Detalle = Plazo(d)
                              + (c.LicenciaCategoria != null
                                  ? $" · categoría {c.LicenciaCategoria}"
                                  : string.Empty),
                    Ruta = "tms.conductores",
                    Fecha = d.Vence,
                }))
            .OrderBy(a => a.Fecha)
            .Take(20)
            .ToList();
    }

    /// <summary>"vence en 12 días" o "venció hace 3 días", que es lo accionable.</summary>
    private static string Plazo(VencimientoResponse d)
    {
        var dias = d.DiasRestantes ?? 0;
        if (dias < 0) return $"venció hace {-dias} día{(dias == -1 ? "" : "s")}";
        if (dias == 0) return "vence hoy";
        return $"vence en {dias} día{(dias == 1 ? "" : "s")}";
    }

    private async Task<List<AlertaResponse>> StockBajoAsync()
    {
        var stock = await _inventario.GetStockAsync(null);

        return stock
            .Where(s => s.BajoMinimo)
            .OrderBy(s => s.Stock)
            .Take(20)
            .Select(s => new AlertaResponse
            {
                Id = $"stock-{s.ProductoId}",
                Tipo = TipoAlerta.StockBajo,
                Severidad = s.Stock <= 0 ? SeveridadAlerta.Critica : SeveridadAlerta.Advertencia,
                Titulo = s.Stock <= 0 ? $"Sin stock: {s.Producto}" : $"Stock bajo: {s.Producto}",
                Detalle = $"{s.Stock} {s.UnidadBase} disponibles, mínimo {s.StockMinimo}",
                Ruta = "inv.stock"
            })
            .ToList();
    }

    private async Task<List<AlertaResponse>> LotesPorVencerAsync(DateTime ahora)
    {
        var lotes = await _inventario.GetLotesAsync();

        return lotes
            .Where(l => l.DiasParaVencer is int d && d <= DiasPorVencerAviso)
            .OrderBy(l => l.DiasParaVencer)
            .Take(20)
            .Select(l => new AlertaResponse
            {
                Id = $"lote-{l.CapaId}",
                Tipo = TipoAlerta.LotePorVencer,
                Severidad = l.DiasParaVencer < 0 ? SeveridadAlerta.Critica : SeveridadAlerta.Advertencia,
                Titulo = l.DiasParaVencer < 0 ? $"Vencido: {l.Producto}" : $"Por vencer: {l.Producto}",
                Detalle = $"{l.CantidadDisponible} {l.UnidadBase} en {l.Almacen}"
                          + (l.Lote != null ? $" · lote {l.Lote}" : "")
                          + (l.DiasParaVencer < 0
                              ? $" · venció hace {-l.DiasParaVencer.Value} días"
                              : $" · vence en {l.DiasParaVencer} días"),
                Ruta = "inv.lotes",
                Fecha = l.FechaVencimiento
            })
            .ToList();
    }

    private async Task<List<AlertaResponse>> ComprasPendientesAsync(DateTime ahora)
    {
        var compras = await _compras.GetComprasAsync(EstadoCompra.Pendiente);
        var limite = ahora.AddDays(-DiasCompraPendiente);

        return compras
            .Where(c => c.Fecha <= limite)
            .OrderBy(c => c.Fecha)
            .Take(20)
            .Select(c => new AlertaResponse
            {
                Id = $"compra-{c.Id}",
                Tipo = TipoAlerta.CompraPendiente,
                Severidad = SeveridadAlerta.Advertencia,
                Titulo = $"Compra sin recibir: {c.Numero}",
                Detalle = $"{c.Proveedor?.Nombre} · hace {(ahora - c.Fecha).Days} días",
                Ruta = "compras.compras",
                Fecha = c.Fecha
            })
            .ToList();
    }

    private async Task<List<AlertaResponse>> CreditosPendientesAsync(DateTime ahora)
    {
        var notas = await _ventas.GetNotasVentaAsync(EstadoNotaVenta.Confirmada);
        var limite = ahora.AddDays(-DiasCreditoPendiente);

        return notas
            .Where(n => n.FormaPago == FormaPagoVenta.Credito && n.Fecha <= limite)
            .Where(n => n.Pagos.Sum(p => p.Monto) < n.Detalle.Sum(d => d.Cantidad * d.PrecioUnitario) - 0.01m)
            .OrderBy(n => n.Fecha)
            .Take(20)
            .Select(n =>
            {
                var total = n.Detalle.Sum(d => d.Cantidad * d.PrecioUnitario);
                var pagado = n.Pagos.Sum(p => p.Monto);
                return new AlertaResponse
                {
                    Id = $"credito-{n.Id}",
                    Tipo = TipoAlerta.CreditoPendiente,
                    Severidad = (ahora - n.Fecha).Days > 30 ? SeveridadAlerta.Critica : SeveridadAlerta.Advertencia,
                    Titulo = $"Crédito sin cobrar: {n.Numero}",
                    Detalle = $"{n.Cliente?.Nombre} · debe S/ {(total - pagado):F2} · hace {(ahora - n.Fecha).Days} días",
                    Ruta = "fact.notaventa",
                    Fecha = n.Fecha
                };
            })
            .ToList();
    }

    private async Task<List<AlertaResponse>> ReservasVencidasAsync(DateTime ahora)
    {
        var pedidos = await _ventas.GetPedidosAsync(EstadoPedido.Pendiente);
        var limite = ahora.AddDays(-DiasReservaVencida);

        return pedidos
            .Where(p => p.ReservaStock && p.Fecha <= limite)
            .OrderBy(p => p.Fecha)
            .Take(20)
            .Select(p => new AlertaResponse
            {
                Id = $"reserva-{p.Id}",
                Tipo = TipoAlerta.ReservaVencida,
                Severidad = SeveridadAlerta.Advertencia,
                Titulo = $"Reserva de stock vieja: {p.Numero}",
                Detalle = $"{p.Cliente?.Nombre} · {p.Almacen?.Nombre} · hace {(ahora - p.Fecha).Days} días sin confirmar",
                Ruta = "fact.pedidos",
                Fecha = p.Fecha
            })
            .ToList();
    }

    /// <summary>
    /// Mercadería que entró hace poco (recepción o ajuste), agrupada por
    /// producto y almacén: para que ventas sepa que ya puede ofrecerlo — sea
    /// porque es un producto nuevo o porque se repuso uno que estaba bajo.
    /// </summary>
    private async Task<List<AlertaResponse>> StockRepuestoAsync(DateTime ahora)
    {
        var desde = ahora.AddHours(-HorasStockRepuesto);
        var movimientos = await _inventarioRepo.GetEntradasRecientesAsync(desde);

        return movimientos
            .GroupBy(m => (m.ProductoId, m.AlmacenId))
            .Select(g =>
            {
                var producto = g.First().Producto!;
                var almacen = g.First().Almacen!;
                var cantidad = g.Sum(m => m.Cantidad);
                var esNuevo = producto.FechaCreacion >= ahora.AddDays(-DiasProductoNuevo);

                return new AlertaResponse
                {
                    Id = $"repuesto-{producto.Id}-{almacen.Id}",
                    Tipo = TipoAlerta.StockRepuesto,
                    Severidad = SeveridadAlerta.Info,
                    Titulo = esNuevo ? $"Nuevo producto: {producto.Nombre}" : $"Llegó stock: {producto.Nombre}",
                    Detalle = $"{cantidad} {producto.UnidadBase?.Codigo} en {almacen.Nombre}",
                    Ruta = "inv.stock",
                    Fecha = g.Max(m => m.Fecha)
                };
            })
            .OrderByDescending(a => a.Fecha)
            .Take(20)
            .ToList();
    }
}
