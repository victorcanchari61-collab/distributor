using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Implementacion;

public class VentasRepository : IVentasRepository
{
    private readonly AppDbContext _context;

    public VentasRepository(AppDbContext context)
    {
        _context = context;
    }

    public Task<IDbContextTransaction> IniciarTransaccionAsync() =>
        _context.Database.BeginTransactionAsync();

    public Task GuardarAsync() => _context.SaveChangesAsync();

    // --------------------------------------------------------------- Pedidos

    public async Task<string> SiguienteNumeroPedidoAsync()
    {
        var ultimo = await _context.Pedidos
            .OrderByDescending(p => p.Id)
            .Select(p => p.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"PD-{correlativo:D4}";
    }

    public async Task<Pedido> AddPedidoAsync(Pedido pedido)
    {
        await _context.Pedidos.AddAsync(pedido);
        await _context.SaveChangesAsync();
        return pedido;
    }

    private IQueryable<Pedido> PedidosConDetalle() =>
        _context.Pedidos
            .Include(p => p.Cliente)
            .Include(p => p.ListaPrecio)
            .Include(p => p.Almacen)
            .Include(p => p.Usuario)
            .Include(p => p.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(p => p.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<Pedido?> GetPedidoAsync(int id) =>
        await PedidosConDetalle().FirstOrDefaultAsync(p => p.Id == id);

    public async Task<IEnumerable<Pedido>> GetPedidosAsync(string? estado = null) =>
        await PedidosConDetalle()
            .Where(p => estado == null || p.Estado == estado)
            .OrderByDescending(p => p.Fecha)
            .ThenByDescending(p => p.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdatePedidoAsync(Pedido pedido)
    {
        _context.Pedidos.Update(pedido);
        await _context.SaveChangesAsync();
    }

    public async Task<(List<Pedido> Items, int Total)> ListarPedidosAsync(ConsultaTablaRequest consulta)
    {
        var query = PedidosConDetalle().AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(p =>
                EF.Functions.Like(p.Numero, $"%{texto}%")
                || (p.Cliente != null && EF.Functions.Like(p.Cliente.Nombre, $"%{texto}%"))
                || (p.Cliente != null && EF.Functions.Like(p.Cliente.Documento, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
        {
            query = query.Where(p => EF.Functions.Like(p.Numero, $"%{numero}%"));
        }

        if (consulta.ValorDe("cliente") is string cliente)
        {
            query = query.Where(p => p.Cliente != null && EF.Functions.Like(p.Cliente.Nombre, $"%{cliente}%"));
        }

        if (consulta.ValorDe("estado") is string estado)
        {
            query = query.Where(p => p.Estado == estado);
        }

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(p => p.Fecha >= desde);
        if (hasta is not null) query = query.Where(p => p.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc
                ? query.OrderByDescending(p => p.Numero).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Numero).ThenBy(p => p.Id),
            "cliente" => desc
                ? query.OrderByDescending(p => p.Cliente!.Nombre).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Cliente!.Nombre).ThenBy(p => p.Id),
            "estado" => desc
                ? query.OrderByDescending(p => p.Estado).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Estado).ThenBy(p => p.Id),
            // El total no es una columna: se suma del detalle, sin las lineas
            // anuladas, igual que lo hace la respuesta.
            "total" => desc
                ? query.OrderByDescending(p => p.Detalle.Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario)).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Detalle.Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario)).ThenBy(p => p.Id),
            _ => desc
                ? query.OrderByDescending(p => p.Fecha).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Fecha).ThenBy(p => p.Id),
        };

        return await query.PaginarAsync(consulta);
    }

    public async Task<ResumenPedidosResponse> ResumenPedidosAsync() => new()
    {
        Total = await _context.Pedidos.CountAsync(),
        Pendientes = await _context.Pedidos.CountAsync(p => p.Estado == EstadoPedido.Pendiente),
        Confirmados = await _context.Pedidos.CountAsync(p => p.Estado == EstadoPedido.Confirmado),
    };

    /// <summary>
    /// Actualiza línea por línea en vez de borrar todo y recrearlo: así una
    /// edición de cantidad queda en la auditoría como "cantidad: 2 → 5" sobre
    /// la misma fila, no como un ELIMINADO + CREADO. Una línea que ya no
    /// viene en la lista nueva tampoco se borra — queda Anulada, para no
    /// perder su historial (regla del negocio: nunca se elimina, se anula).
    /// </summary>
    public async Task ReemplazarDetallePedidoAsync(int pedidoId, IEnumerable<PedidoDetalle> detalle)
    {
        var actuales = await _context.PedidoDetalles
            .Where(d => d.PedidoId == pedidoId)
            .ToListAsync();
        var actualesPorId = actuales.ToDictionary(d => d.Id);

        var conservadas = new HashSet<int>();

        foreach (var linea in detalle)
        {
            if (linea.Id > 0 && actualesPorId.TryGetValue(linea.Id, out var existente))
            {
                existente.ProductoId = linea.ProductoId;
                existente.PresentacionId = linea.PresentacionId;
                existente.CantidadPresentacion = linea.CantidadPresentacion;
                existente.Cantidad = linea.Cantidad;
                existente.PrecioUnitario = linea.PrecioUnitario;
                existente.Anulado = linea.Anulado;
                conservadas.Add(existente.Id);
            }
            else
            {
                linea.PedidoId = pedidoId;
                linea.Id = 0;
                await _context.PedidoDetalles.AddAsync(linea);
            }
        }

        foreach (var quitada in actuales.Where(d => !conservadas.Contains(d.Id)))
        {
            quitada.Anulado = true;
        }

        await _context.SaveChangesAsync();
    }

    public async Task<Dictionary<int, decimal>> GetReservadoPorProductoAsync(int? almacenId) =>
        await _context.PedidoDetalles
            .Where(d => d.Pedido!.Estado == EstadoPedido.Pendiente
                        && d.Pedido.ReservaStock
                        && !d.Anulado
                        && (almacenId == null || d.Pedido.AlmacenId == almacenId))
            .GroupBy(d => d.ProductoId)
            .Select(g => new { ProductoId = g.Key, Cantidad = g.Sum(d => d.Cantidad) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Cantidad);

    // ---------------------------------------------------------- Notas de venta

    public async Task<string> SiguienteNumeroNotaVentaAsync()
    {
        var ultimo = await _context.NotasVenta
            .OrderByDescending(n => n.Id)
            .Select(n => n.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"NV-{correlativo:D4}";
    }

    public async Task<NotaVenta> AddNotaVentaAsync(NotaVenta notaVenta)
    {
        await _context.NotasVenta.AddAsync(notaVenta);
        await _context.SaveChangesAsync();
        return notaVenta;
    }

    private IQueryable<NotaVenta> NotasVentaConDetalle() =>
        _context.NotasVenta
            .Include(n => n.Cliente)
            .Include(n => n.Pedido)
            .Include(n => n.Almacen)
            .Include(n => n.Usuario)
            .Include(n => n.Pagos).ThenInclude(p => p.MetodoPago)
            .Include(n => n.Pagos).ThenInclude(p => p.Usuario)
            .Include(n => n.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(n => n.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<NotaVenta?> GetNotaVentaAsync(int id) =>
        await NotasVentaConDetalle().FirstOrDefaultAsync(n => n.Id == id);

    public async Task<IEnumerable<NotaVenta>> GetNotasVentaAsync(string? estado = null) =>
        await NotasVentaConDetalle()
            .Where(n => estado == null || n.Estado == estado)
            .OrderByDescending(n => n.Fecha)
            .ThenByDescending(n => n.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdateNotaVentaAsync(NotaVenta notaVenta)
    {
        _context.NotasVenta.Update(notaVenta);
        await _context.SaveChangesAsync();
    }

    public async Task<(List<NotaVenta> Items, int Total)> ListarNotasVentaAsync(ConsultaTablaRequest consulta)
    {
        var query = NotasVentaConDetalle().AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(n =>
                EF.Functions.Like(n.Numero, $"%{texto}%")
                || (n.Cliente != null && EF.Functions.Like(n.Cliente.Nombre, $"%{texto}%"))
                || (n.Cliente != null && EF.Functions.Like(n.Cliente.Documento, $"%{texto}%"))
                || (n.Pedido != null && EF.Functions.Like(n.Pedido.Numero, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
        {
            query = query.Where(n => EF.Functions.Like(n.Numero, $"%{numero}%"));
        }

        if (consulta.ValorDe("cliente") is string cliente)
        {
            query = query.Where(n => n.Cliente != null && EF.Functions.Like(n.Cliente.Nombre, $"%{cliente}%"));
        }

        if (consulta.ValorDe("estado") is string estado)
        {
            query = query.Where(n => n.Estado == estado);
        }

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(n => n.Fecha >= desde);
        if (hasta is not null) query = query.Where(n => n.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc
                ? query.OrderByDescending(n => n.Numero).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Numero).ThenBy(n => n.Id),
            "cliente" => desc
                ? query.OrderByDescending(n => n.Cliente!.Nombre).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Cliente!.Nombre).ThenBy(n => n.Id),
            "estado" => desc
                ? query.OrderByDescending(n => n.Estado).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Estado).ThenBy(n => n.Id),
            "total" => desc
                ? query.OrderByDescending(n => n.Detalle.Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario)).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Detalle.Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario)).ThenBy(n => n.Id),
            _ => desc
                ? query.OrderByDescending(n => n.Fecha).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Fecha).ThenBy(n => n.Id),
        };

        return await query.PaginarAsync(consulta);
    }

    public async Task<ResumenNotasVentaResponse> ResumenNotasVentaAsync()
    {
        var confirmadas = _context.NotasVenta.Where(n => n.Estado == EstadoNotaVenta.Confirmada);

        return new ResumenNotasVentaResponse
        {
            Total = await _context.NotasVenta.CountAsync(),
            Confirmadas = await confirmadas.CountAsync(),
            TotalVendido = await confirmadas
                .SelectMany(n => n.Detalle)
                .Where(d => !d.Anulado)
                .SumAsync(d => (decimal?)(d.Cantidad * d.PrecioUnitario)) ?? 0m,
        };
    }

    /// <summary>Los cobros de un usuario en un rango, sin ordenar ni paginar.</summary>
    private IQueryable<PagoVenta> CobrosBase(int? usuarioId, DateTime? desde, DateTime? hasta) =>
        _context.PagosVenta
            .Include(p => p.MetodoPago)
            .Include(p => p.NotaVenta).ThenInclude(n => n!.Cliente)
            .Where(p => p.NotaVenta!.Estado == EstadoNotaVenta.Confirmada
                        && (usuarioId == null || p.UsuarioId == usuarioId)
                        && (desde == null || p.Fecha >= desde)
                        && (hasta == null || p.Fecha <= hasta))
            .AsNoTracking();

    public async Task<(List<PagoVenta> Items, int Total)> ListarCobrosAsync(
        ConsultaTablaRequest consulta, int? usuarioId, DateTime? desde, DateTime? hasta)
    {
        var query = CobrosBase(usuarioId, desde, hasta);

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(p =>
                EF.Functions.Like(p.NotaVenta!.Numero, $"%{texto}%")
                || (p.NotaVenta.Cliente != null && EF.Functions.Like(p.NotaVenta.Cliente.Nombre, $"%{texto}%"))
                || (p.MetodoPago != null && EF.Functions.Like(p.MetodoPago.Nombre, $"%{texto}%")));
        }

        if (consulta.ValorDe("metodoPago") is string metodo)
            query = query.Where(p => p.MetodoPago != null && p.MetodoPago.Nombre == metodo);

        if (consulta.ValorDe("cliente") is string cliente)
            query = query.Where(p => p.NotaVenta!.Cliente != null
                                     && EF.Functions.Like(p.NotaVenta.Cliente.Nombre, $"%{cliente}%"));

        var (fDesde, fHasta) = consulta.RangoFechas("fecha");
        if (fDesde is not null) query = query.Where(p => p.Fecha >= fDesde);
        if (fHasta is not null) query = query.Where(p => p.Fecha <= fHasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "monto" => desc ? query.OrderByDescending(p => p.Monto).ThenByDescending(p => p.Id)
                            : query.OrderBy(p => p.Monto).ThenBy(p => p.Id),
            "cliente" => desc ? query.OrderByDescending(p => p.NotaVenta!.Cliente!.Nombre).ThenByDescending(p => p.Id)
                              : query.OrderBy(p => p.NotaVenta!.Cliente!.Nombre).ThenBy(p => p.Id),
            "metodoPago" => desc ? query.OrderByDescending(p => p.MetodoPago!.Nombre).ThenByDescending(p => p.Id)
                                 : query.OrderBy(p => p.MetodoPago!.Nombre).ThenBy(p => p.Id),
            _ => desc ? query.OrderByDescending(p => p.Fecha).ThenByDescending(p => p.Id)
                      : query.OrderBy(p => p.Fecha).ThenBy(p => p.Id),
        };

        return await query.PaginarAsync(consulta);
    }

    public async Task<ResumenCobrosResponse> ResumenCobrosAsync(
        int? usuarioId, DateTime? desde, DateTime? hasta)
    {
        var cobros = CobrosBase(usuarioId, desde, hasta);

        return new ResumenCobrosResponse
        {
            Validos = await cobros.CountAsync(p => !p.Anulado),
            Anulados = await cobros.CountAsync(p => p.Anulado),
            // Un cobro anulado no entra: su monto volvio al saldo pendiente.
            TotalCobrado = await cobros.Where(p => !p.Anulado).SumAsync(p => (decimal?)p.Monto) ?? 0m,
        };
    }

    public async Task<NotaVentaDetalle?> GetNotaVentaDetalleConNotaVentaAsync(int id) =>
        await _context.NotaVentaDetalles
            .Include(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(d => d.NotaVenta)
            .FirstOrDefaultAsync(d => d.Id == id);

    public async Task ReemplazarDetalleNotaVentaAsync(int notaVentaId, IEnumerable<NotaVentaDetalle> detalle)
    {
        var actuales = await _context.NotaVentaDetalles
            .Where(d => d.NotaVentaId == notaVentaId)
            .ToListAsync();
        var actualesPorId = actuales.ToDictionary(d => d.Id);

        var conservadas = new HashSet<int>();

        foreach (var linea in detalle)
        {
            if (linea.Id > 0 && actualesPorId.TryGetValue(linea.Id, out var existente))
            {
                existente.ProductoId = linea.ProductoId;
                existente.PresentacionId = linea.PresentacionId;
                existente.CantidadPresentacion = linea.CantidadPresentacion;
                existente.Cantidad = linea.Cantidad;
                existente.PrecioUnitario = linea.PrecioUnitario;
                existente.Anulado = linea.Anulado;
                conservadas.Add(existente.Id);
            }
            else
            {
                linea.NotaVentaId = notaVentaId;
                linea.Id = 0;
                await _context.NotaVentaDetalles.AddAsync(linea);
            }
        }

        foreach (var quitada in actuales.Where(d => !conservadas.Contains(d.Id)))
        {
            quitada.Anulado = true;
        }

        await _context.SaveChangesAsync();
    }
}
