using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Compras: lo comprado en las fechas (por compra, proveedor, producto, categoría o día), lo que
/// se pagó y lo que se le debe hoy a cada proveedor (con la regla de Cuentas por pagar).
///
/// Las vistas de lo comprado salen de las líneas: así filtrar por categoría o producto recorta el
/// importe de cada compra a lo de esa categoría, en vez de mostrar la compra entera.
/// </summary>
public partial class ReportesService
{
    private async Task<ReporteResponse> ComprasAsync(ReporteRequest request)
    {
        var (primero, ultimo) = Rango(request);
        var hoy = Zona.Hoy;
        var inicio = Zona.AUtc(primero);
        var fin = Zona.AUtc(ultimo.AddDays(1));
        List<VistaReporte> vistas =
        [
            V("compra", "Por compra"), V("proveedor", "Por proveedor"), V("producto", "Por producto"),
            V("categoria", "Por categoría"), V("dia", "Por día"), V("deuda", "Por pagar"), V("pagos", "Pagos"),
        ];
        var vista = VistaDe(request, vistas);

        var lineas = (await context.Compras
                .Where(c => c.Estado != EstadoCompra.Anulada && c.Fecha >= inicio && c.Fecha < fin)
                .SelectMany(c => c.Detalle.Select(d => new
                {
                    CompraId = c.Id,
                    c.Numero,
                    c.Fecha,
                    Proveedor = c.Proveedor != null ? c.Proveedor.Nombre : "Sin proveedor",
                    Comprobante = c.TipoComprobante + " " + (c.SerieComprobante ?? "") + "-" + (c.NumeroComprobante ?? ""),
                    c.FormaPago,
                    c.Estado,
                    d.ProductoId,
                    Producto = d.Producto!.Nombre,
                    Codigo = d.Producto.Codigo,
                    Categoria = d.Producto.Categoria != null ? d.Producto.Categoria.Nombre : "Sin categoría",
                    Unidad = d.Producto.UnidadBase != null ? d.Producto.UnidadBase.Codigo : "",
                    d.Cantidad,
                    Importe = d.Cantidad * d.CostoUnitario,
                }))
                .AsNoTracking()
                .ToListAsync())
            .Select(l => new
            {
                l.CompraId, l.Numero, Dia = Zona.DiaDe(l.Fecha), l.Proveedor, Comprobante = l.Comprobante.Trim(' ', '-'),
                l.FormaPago, l.Estado, l.ProductoId, l.Producto, l.Codigo, l.Categoria, l.Unidad, l.Cantidad, l.Importe,
            })
            .ToList();

        // Lo que se debe hoy: la regla de Cuentas por pagar, sea de cuando sea la compra.
        var abiertas = (await context.Compras
                .Where(c => c.Estado != EstadoCompra.Anulada && c.FormaPago == FormaPagoCompra.Credito)
                .Select(c => new
                {
                    c.Id,
                    c.Numero,
                    c.Fecha,
                    Proveedor = c.Proveedor != null ? c.Proveedor.Nombre : "Sin proveedor",
                    c.Estado,
                    Total = c.Detalle.Sum(d => (decimal?)(d.Cantidad * d.CostoUnitario)) ?? 0m,
                    Pagado = c.Pagos.Where(p => !p.Anulado).Sum(p => (decimal?)p.Monto) ?? 0m,
                })
                .Where(c => Math.Round(c.Total, 2) > c.Pagado)
                .AsNoTracking()
                .ToListAsync())
            .Select(c => new
            {
                c.Id, c.Numero, Dia = Zona.DiaDe(c.Fecha), c.Proveedor, c.Estado,
                Total = Math.Round(c.Total, 2), c.Pagado, Saldo = Math.Round(c.Total, 2) - c.Pagado,
                Dias = Math.Max(0, (int)(hoy - Zona.DiaDe(c.Fecha)).TotalDays),
            })
            .ToList();

        var pagos = (await context.CompraPagos
                .Where(p => !p.Anulado && p.Compra!.Estado != EstadoCompra.Anulada && p.Fecha >= inicio && p.Fecha < fin)
                .Select(p => new
                {
                    p.Id,
                    p.Fecha,
                    p.Monto,
                    Compra = p.Compra!.Numero,
                    Proveedor = p.Compra.Proveedor != null ? p.Compra.Proveedor.Nombre : "Sin proveedor",
                    Metodo = p.MetodoPago != null ? p.MetodoPago.Nombre : "Otro",
                })
                .AsNoTracking()
                .ToListAsync())
            .Select(p => new { p.Id, Dia = Zona.DiaDe(p.Fecha), p.Monto, p.Compra, p.Proveedor, p.Metodo })
            .ToList();

        static string TextoForma(string forma) => forma == FormaPagoCompra.Credito ? "Crédito" : "Contado";
        static string TextoEstado(string estado) => estado switch
        {
            EstadoCompra.Pendiente => "Por recibir",
            EstadoCompra.RecibidaParcial => "Recibida en parte",
            EstadoCompra.RecibidaTotal => "Recibida",
            _ => estado,
        };

        List<FiltroReporte> filtros =
        [
            Filtro("proveedor", "Proveedor", lineas.Select(l => l.Proveedor).Concat(abiertas.Select(a => a.Proveedor))),
            Filtro("categoria", "Categoría", lineas.Select(l => l.Categoria)),
            Filtro("producto", "Producto", lineas.Select(l => (l.ProductoId.ToString(), l.Producto))),
            Filtro("pago", "Forma de pago", lineas.Select(l => (l.FormaPago, TextoForma(l.FormaPago)))),
            Filtro("estado", "Estado", lineas.Select(l => (l.Estado, TextoEstado(l.Estado))).Concat(abiertas.Select(a => (a.Estado, TextoEstado(a.Estado))))),
        ];

        string? F(string clave) => request.Filtro(clave);
        var compradas = lineas.Where(l =>
                (F("proveedor") is not string prov || l.Proveedor == prov)
                && (F("categoria") is not string cat || l.Categoria == cat)
                && (F("producto") is not string prod || l.ProductoId.ToString() == prod)
                && (F("pago") is not string pago || l.FormaPago == pago)
                && (F("estado") is not string est || l.Estado == est))
            .ToList();
        var deuda = abiertas.Where(a =>
                (F("proveedor") is not string prov || a.Proveedor == prov)
                && (F("estado") is not string est || a.Estado == est))
            .ToList();
        var pagado = pagos.Where(p => F("proveedor") is not string prov || p.Proveedor == prov).ToList();

        List<ColumnaReporte> columnas;
        IEnumerable<Dictionary<string, object?>> filas;
        var total = Col("total", "Total", TipoDato.Moneda, suma: true, destacada: true, ancho: 76);
        var nCompras = Col("compras", "Compras", TipoDato.Entero, suma: true, ancho: 56);

        switch (vista)
        {
            case "proveedor":
                columnas = [Col("nombre", "Proveedor"), nCompras, total];
                filas = compradas.GroupBy(l => l.Proveedor).OrderByDescending(g => g.Sum(l => l.Importe))
                    .Select(g => Fila(g.Key, ("nombre", g.Key), ("compras", g.Select(l => l.CompraId).Distinct().Count()),
                                      ("total", R2(g.Sum(l => l.Importe)))));
                break;
            case "producto":
                // Una compra con dos productos cae en dos filas: aquí las compras no se suman.
                columnas = [Col("nombre", "Producto", apoyo: "detalle"),
                            Col("cantidad", "Cantidad", TipoDato.Cantidad, apoyo: "unidad", ancho: 66),
                            Col("compras", "Compras", TipoDato.Entero, ancho: 56),
                            Col("costoPromedio", "Costo prom.", TipoDato.Moneda, ancho: 70), total];
                filas = compradas.GroupBy(l => l.ProductoId).OrderByDescending(g => g.Sum(l => l.Importe))
                    .Select(g =>
                    {
                        var una = g.First();
                        var cantidad = g.Sum(l => l.Cantidad);
                        return Fila(g.Key.ToString(), ("nombre", una.Producto), ("detalle", $"{una.Codigo} · {una.Categoria}"),
                            ("cantidad", cantidad), ("unidad", una.Unidad), ("compras", g.Select(l => l.CompraId).Distinct().Count()),
                            ("costoPromedio", cantidad > 0 ? R2(g.Sum(l => l.Importe) / cantidad) : 0m), ("total", R2(g.Sum(l => l.Importe))));
                    });
                break;
            case "categoria":
                columnas = [Col("nombre", "Categoría"), Col("productos", "Productos", TipoDato.Entero, suma: true, ancho: 60), total];
                filas = compradas.GroupBy(l => l.Categoria).OrderByDescending(g => g.Sum(l => l.Importe))
                    .Select(g => Fila(g.Key, ("nombre", g.Key), ("productos", g.Select(l => l.ProductoId).Distinct().Count()),
                                      ("total", R2(g.Sum(l => l.Importe)))));
                break;
            case "dia":
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, apoyo: "semana"), nCompras,
                            Col("contado", "Contado", TipoDato.Moneda, suma: true, ancho: 76),
                            Col("credito", "Crédito", TipoDato.Moneda, suma: true, ancho: 76), total];
                filas = compradas.GroupBy(l => l.Dia).OrderBy(g => g.Key)
                    .Select(g => Fila(g.Key.ToString("yyyy-MM-dd"), ("fecha", g.Key), ("semana", DiaSemana(g.Key)),
                        ("compras", g.Select(l => l.CompraId).Distinct().Count()),
                        ("contado", R2(g.Where(l => l.FormaPago != FormaPagoCompra.Credito).Sum(l => l.Importe))),
                        ("credito", R2(g.Where(l => l.FormaPago == FormaPagoCompra.Credito).Sum(l => l.Importe))),
                        ("total", R2(g.Sum(l => l.Importe)))));
                break;
            case "deuda":
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, ancho: 64), Col("numero", "Compra", ancho: 70),
                            Col("proveedor", "Proveedor"), Col("dias", "Días", TipoDato.Entero, ancho: 44),
                            Col("totalCompra", "Total", TipoDato.Moneda, suma: true, ancho: 72),
                            Col("pagado", "Pagado", TipoDato.Moneda, suma: true, ancho: 72),
                            Col("saldo", "Saldo", TipoDato.Moneda, suma: true, destacada: true, ancho: 74)];
                filas = deuda.OrderByDescending(a => a.Dias)
                    .Select(a => Fila(a.Id.ToString(), ("fecha", a.Dia), ("numero", a.Numero), ("proveedor", a.Proveedor),
                        ("dias", a.Dias), ("totalCompra", a.Total), ("pagado", R2(a.Pagado)), ("saldo", R2(a.Saldo))));
                break;
            case "pagos":
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, ancho: 64), Col("numero", "Compra", ancho: 70),
                            Col("proveedor", "Proveedor"), Col("metodo", "Método", ancho: 100),
                            Col("monto", "Monto", TipoDato.Moneda, suma: true, destacada: true, ancho: 76)];
                filas = pagado.OrderByDescending(p => p.Dia).ThenByDescending(p => p.Id)
                    .Select(p => Fila(p.Id.ToString(), ("fecha", p.Dia), ("numero", p.Compra), ("proveedor", p.Proveedor),
                        ("metodo", p.Metodo), ("monto", R2(p.Monto))));
                break;
            default:
                columnas = [Col("fecha", "Fecha", TipoDato.Fecha, ancho: 64), Col("numero", "Compra", ancho: 70),
                            Col("proveedor", "Proveedor", apoyo: "comprobante"), Col("pago", "Pago", ancho: 54),
                            Col("estado", "Estado", ancho: 84), total];
                filas = compradas.GroupBy(l => l.CompraId).OrderByDescending(g => g.First().Dia).ThenByDescending(g => g.Key)
                    .Select(g =>
                    {
                        var una = g.First();
                        return Fila(g.Key.ToString(), ("fecha", una.Dia), ("numero", una.Numero), ("proveedor", una.Proveedor),
                            ("comprobante", una.Comprobante), ("pago", TextoForma(una.FormaPago)), ("estado", TextoEstado(una.Estado)),
                            ("total", R2(g.Sum(l => l.Importe))));
                    });
                break;
        }

        var aviso = vista == "deuda"
            ? "Por pagar es lo que se debe hoy, sea de cuando sea la compra: las fechas no lo recortan."
            : (F("categoria") ?? F("producto")) is not null
                ? "Con categoría o producto elegidos, cada compra muestra solo lo de ese filtro."
                : null;

        return new ReporteResponse
        {
            Titulo = "Reporte de compras",
            Vista = vista,
            Vistas = vistas,
            ConFechas = true,
            Desde = primero,
            Hasta = ultimo,
            Columnas = columnas,
            Filas = filas.ToList(),
            Filtros = filtros,
            Resumen =
            [
                Resumen("Comprado", compradas.Sum(l => l.Importe), tono: "sys", nota: $"{compradas.Select(l => l.CompraId).Distinct().Count()} compras"),
                Resumen("Pagado", pagado.Sum(p => p.Monto), tono: "success", nota: "A proveedores, en las fechas"),
                Resumen("Por pagar", deuda.Sum(a => a.Saldo), tono: "warning", nota: "Hoy"),
                Resumen("Más de 30 días", deuda.Where(a => a.Dias > 30).Sum(a => a.Saldo), tono: "danger"),
            ],
            Aviso = aviso,
        };
    }
}
