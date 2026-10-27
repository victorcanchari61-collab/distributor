using Backend.Data;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Productos sin ventas: lo que está en el catálogo, tenga o no stock, y no se vende.
///
/// Un producto "se vendió" si lo vendido en los últimos N días, menos lo recogido, es mayor que
/// cero. Con un mercado o una ruta, solo cuentan las ventas a clientes de esa zona: así se ve qué
/// producto se mueve en otras partes y ahí no.
/// </summary>
public class CrmProductosService : ICrmProductosService
{
    private const int MaxDias = 365;

    private readonly AppDbContext _context;

    public CrmProductosService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<CrmProductosResponse> SinVentasAsync(
        int dias, int? mercadoId, int? rutaId, int? categoriaId, string? stock)
    {
        if (dias < 1 || dias > MaxDias)
            throw new BadRequestException($"Elige entre 1 y {MaxDias} días.");
        if (stock is not null && stock is not ("con" or "sin"))
            throw new BadRequestException("El filtro de stock es con o sin.");

        var hoy = Zona.Hoy;
        var desde = hoy.AddDays(-(dias - 1));
        var ini = Zona.AUtc(desde);
        var fin = Zona.AUtc(hoy.AddDays(1));
        var conZona = mercadoId is not null || rutaId is not null;

        var productos = _context.Productos.AsNoTracking().Where(p => p.Activo);
        if (categoriaId is int cat) productos = productos.Where(p => p.CategoriaId == cat);

        var catalogo = await productos
            .Select(p => new
            {
                p.Id,
                p.Codigo,
                p.Nombre,
                p.CategoriaId,
                Categoria = p.Categoria != null ? p.Categoria.Nombre : null,
                Marca = p.Marca != null ? p.Marca.Nombre : null,
                UnidadBase = p.UnidadBase != null ? p.UnidadBase.Codigo : string.Empty,
            })
            .ToListAsync();

        var existencias = await _context.CapasCosto.AsNoTracking()
            .Where(c => c.CantidadDisponible > 0)
            .GroupBy(c => c.ProductoId)
            .Select(g => new
            {
                ProductoId = g.Key,
                Stock = g.Sum(c => c.CantidadDisponible),
                Valor = g.Sum(c => c.CantidadDisponible * c.CostoUnitario),
            })
            .ToDictionaryAsync(x => x.ProductoId);

        var vendidoZona = await VendidoAsync(ini, fin, mercadoId, rutaId);
        var vendidoTodo = conZona ? await VendidoAsync(ini, fin, null, null) : vendidoZona;
        var ultimas = await UltimasVentasAsync(mercadoId, rutaId);

        var items = new List<CrmProductoSinVentaResponse>();
        foreach (var p in catalogo)
        {
            // Si el neto del periodo es positivo, se vendió: no es noticia.
            if (vendidoZona.GetValueOrDefault(p.Id) > 0) continue;

            existencias.TryGetValue(p.Id, out var existencia);
            ultimas.TryGetValue(p.Id, out var ultima);
            var tiene = ultima != default;

            items.Add(new CrmProductoSinVentaResponse
            {
                ProductoId = p.Id,
                Codigo = p.Codigo,
                Producto = p.Nombre,
                CategoriaId = p.CategoriaId,
                Categoria = p.Categoria,
                Marca = p.Marca,
                UnidadBase = p.UnidadBase,
                Stock = existencia?.Stock ?? 0m,
                ValorStock = Math.Round(existencia?.Valor ?? 0m, 2),
                UltimaVenta = tiene ? Zona.DiaDe(ultima) : null,
                DiasSinVender = tiene ? Math.Max(0, (int)(hoy - Zona.DiaDe(ultima)).TotalDays) : null,
                VendidoEnOtrasZonas = conZona
                    ? Math.Round(Math.Max(0m, vendidoTodo.GetValueOrDefault(p.Id) - vendidoZona.GetValueOrDefault(p.Id)), 2)
                    : 0m,
            });
        }

        // El resumen es de todo lo que no se vendió, antes de elegir con o sin stock: así los
        // contadores no cambian al tocar ese filtro.
        var resumen = new CrmProductosResumenResponse
        {
            ProductosActivos = catalogo.Count,
            SinVentas = items.Count,
            ConStock = items.Count(i => i.Stock > 0),
            SinStock = items.Count(i => i.Stock <= 0),
            NuncaVendidos = items.Count(i => i.UltimaVenta is null),
            CapitalParado = items.Sum(i => i.ValorStock),
        };

        if (stock == "con") items = items.Where(i => i.Stock > 0).ToList();
        else if (stock == "sin") items = items.Where(i => i.Stock <= 0).ToList();

        return new CrmProductosResponse
        {
            Dias = dias,
            Rango = new CrmRango { Desde = desde, Hasta = hoy },
            Mercado = mercadoId is int m
                ? await _context.Mercados.Where(x => x.Id == m).Select(x => x.Nombre).FirstOrDefaultAsync()
                : null,
            Ruta = rutaId is int r
                ? await _context.Rutas.Where(x => x.Id == r).Select(x => x.Nombre).FirstOrDefaultAsync()
                : null,
            Resumen = resumen,
            // La plata parada primero; a igual valor, el que lleva más tiempo sin moverse.
            Items = items
                .OrderByDescending(i => i.ValorStock)
                .ThenByDescending(i => i.DiasSinVender ?? int.MaxValue)
                .ThenBy(i => i.Producto)
                .ToList(),
        };
    }

    /// <summary>
    /// Lo vendido por producto en [ini, fin), en importe: las líneas vigentes menos lo recogido.
    /// Con mercado o ruta, solo a los clientes de esa zona.
    /// </summary>
    private async Task<Dictionary<int, decimal>> VendidoAsync(DateTime ini, DateTime fin, int? mercadoId, int? rutaId)
    {
        var lineas = _context.NotaVentaDetalles
            .Where(d => !d.Anulado
                        && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && d.NotaVenta.Fecha >= ini && d.NotaVenta.Fecha < fin);
        var recojos = _context.RecojosVenta
            .Where(r => r.Estado != EstadoRecojo.Anulado
                        && r.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && r.NotaVenta.Fecha >= ini && r.NotaVenta.Fecha < fin);

        if (mercadoId is int m)
        {
            lineas = lineas.Where(d => d.NotaVenta!.Cliente!.MercadoId == m);
            recojos = recojos.Where(r => r.NotaVenta!.Cliente!.MercadoId == m);
        }
        if (rutaId is int ru)
        {
            lineas = lineas.Where(d => d.NotaVenta!.Cliente!.RutaId == ru);
            recojos = recojos.Where(r => r.NotaVenta!.Cliente!.RutaId == ru);
        }

        var vendido = await lineas
            .GroupBy(d => d.ProductoId)
            .Select(g => new { ProductoId = g.Key, Importe = g.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Importe);

        var recogido = await recojos
            .GroupBy(r => r.ProductoId)
            .Select(g => new { ProductoId = g.Key, Importe = g.Sum(r => r.Importe) })
            .ToListAsync();

        foreach (var r in recogido)
            vendido[r.ProductoId] = vendido.GetValueOrDefault(r.ProductoId) - r.Importe;

        return vendido;
    }

    /// <summary>La fecha (UTC) de la última venta vigente de cada producto, sin límite de días.</summary>
    private async Task<Dictionary<int, DateTime>> UltimasVentasAsync(int? mercadoId, int? rutaId)
    {
        var lineas = _context.NotaVentaDetalles
            .Where(d => !d.Anulado && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada);
        if (mercadoId is int m) lineas = lineas.Where(d => d.NotaVenta!.Cliente!.MercadoId == m);
        if (rutaId is int r) lineas = lineas.Where(d => d.NotaVenta!.Cliente!.RutaId == r);

        return await lineas
            .GroupBy(d => d.ProductoId)
            .Select(g => new { ProductoId = g.Key, Ultima = g.Max(d => d.NotaVenta!.Fecha) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Ultima);
    }
}
