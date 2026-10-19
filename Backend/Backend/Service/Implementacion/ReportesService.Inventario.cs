using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Inventario: lo que hay hoy, valorizado a costo, con cuánto dura al ritmo de venta de los
/// últimos 30 días y lo que vence. Es una foto: no lleva fechas.
///
/// Las mismas reglas del gráfico: stock y valor de las capas de costo disponibles, y el estado
/// (agotado, crítico, atención, sano, sobrestock, sin rotación) por días de cobertura.
/// </summary>
public partial class ReportesService
{
    private static readonly string[] OrdenEstados = ["Agotado", "Crítico", "Atención", "Sano", "Sobrestock", "Sin rotación"];

    private static string EstadoStock(decimal stock, decimal venta, decimal? dias) =>
        venta <= 0 ? "Sin rotación"
        : stock <= 0 ? "Agotado"
        : dias < 7 ? "Crítico"
        : dias < 15 ? "Atención"
        : dias <= 60 ? "Sano"
        : "Sobrestock";

    private async Task<ReporteResponse> InventarioAsync(ReporteRequest request)
    {
        var hoy = Zona.Hoy;
        List<VistaReporte> vistas =
        [
            V("producto", "Por producto"), V("almacen", "Por almacén"), V("categoria", "Por categoría"),
            V("estado", "Por estado"), V("lotes", "Lotes y vencimientos"),
        ];
        var vista = VistaDe(request, vistas);

        var capas = await context.CapasCosto
            .Where(c => c.CantidadDisponible > 0 && c.Producto!.ControlaStock && c.Producto.Activo)
            .Select(c => new
            {
                c.Id,
                c.ProductoId,
                Almacen = c.Almacen != null ? c.Almacen.Nombre : "Sin almacén",
                c.CantidadDisponible,
                c.CostoUnitario,
                c.Lote,
                c.FechaVencimiento,
            })
            .AsNoTracking()
            .ToListAsync();

        // El ritmo de venta: lo vendido en los últimos 30 días, por día. Es de todo el negocio,
        // no de un almacén: así lo calcula también el gráfico.
        var ritmo = await context.NotaVentaDetalles
            .Where(d => !d.Anulado
                        && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && d.NotaVenta.Fecha >= Zona.AUtc(hoy.AddDays(-29)))
            .GroupBy(d => d.ProductoId)
            .Select(g => new { ProductoId = g.Key, Cantidad = g.Sum(d => d.Cantidad) })
            .AsNoTracking()
            .ToDictionaryAsync(x => x.ProductoId, x => x.Cantidad / 30m);

        var ids = capas.Select(c => c.ProductoId).Union(ritmo.Keys).ToList();
        var productos = await context.Productos
            .Where(p => ids.Contains(p.Id) && p.ControlaStock)
            .Select(p => new
            {
                p.Id,
                p.Nombre,
                p.Codigo,
                Categoria = p.Categoria != null ? p.Categoria.Nombre : "Sin categoría",
                Marca = p.Marca != null ? p.Marca.Nombre : "Sin marca",
                Unidad = p.UnidadBase != null ? p.UnidadBase.Codigo : "",
            })
            .AsNoTracking()
            .ToDictionaryAsync(p => p.Id);

        string? F(string clave) => request.Filtro(clave);

        // El almacén recorta las capas; categoría y marca, los productos.
        var capasVista = capas.Where(c => F("almacen") is not string alm || c.Almacen == alm).ToList();

        var filasProducto = productos.Values
            .Select(p =>
            {
                var suyas = capasVista.Where(c => c.ProductoId == p.Id).ToList();
                var stock = suyas.Sum(c => c.CantidadDisponible);
                var valor = suyas.Sum(c => c.CantidadDisponible * c.CostoUnitario);
                var venta = ritmo.GetValueOrDefault(p.Id);
                var dias = venta > 0 ? stock / venta : (decimal?)null;
                return new
                {
                    p.Id, p.Nombre, p.Codigo, p.Categoria, p.Marca, p.Unidad,
                    Stock = stock, Valor = valor, Venta = venta, Dias = dias,
                    Estado = EstadoStock(stock, venta, dias),
                };
            })
            .Where(f => f.Stock > 0 || (f.Venta > 0 && F("almacen") is null))
            .Where(f => (F("categoria") is not string cat || f.Categoria == cat)
                        && (F("marca") is not string marca || f.Marca == marca)
                        && (F("estado") is not string est || f.Estado == est))
            .ToList();

        var deLosProductos = filasProducto.Select(f => f.Id).ToHashSet();

        List<FiltroReporte> filtros =
        [
            Filtro("almacen", "Almacén", capas.Select(c => c.Almacen)),
            Filtro("categoria", "Categoría", productos.Values.Select(p => p.Categoria)),
            Filtro("marca", "Marca", productos.Values.Select(p => p.Marca)),
            new FiltroReporte
            {
                Clave = "estado", Titulo = "Estado",
                Opciones = OrdenEstados.Select(e => new OpcionReporte { Valor = e, Texto = e }).ToList(),
            },
        ];

        List<ColumnaReporte> columnas;
        IEnumerable<Dictionary<string, object?>> filas;
        var valorCol = Col("valor", "Valor", TipoDato.Moneda, suma: true, destacada: true, ancho: 80);

        switch (vista)
        {
            case "almacen":
                // Un producto puede estar en dos almacenes: aquí los productos no se suman.
                columnas = [Col("nombre", "Almacén"), Col("productos", "Productos", TipoDato.Entero, ancho: 60), valorCol];
                filas = capasVista.Where(c => deLosProductos.Contains(c.ProductoId))
                    .GroupBy(c => c.Almacen).OrderByDescending(g => g.Sum(c => c.CantidadDisponible * c.CostoUnitario))
                    .Select(g => Fila(g.Key, ("nombre", g.Key), ("productos", g.Select(c => c.ProductoId).Distinct().Count()),
                                      ("valor", R2(g.Sum(c => c.CantidadDisponible * c.CostoUnitario)))));
                break;
            case "categoria":
            case "estado":
                var porEstado = vista == "estado";
                columnas = [Col("nombre", porEstado ? "Estado" : "Categoría"),
                            Col("productos", "Productos", TipoDato.Entero, suma: true, ancho: 60), valorCol];
                var gruposProd = filasProducto.GroupBy(f => porEstado ? f.Estado : f.Categoria);
                filas = (porEstado
                        ? gruposProd.OrderBy(g => Array.IndexOf(OrdenEstados, g.Key))
                        : gruposProd.OrderByDescending(g => g.Sum(f => f.Valor)))
                    .Select(g => Fila(g.Key, ("nombre", g.Key), ("productos", g.Count()), ("valor", R2(g.Sum(f => f.Valor)))));
                break;
            case "lotes":
                columnas = [Col("nombre", "Producto", apoyo: "lote"), Col("almacen", "Almacén"),
                            Col("vence", "Vence", TipoDato.Fecha, ancho: 64), Col("dias", "Días", TipoDato.Entero, ancho: 44),
                            Col("stock", "Stock", TipoDato.Cantidad, apoyo: "unidad", ancho: 64), valorCol];
                filas = capasVista
                    .Where(c => c.FechaVencimiento is not null && deLosProductos.Contains(c.ProductoId))
                    .OrderBy(c => c.FechaVencimiento)
                    .Select(c =>
                    {
                        var p = productos[c.ProductoId];
                        var vence = c.FechaVencimiento!.Value.Date;
                        return Fila(c.Id.ToString(), ("nombre", p.Nombre), ("lote", string.IsNullOrWhiteSpace(c.Lote) ? "Sin lote" : $"Lote {c.Lote}"),
                            ("almacen", c.Almacen), ("vence", vence), ("dias", (int)(vence - hoy).TotalDays),
                            ("stock", c.CantidadDisponible), ("unidad", p.Unidad), ("valor", R2(c.CantidadDisponible * c.CostoUnitario)));
                    });
                break;
            default:
                columnas = [Col("nombre", "Producto", apoyo: "detalle"),
                            Col("stock", "Stock", TipoDato.Cantidad, apoyo: "unidad", ancho: 64),
                            Col("costo", "Costo prom.", TipoDato.Moneda, ancho: 70), valorCol,
                            Col("ventaDiaria", "Venta/día", TipoDato.Cantidad, ancho: 60),
                            Col("cobertura", "Días que dura", TipoDato.Cantidad, ancho: 66),
                            Col("estado", "Estado", ancho: 74)];
                filas = filasProducto
                    .OrderBy(f => Array.IndexOf(OrdenEstados, f.Estado)).ThenBy(f => f.Dias ?? decimal.MaxValue).ThenBy(f => f.Nombre, Orden)
                    .Select(f => Fila(f.Id.ToString(), ("nombre", f.Nombre), ("detalle", $"{f.Codigo} · {f.Categoria}"),
                        ("stock", Math.Round(f.Stock, 3)), ("unidad", f.Unidad),
                        ("costo", f.Stock > 0 ? R2(f.Valor / f.Stock) : 0m), ("valor", R2(f.Valor)),
                        ("ventaDiaria", Math.Round(f.Venta, 2)), ("cobertura", f.Dias is decimal d ? Math.Round(d, 1) : null),
                        ("estado", f.Estado)));
                break;
        }

        var porVencer = capasVista
            .Where(c => c.FechaVencimiento is not null && deLosProductos.Contains(c.ProductoId)
                        && (c.FechaVencimiento.Value.Date - hoy).TotalDays <= 90)
            .Sum(c => c.CantidadDisponible * c.CostoUnitario);

        return new ReporteResponse
        {
            Titulo = "Reporte de inventario",
            Vista = vista,
            Vistas = vistas,
            ConFechas = false,
            Columnas = columnas,
            Filas = filas.ToList(),
            Filtros = filtros,
            Resumen =
            [
                Resumen("Valor del inventario", filasProducto.Sum(f => f.Valor), tono: "sys"),
                Resumen("Productos con stock", filasProducto.Count(f => f.Stock > 0), TipoDato.Entero),
                Resumen("Por agotarse", filasProducto.Count(f => f.Estado is "Agotado" or "Crítico"), TipoDato.Entero, "danger"),
                Resumen("Vence en 90 días", porVencer, tono: "warning", nota: "Valorizado a costo"),
            ],
            Aviso = F("almacen") is not null
                ? "Con un almacén elegido, el stock es solo el de ese almacén; el ritmo de venta es el de todo el negocio."
                : null,
            Nota = "Días que dura: stock entre lo vendido por día en los últimos 30 días. " +
                   "Estado: agotado, crítico (menos de 7 días), atención (menos de 15), sano (hasta 60), sobrestock (más) o sin rotación (no se vendió).",
        };
    }
}
