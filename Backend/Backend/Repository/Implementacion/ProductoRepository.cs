using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class ProductoRepository : IProductoRepository
{
    private readonly AppDbContext _context;

    public ProductoRepository(AppDbContext context)
    {
        _context = context;
    }

    private IQueryable<Producto> ConDetalle() => _context.Productos
        .Include(p => p.Categoria)
        .Include(p => p.Marca)
        .Include(p => p.UnidadBase)
        .Include(p => p.ContenidoUnidad)
        .Include(p => p.Presentaciones)
        .ThenInclude(pr => pr.Unidad);

    public async Task<IEnumerable<Producto>> GetAllConDetalleAsync()
    {
        return await ConDetalle()
            .OrderByDescending(p => p.Activo)
            .ThenBy(p => p.Nombre)
            .ToListAsync();
    }

    public async Task<(List<Producto> Items, int Total)> ListarAsync(ConsultaTablaRequest consulta)
    {
        var query = ConDetalle().AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(p =>
                EF.Functions.Like(p.Codigo, $"%{texto}%")
                || EF.Functions.Like(p.Nombre, $"%{texto}%")
                || (p.Descripcion != null && EF.Functions.Like(p.Descripcion, $"%{texto}%"))
                || (p.Categoria != null && EF.Functions.Like(p.Categoria.Nombre, $"%{texto}%"))
                || (p.Marca != null && EF.Functions.Like(p.Marca.Nombre, $"%{texto}%")));
        }

        if (consulta.ValorDe("codigo") is string codigo)
            query = query.Where(p => EF.Functions.Like(p.Codigo, $"%{codigo}%"));

        if (consulta.ValorDe("nombre") is string nombre)
            query = query.Where(p => EF.Functions.Like(p.Nombre, $"%{nombre}%"));

        if (consulta.ValorDe("categoria") is string categoria)
            query = query.Where(p => p.Categoria != null && p.Categoria.Nombre == categoria);

        if (consulta.ValorDe("marca") is string marca)
            query = query.Where(p => p.Marca != null && p.Marca.Nombre == marca);

        // En pantalla el estado se lee "Activo" / "Inactivo", no true/false.
        if (consulta.ValorDe("activo") is string activo)
            query = query.Where(p => p.Activo == activo.Equals("Activo", StringComparison.OrdinalIgnoreCase));

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "codigo" => desc ? query.OrderByDescending(p => p.Codigo).ThenByDescending(p => p.Id)
                             : query.OrderBy(p => p.Codigo).ThenBy(p => p.Id),
            "nombre" => desc ? query.OrderByDescending(p => p.Nombre).ThenByDescending(p => p.Id)
                             : query.OrderBy(p => p.Nombre).ThenBy(p => p.Id),
            "categoria" => desc ? query.OrderByDescending(p => p.Categoria!.Nombre).ThenByDescending(p => p.Id)
                                : query.OrderBy(p => p.Categoria!.Nombre).ThenBy(p => p.Id),
            "marca" => desc ? query.OrderByDescending(p => p.Marca!.Nombre).ThenByDescending(p => p.Id)
                            : query.OrderBy(p => p.Marca!.Nombre).ThenBy(p => p.Id),
            "activo" => desc ? query.OrderByDescending(p => p.Activo).ThenByDescending(p => p.Id)
                             : query.OrderBy(p => p.Activo).ThenBy(p => p.Id),
            // Por defecto, el orden de siempre: activos primero, luego nombre.
            _ => query.OrderByDescending(p => p.Activo).ThenBy(p => p.Nombre).ThenBy(p => p.Id),
        };

        return await query.PaginarAsync(consulta);
    }

    public async Task<(List<Producto> Items, int Total)> ListarConStockAsync(
        ConsultaTablaRequest consulta, int? almacenId)
    {
        var query = ConDetalle().Where(p => p.ControlaStock).AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(p =>
                EF.Functions.Like(p.Codigo, $"%{texto}%")
                || EF.Functions.Like(p.Nombre, $"%{texto}%")
                || (p.Categoria != null && EF.Functions.Like(p.Categoria.Nombre, $"%{texto}%"))
                || (p.Marca != null && EF.Functions.Like(p.Marca.Nombre, $"%{texto}%")));
        }

        if (consulta.ValorDe("codigo") is string codigo)
            query = query.Where(p => EF.Functions.Like(p.Codigo, $"%{codigo}%"));

        if (consulta.ValorDe("producto") is string nombre)
            query = query.Where(p => EF.Functions.Like(p.Nombre, $"%{nombre}%"));

        if (consulta.ValorDe("categoria") is string categoria)
            query = query.Where(p => p.Categoria != null && p.Categoria.Nombre == categoria);

        // El stock de un producto es la suma de sus capas con saldo. No es una
        // columna, asi que ordenar o filtrar por el va como subconsulta.
        var capas = _context.CapasCosto
            .Where(c => c.CantidadDisponible > 0 && (almacenId == null || c.AlmacenId == almacenId));

        if (consulta.ValorDe("bajoMinimo") is string bajo && bajo.Equals("Si", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(p => p.StockMinimo > 0
                && capas.Where(c => c.ProductoId == p.Id).Sum(c => (decimal?)c.CantidadDisponible).GetValueOrDefault()
                   <= p.StockMinimo);
        }

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "codigo" => desc ? query.OrderByDescending(p => p.Codigo).ThenByDescending(p => p.Id)
                             : query.OrderBy(p => p.Codigo).ThenBy(p => p.Id),
            "categoria" => desc ? query.OrderByDescending(p => p.Categoria!.Nombre).ThenByDescending(p => p.Id)
                                : query.OrderBy(p => p.Categoria!.Nombre).ThenBy(p => p.Id),
            "stock" or "disponible" => desc
                ? query.OrderByDescending(p => capas.Where(c => c.ProductoId == p.Id)
                        .Sum(c => (decimal?)c.CantidadDisponible).GetValueOrDefault()).ThenByDescending(p => p.Id)
                : query.OrderBy(p => capas.Where(c => c.ProductoId == p.Id)
                        .Sum(c => (decimal?)c.CantidadDisponible).GetValueOrDefault()).ThenBy(p => p.Id),
            _ => desc ? query.OrderByDescending(p => p.Nombre).ThenByDescending(p => p.Id)
                      : query.OrderBy(p => p.Nombre).ThenBy(p => p.Id),
        };

        return await query.PaginarAsync(consulta);
    }

    public async Task<ResumenProductosResponse> ResumenAsync() => new()
    {
        Activos = await _context.Productos.CountAsync(p => p.Activo),
        Desactivados = await _context.Productos.CountAsync(p => !p.Activo),
        Presentaciones = await _context.Presentaciones.CountAsync(),
        Categorias = await _context.Productos
            .Where(p => p.Categoria != null)
            .Select(p => p.Categoria!.Nombre).Distinct().OrderBy(n => n).ToListAsync(),
        Marcas = await _context.Productos
            .Where(p => p.Marca != null)
            .Select(p => p.Marca!.Nombre).Distinct().OrderBy(n => n).ToListAsync(),
    };

    public async Task<Producto?> GetConDetalleAsync(int id) =>
        await ConDetalle().FirstOrDefaultAsync(p => p.Id == id);

    public async Task<Producto?> GetByCodigoAsync(string codigo) =>
        await ConDetalle().FirstOrDefaultAsync(p => p.Codigo == codigo);

    public async Task<bool> ExisteCodigoAsync(string codigo, int? excepto = null) =>
        await _context.Productos.AnyAsync(p =>
            p.Codigo == codigo && (excepto == null || p.Id != excepto));

    public async Task<Producto> AddAsync(Producto producto)
    {
        await _context.Productos.AddAsync(producto);
        await _context.SaveChangesAsync();
        return producto;
    }

    public async Task UpdateAsync(Producto producto)
    {
        _context.Productos.Update(producto);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Producto producto)
    {
        _context.Productos.Remove(producto);
        await _context.SaveChangesAsync();
    }

    // --- Presentaciones ---

    public async Task<ProductoPresentacion?> GetPresentacionAsync(int id) =>
        await _context.Presentaciones
            .Include(p => p.Unidad)
            .Include(p => p.Producto)
            .ThenInclude(pr => pr!.UnidadBase)
            .FirstOrDefaultAsync(p => p.Id == id);

    public async Task<ProductoPresentacion> AddPresentacionAsync(ProductoPresentacion presentacion)
    {
        await _context.Presentaciones.AddAsync(presentacion);
        await _context.SaveChangesAsync();
        return presentacion;
    }

    public async Task UpdatePresentacionAsync(ProductoPresentacion presentacion)
    {
        _context.Presentaciones.Update(presentacion);
        await _context.SaveChangesAsync();
    }

    public async Task DeletePresentacionAsync(ProductoPresentacion presentacion)
    {
        _context.Presentaciones.Remove(presentacion);
        await _context.SaveChangesAsync();
    }

    public async Task<int> ContarPreciosAsync(int presentacionId) =>
        await _context.Precios.CountAsync(p => p.PresentacionId == presentacionId);

    public async Task LimpiarPredeterminadaAsync(int productoId, int exceptoId, bool venta)
    {
        var otras = await _context.Presentaciones
            .Where(p => p.ProductoId == productoId && p.Id != exceptoId)
            .ToListAsync();

        foreach (var otra in otras)
        {
            if (venta)
            {
                otra.PredeterminadaVenta = false;
            }
            else
            {
                otra.PredeterminadaCompra = false;
            }
        }

        await _context.SaveChangesAsync();
    }
}
