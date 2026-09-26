using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Implementacion;

public class ComprasRepository : IComprasRepository
{
    private readonly AppDbContext _context;

    public ComprasRepository(AppDbContext context)
    {
        _context = context;
    }

    public Task<IDbContextTransaction> IniciarTransaccionAsync() =>
        _context.Database.BeginTransactionAsync();

    public Task GuardarAsync() => _context.SaveChangesAsync();

    // ------------------------------------------------------- Ordenes de compra

    public async Task<string> SiguienteNumeroOrdenAsync()
    {
        var ultimo = await _context.OrdenesCompra
            .OrderByDescending(o => o.Id)
            .Select(o => o.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"OC-{correlativo:D4}";
    }

    public async Task<OrdenCompra> AddOrdenAsync(OrdenCompra orden)
    {
        await _context.OrdenesCompra.AddAsync(orden);
        await _context.SaveChangesAsync();
        return orden;
    }

    private IQueryable<OrdenCompra> OrdenesConDetalle() =>
        _context.OrdenesCompra
            .Include(o => o.Proveedor)
            .Include(o => o.Usuario)
            .Include(o => o.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(o => o.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<OrdenCompra?> GetOrdenAsync(int id) =>
        await OrdenesConDetalle().FirstOrDefaultAsync(o => o.Id == id);

    public async Task<IEnumerable<OrdenCompra>> GetOrdenesAsync(string? estado = null) =>
        await OrdenesConDetalle()
            .Where(o => estado == null || o.Estado == estado)
            .OrderByDescending(o => o.Fecha)
            .ThenByDescending(o => o.Id)
            .Take(300)
            .ToListAsync();

    public async Task<(List<OrdenCompraFilaResponse> Items, int Total)> ListarOrdenesAsync(ConsultaTablaRequest consulta)
    {
        // Sin Include: la fila se proyecta al final, sin las líneas.
        var query = _context.OrdenesCompra.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(o =>
                EF.Functions.Like(o.Numero, $"%{texto}%")
                || (o.Proveedor != null && EF.Functions.Like(o.Proveedor.Nombre, $"%{texto}%"))
                || (o.Proveedor != null && EF.Functions.Like(o.Proveedor.Documento, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
            query = query.Where(o => EF.Functions.Like(o.Numero, $"%{numero}%"));

        if (consulta.ValorDe("proveedor") is string proveedor)
            query = query.Where(o => o.Proveedor != null && EF.Functions.Like(o.Proveedor.Nombre, $"%{proveedor}%"));

        if (consulta.ValorDe("estado") is string estado)
            query = query.Where(o => o.Estado == estado);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(o => o.Fecha >= desde);
        if (hasta is not null) query = query.Where(o => o.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc ? query.OrderByDescending(o => o.Numero).ThenByDescending(o => o.Id)
                             : query.OrderBy(o => o.Numero).ThenBy(o => o.Id),
            "proveedor" => desc ? query.OrderByDescending(o => o.Proveedor!.Nombre).ThenByDescending(o => o.Id)
                                : query.OrderBy(o => o.Proveedor!.Nombre).ThenBy(o => o.Id),
            "estado" => desc ? query.OrderByDescending(o => o.Estado).ThenByDescending(o => o.Id)
                             : query.OrderBy(o => o.Estado).ThenBy(o => o.Id),
            "total" => desc
                ? query.OrderByDescending(o => o.Detalle.Sum(d => d.Cantidad * d.CostoUnitario)).ThenByDescending(o => o.Id)
                : query.OrderBy(o => o.Detalle.Sum(d => d.Cantidad * d.CostoUnitario)).ThenBy(o => o.Id),
            _ => desc ? query.OrderByDescending(o => o.Fecha).ThenByDescending(o => o.Id)
                      : query.OrderBy(o => o.Fecha).ThenBy(o => o.Id),
        };

        var pagina = await query
            .Select(o => new OrdenCompraFilaResponse
            {
                Id = o.Id,
                Numero = o.Numero,
                ProveedorId = o.ProveedorId,
                Proveedor = o.Proveedor != null ? o.Proveedor.Nombre : string.Empty,
                Fecha = o.Fecha,
                FechaEsperada = o.FechaEsperada,
                Estado = o.Estado,
                Usuario = o.Usuario != null ? o.Usuario.Nombre : null,
                Total = o.Detalle.Sum(d => d.Cantidad * d.CostoUnitario),
            })
            .PaginarAsync(consulta);

        foreach (var f in pagina.Items) f.Total = Math.Round(f.Total, 2);
        return pagina;
    }

    public async Task<ResumenOrdenesCompraResponse> ResumenOrdenesAsync() => new()
    {
        Total = await _context.OrdenesCompra.CountAsync(),
        Pendientes = await _context.OrdenesCompra.CountAsync(o => o.Estado == EstadoOrdenCompra.Pendiente),
        Confirmadas = await _context.OrdenesCompra.CountAsync(o => o.Estado == EstadoOrdenCompra.Confirmada),
    };

    public async Task UpdateOrdenAsync(OrdenCompra orden)
    {
        _context.OrdenesCompra.Update(orden);
        await _context.SaveChangesAsync();
    }

    public async Task ReemplazarDetalleOrdenAsync(int ordenId, IEnumerable<OrdenCompraDetalle> detalle)
    {
        var actuales = await _context.OrdenCompraDetalles
            .Where(d => d.OrdenCompraId == ordenId)
            .ToListAsync();

        _context.OrdenCompraDetalles.RemoveRange(actuales);
        await _context.OrdenCompraDetalles.AddRangeAsync(detalle);
        await _context.SaveChangesAsync();
    }

    // ------------------------------------------------------------------ Compras

    public async Task<string> SiguienteNumeroCompraAsync()
    {
        var ultimo = await _context.Compras
            .OrderByDescending(c => c.Id)
            .Select(c => c.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"CP-{correlativo:D4}";
    }

    public async Task<Compra> AddCompraAsync(Compra compra)
    {
        await _context.Compras.AddAsync(compra);
        await _context.SaveChangesAsync();
        return compra;
    }

    private IQueryable<Compra> ComprasConDetalle() =>
        _context.Compras
            .Include(c => c.Proveedor)
            .Include(c => c.OrdenCompra)
            .Include(c => c.Usuario)
            .Include(c => c.Pagos).ThenInclude(p => p.MetodoPago)
            .Include(c => c.Pagos).ThenInclude(p => p.Usuario)
            .Include(c => c.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(c => c.Detalle).ThenInclude(d => d.Presentacion)
            // Detalle y pagos en consultas separadas: en una sola, cada línea
            // se repetía por cada pago.
            .AsSplitQuery();

    /*
     * Lo que ya se compro y no ha llegado.
     *
     * No se puede partir por almacen: la compra no elige almacen, lo elige la
     * recepcion cuando la mercaderia llega. Asi que esta cifra es del negocio
     * entero, y con eso alcanza para lo que sirve: no volver a comprar algo
     * que ya viene en camino.
     */
    public async Task<Dictionary<int, decimal>> GetEnTransitoPorProductoAsync(IEnumerable<int>? productoIds = null)
    {
        var ids = productoIds?.ToList();
        return await _context.CompraDetalles
            .Where(d => (d.Compra!.Estado == EstadoCompra.Pendiente
                         || d.Compra.Estado == EstadoCompra.RecibidaParcial)
                        && d.Cantidad > d.CantidadRecibida
                        && (ids == null || ids.Contains(d.ProductoId)))
            .GroupBy(d => d.ProductoId)
            .Select(g => new
            {
                ProductoId = g.Key,
                Cantidad = g.Sum(d => d.Cantidad - d.CantidadRecibida)
            })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Cantidad);
    }

    public async Task<Compra?> GetCompraAsync(int id) =>
        await ComprasConDetalle().FirstOrDefaultAsync(c => c.Id == id);

    public async Task<IEnumerable<Compra>> GetComprasAsync(string? estado = null) =>
        await ComprasConDetalle()
            .Where(c => estado == null || c.Estado == estado)
            .OrderByDescending(c => c.Fecha)
            .ThenByDescending(c => c.Id)
            .Take(300)
            .ToListAsync();

    public async Task<(List<CompraFilaResponse> Items, int Total)> ListarComprasAsync(ConsultaTablaRequest consulta)
    {
        // Sin Include: la fila se proyecta al final, sin detalle ni pagos.
        var query = _context.Compras.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(c =>
                EF.Functions.Like(c.Numero, $"%{texto}%")
                || (c.Proveedor != null && EF.Functions.Like(c.Proveedor.Nombre, $"%{texto}%"))
                || (c.Proveedor != null && EF.Functions.Like(c.Proveedor.Documento, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
            query = query.Where(c => EF.Functions.Like(c.Numero, $"%{numero}%"));

        if (consulta.ValorDe("proveedor") is string proveedor)
            query = query.Where(c => c.Proveedor != null && EF.Functions.Like(c.Proveedor.Nombre, $"%{proveedor}%"));

        if (consulta.ValorDe("estado") is string estado)
            query = query.Where(c => c.Estado == estado);

        if (consulta.ValorDe("tipoComprobante") is string tipoComprobante)
            query = query.Where(c => c.TipoComprobante == tipoComprobante);

        // El filtro viaja con el nombre de la columna: "ordenCompraNumero".
        // "Directa" es la que no viene de una orden de compra confirmada.
        if (consulta.ValorDe("ordenCompraNumero") is string origen)
            query = origen.Equals("Directa", StringComparison.OrdinalIgnoreCase)
                ? query.Where(c => c.OrdenCompraId == null)
                : query.Where(c => c.OrdenCompraId != null);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(c => c.Fecha >= desde);
        if (hasta is not null) query = query.Where(c => c.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc ? query.OrderByDescending(c => c.Numero).ThenByDescending(c => c.Id)
                             : query.OrderBy(c => c.Numero).ThenBy(c => c.Id),
            "proveedor" => desc ? query.OrderByDescending(c => c.Proveedor!.Nombre).ThenByDescending(c => c.Id)
                                : query.OrderBy(c => c.Proveedor!.Nombre).ThenBy(c => c.Id),
            "estado" => desc ? query.OrderByDescending(c => c.Estado).ThenByDescending(c => c.Id)
                             : query.OrderBy(c => c.Estado).ThenBy(c => c.Id),
            "total" => desc
                ? query.OrderByDescending(c => c.Detalle.Sum(d => d.Cantidad * d.CostoUnitario)).ThenByDescending(c => c.Id)
                : query.OrderBy(c => c.Detalle.Sum(d => d.Cantidad * d.CostoUnitario)).ThenBy(c => c.Id),
            _ => desc ? query.OrderByDescending(c => c.Fecha).ThenByDescending(c => c.Id)
                      : query.OrderBy(c => c.Fecha).ThenBy(c => c.Id),
        };

        return Redondear(await query.Select(AFila).PaginarAsync(consulta));
    }

    public async Task<ResumenComprasResponse> ResumenComprasAsync() => new()
    {
        Total = await _context.Compras.CountAsync(),
        PorRecibir = await _context.Compras.CountAsync(c =>
            c.Estado == EstadoCompra.Pendiente || c.Estado == EstadoCompra.RecibidaParcial),
        Recibidas = await _context.Compras.CountAsync(c => c.Estado == EstadoCompra.RecibidaTotal),
    };

    /// <summary>
    /// Las compras a credito que todavia deben algo. El saldo no es una
    /// columna: sale del detalle menos los pagos vigentes, asi que va como
    /// subconsulta para que la base resuelva el "debe algo".
    /// </summary>
    private IQueryable<Compra> CuentasPorPagarBase() =>
        _context.Compras
            // Redondeado a centavos, como el total que se muestra: un costo por
            // caja repartido entre 12 deja fracciones de céntimo, y sin esto
            // una compra pagada exacta seguía "debiendo" S/ 0.00.
            .Where(c => c.Estado != EstadoCompra.Anulada
                        && c.FormaPago == FormaPagoCompra.Credito
                        && Math.Round(c.Detalle.Sum(d => d.Cantidad * d.CostoUnitario), 2)
                           > c.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto))
            .AsNoTracking();

    public async Task<(List<CompraFilaResponse> Items, int Total)> ListarCuentasPorPagarAsync(ConsultaTablaRequest consulta)
    {
        var query = CuentasPorPagarBase();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(c =>
                EF.Functions.Like(c.Numero, $"%{texto}%")
                || (c.Proveedor != null && EF.Functions.Like(c.Proveedor.Nombre, $"%{texto}%"))
                || (c.Proveedor != null && EF.Functions.Like(c.Proveedor.Documento, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
            query = query.Where(c => EF.Functions.Like(c.Numero, $"%{numero}%"));

        if (consulta.ValorDe("proveedor") is string proveedor)
            query = query.Where(c => c.Proveedor != null && EF.Functions.Like(c.Proveedor.Nombre, $"%{proveedor}%"));

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(c => c.Fecha >= desde);
        if (hasta is not null) query = query.Where(c => c.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc ? query.OrderByDescending(c => c.Numero).ThenByDescending(c => c.Id)
                             : query.OrderBy(c => c.Numero).ThenBy(c => c.Id),
            "proveedor" => desc ? query.OrderByDescending(c => c.Proveedor!.Nombre).ThenByDescending(c => c.Id)
                                : query.OrderBy(c => c.Proveedor!.Nombre).ThenBy(c => c.Id),
            "saldo" => desc
                ? query.OrderByDescending(c => c.Detalle.Sum(d => d.Cantidad * d.CostoUnitario)
                        - c.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto)).ThenByDescending(c => c.Id)
                : query.OrderBy(c => c.Detalle.Sum(d => d.Cantidad * d.CostoUnitario)
                        - c.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto)).ThenBy(c => c.Id),
            _ => desc ? query.OrderByDescending(c => c.Fecha).ThenByDescending(c => c.Id)
                      : query.OrderBy(c => c.Fecha).ThenBy(c => c.Id),
        };

        return Redondear(await query.Select(AFila).PaginarAsync(consulta));
    }

    public async Task<ResumenCuentasResponse> ResumenCuentasPorPagarAsync()
    {
        // Una fila por cuenta abierta, con los totales como en la tabla.
        var cuentas = await CuentasPorPagarBase().Select(AFila).ToListAsync();
        var facturado = cuentas.Sum(c => Math.Round(c.Total, 2));
        var cubierto = cuentas.Sum(c => Math.Round(c.TotalPagado, 2));

        return new ResumenCuentasResponse
        {
            Cuentas = cuentas.Count,
            TotalFacturado = facturado,
            TotalCubierto = cubierto,
            TotalPendiente = facturado - cubierto,
        };
    }

    /// <summary>
    /// Lo que usa el modal de recepción: la compra con sus líneas. Sin pagos,
    /// usuario ni orden: no se muestran ahí.
    /// </summary>
    public async Task<List<Compra>> GetComprasAbiertasAsync() =>
        await _context.Compras
            .AsNoTracking()
            .Include(c => c.Proveedor)
            .Include(c => c.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(c => c.Detalle).ThenInclude(d => d.Presentacion)
            .Where(c => c.Estado == EstadoCompra.Pendiente || c.Estado == EstadoCompra.RecibidaParcial)
            .OrderByDescending(c => c.Fecha)
            .ThenByDescending(c => c.Id)
            .ToListAsync();

    public async Task<List<string>> GetNumerosConRecepcionAsync() =>
        await _context.DocumentosInventario
            .Where(d => d.Tipo == TipoDocumentoInventario.Recepcion && d.Compra != null)
            .Select(d => d.Compra!.Numero)
            .Distinct()
            .OrderByDescending(n => n)
            .ToListAsync();

    /// <summary>La fila de un listado de compras, resuelta por la base.</summary>
    private static readonly System.Linq.Expressions.Expression<Func<Compra, CompraFilaResponse>> AFila = c => new CompraFilaResponse
    {
        Id = c.Id,
        Numero = c.Numero,
        ProveedorId = c.ProveedorId,
        Proveedor = c.Proveedor != null ? c.Proveedor.Nombre : string.Empty,
        OrdenCompraNumero = c.OrdenCompra != null ? c.OrdenCompra.Numero : null,
        Fecha = c.Fecha,
        Estado = c.Estado,
        TipoComprobante = c.TipoComprobante,
        SerieComprobante = c.SerieComprobante,
        NumeroComprobante = c.NumeroComprobante,
        FormaPago = c.FormaPago,
        Total = c.Detalle.Sum(d => d.Cantidad * d.CostoUnitario),
        TotalPagado = c.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto),
    };

    private static (List<CompraFilaResponse> Items, int Total) Redondear(
        (List<CompraFilaResponse> Items, int Total) pagina)
    {
        foreach (var f in pagina.Items)
        {
            f.Total = Math.Round(f.Total, 2);
            f.TotalPagado = Math.Round(f.TotalPagado, 2);
        }
        return pagina;
    }

    public async Task UpdateCompraAsync(Compra compra)
    {
        _context.Compras.Update(compra);
        await _context.SaveChangesAsync();
    }

    public async Task<CompraDetalle?> GetCompraDetalleConCompraAsync(int id) =>
        await _context.CompraDetalles
            .Include(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(d => d.Compra).ThenInclude(c => c!.Detalle)
            .FirstOrDefaultAsync(d => d.Id == id);

    public async Task ReemplazarDetalleCompraAsync(int compraId, IEnumerable<CompraDetalle> detalle)
    {
        var actuales = await _context.CompraDetalles
            .Where(d => d.CompraId == compraId)
            .ToListAsync();

        _context.CompraDetalles.RemoveRange(actuales);
        await _context.CompraDetalles.AddRangeAsync(detalle);
        await _context.SaveChangesAsync();
    }

    public async Task ReemplazarPagosCompraAsync(int compraId, IEnumerable<CompraPago> pagos)
    {
        var actuales = await _context.CompraPagos
            .Where(p => p.CompraId == compraId)
            .ToListAsync();

        _context.CompraPagos.RemoveRange(actuales);
        await _context.CompraPagos.AddRangeAsync(pagos);
        await _context.SaveChangesAsync();
    }
}
