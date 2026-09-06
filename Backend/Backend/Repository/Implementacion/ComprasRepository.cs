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

    public async Task<(List<OrdenCompra> Items, int Total)> ListarOrdenesAsync(ConsultaTablaRequest consulta)
    {
        var query = OrdenesConDetalle().AsNoTracking().AsQueryable();

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

        return await query.PaginarAsync(consulta);
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
            .Include(c => c.Detalle).ThenInclude(d => d.Presentacion);

    public async Task<Compra?> GetCompraAsync(int id) =>
        await ComprasConDetalle().FirstOrDefaultAsync(c => c.Id == id);

    public async Task<IEnumerable<Compra>> GetComprasAsync(string? estado = null) =>
        await ComprasConDetalle()
            .Where(c => estado == null || c.Estado == estado)
            .OrderByDescending(c => c.Fecha)
            .ThenByDescending(c => c.Id)
            .Take(300)
            .ToListAsync();

    public async Task<(List<Compra> Items, int Total)> ListarComprasAsync(ConsultaTablaRequest consulta)
    {
        var query = ComprasConDetalle().AsNoTracking().AsQueryable();

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

        return await query.PaginarAsync(consulta);
    }

    public async Task<ResumenComprasResponse> ResumenComprasAsync() => new()
    {
        Total = await _context.Compras.CountAsync(),
        PorRecibir = await _context.Compras.CountAsync(c =>
            c.Estado == EstadoCompra.Pendiente || c.Estado == EstadoCompra.RecibidaParcial),
        Recibidas = await _context.Compras.CountAsync(c => c.Estado == EstadoCompra.RecibidaTotal),
    };

    public async Task<List<Compra>> GetComprasAbiertasAsync() =>
        await ComprasConDetalle()
            .Where(c => c.Estado == EstadoCompra.Pendiente || c.Estado == EstadoCompra.RecibidaParcial)
            .OrderByDescending(c => c.Fecha)
            .ThenByDescending(c => c.Id)
            .ToListAsync();

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
