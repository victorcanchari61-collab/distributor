using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// Ventas y Rentabilidad: las mismas líneas vendidas de Mis ganancias —con su costo y los
/// recojos restados—. Ventas mira lo cobrado (con IGV); Rentabilidad, lo que deja (sin IGV) y se
/// ordena por ganancia.
/// </summary>
public partial class ReportesService
{
    private async Task<ReporteResponse> LineasVendidasAsync(ReporteRequest request, bool rentabilidad)
    {
        var (primero, ultimo) = Rango(request);
        List<VistaReporte> vistas = rentabilidad
            ? [V("producto", "Producto"), V("categoria", "Categoría"), V("marca", "Marca"), V("vendedor", "Vendedor"),
               V("cliente", "Cliente"), V("ruta", "Ruta"), V("dia", "Día")]
            : [V("producto", "Producto"), V("nota", "Nota de venta"), V("dia", "Día"), V("categoria", "Categoría"),
               V("cliente", "Cliente"), V("vendedor", "Vendedor"), V("ruta", "Ruta")];
        var vista = VistaDe(request, vistas);

        var (lineas, soloPropio) = await ganancias.LineasAsync(Zona.AUtc(primero), Zona.AUtc(ultimo.AddDays(1)));

        // Las opciones salen de todo el rango, antes de filtrar: elegir un cliente no vacía la lista
        // de categorías, y nunca se ofrece algo que no se vendió en esas fechas.
        List<FiltroReporte> filtros =
        [
            Filtro("categoria", "Categoría", lineas.Select(l => l.Categoria)),
            Filtro("marca", "Marca", lineas.Select(l => l.Marca)),
            Filtro("producto", "Producto", lineas.Select(l => (l.ProductoId.ToString(), l.Producto))),
            Filtro("cliente", "Cliente", lineas.Select(l => l.Cliente)),
            Filtro("vendedor", "Vendedor", lineas.Select(l => l.Vendedor)),
            Filtro("ruta", "Ruta", lineas.Select(l => l.Ruta)),
            Filtro("pago", "Forma de pago", lineas.Select(l => (l.FormaPago, TextoFormaPago(l.FormaPago)))),
        ];

        string? F(string clave) => request.Filtro(clave);
        var filtradas = lineas.Where(l =>
                (F("categoria") is not string cat || l.Categoria == cat)
                && (F("marca") is not string marca || l.Marca == marca)
                && (F("producto") is not string prod || l.ProductoId.ToString() == prod)
                && (F("cliente") is not string cli || l.Cliente == cli)
                && (F("vendedor") is not string ven || l.Vendedor == ven)
                && (F("ruta") is not string ruta || l.Ruta == ruta)
                && (F("pago") is not string pago || l.FormaPago == pago))
            .ToList();

        var grupos = vista switch
        {
            "nota" => filtradas.GroupBy(l => l.NotaVentaId.ToString()),
            "dia" => filtradas.GroupBy(l => Zona.DiaDe(l.Fecha).ToString("yyyy-MM-dd")),
            "categoria" => filtradas.GroupBy(l => l.Categoria),
            "marca" => filtradas.GroupBy(l => l.Marca),
            "cliente" => filtradas.GroupBy(l => l.Cliente),
            "vendedor" => filtradas.GroupBy(l => l.Vendedor),
            "ruta" => filtradas.GroupBy(l => l.Ruta),
            _ => filtradas.GroupBy(l => l.ProductoId.ToString()),
        };

        var filas = grupos.Select(g =>
        {
            var una = g.First();
            var valor = g.Sum(l => l.ValorVenta);
            var costo = g.Sum(l => l.Costo);
            var fila = Fila(g.Key,
                ("ventas", g.Select(l => l.NotaVentaId).Distinct().Count()),
                ("importe", R2(g.Sum(l => l.Importe))),
                ("valorVenta", R2(valor)),
                ("costo", R2(costo)),
                ("ganancia", R2(valor - costo)),
                ("margen", Pct(valor - costo, valor)));

            switch (vista)
            {
                case "nota":
                    fila["fecha"] = Zona.DiaDe(una.Fecha);
                    fila["nombre"] = una.Venta;
                    fila["cliente"] = una.Cliente;
                    fila["ruta"] = una.Ruta;
                    fila["vendedor"] = una.Vendedor;
                    fila["pago"] = TextoFormaPago(una.FormaPago);
                    break;
                case "dia":
                    var dia = Zona.DiaDe(una.Fecha);
                    fila["fecha"] = dia;
                    fila["semana"] = DiaSemana(dia);
                    break;
                case "producto":
                    fila["nombre"] = una.Producto;
                    fila["detalle"] = $"{una.Codigo} · {una.Categoria}";
                    fila["cantidad"] = g.Sum(l => l.Cantidad);
                    fila["unidad"] = una.UnidadBase;
                    break;
                case "cliente":
                    fila["nombre"] = una.Cliente;
                    fila["detalle"] = una.Ruta;
                    break;
                default:
                    fila["nombre"] = g.Key;
                    break;
            }

            return fila;
        });

        filas = vista switch
        {
            "nota" => filas.OrderByDescending(f => (DateTime)f["fecha"]!).ThenByDescending(f => (string)f["nombre"]!),
            "dia" => filas.OrderBy(f => (DateTime)f["fecha"]!),
            _ when rentabilidad => filas.OrderByDescending(f => (decimal)f["ganancia"]!),
            _ => filas.OrderByDescending(f => (decimal)f["importe"]!),
        };

        // Las ventas solo se suman donde cada nota cae en una sola fila: en "por producto" una
        // nota con tres productos se contaría tres veces.
        var ventasSuman = vista is "nota" or "dia" or "cliente" or "vendedor" or "ruta";
        var ventas = Col("ventas", "Ventas", TipoDato.Entero, suma: ventasSuman, ancho: 50);

        List<ColumnaReporte> propias = vista switch
        {
            "nota" =>
            [
                Col("fecha", "Fecha", TipoDato.Fecha, ancho: 64),
                Col("nombre", "Nota", ancho: 66),
                Col("cliente", "Cliente", apoyo: "ruta"),
                Col("vendedor", "Vendedor"),
                Col("pago", "Pago", ancho: 54),
            ],
            "dia" => [Col("fecha", "Fecha", TipoDato.Fecha, apoyo: "semana"), ventas],
            "producto" =>
            [
                Col("nombre", "Producto", apoyo: "detalle"),
                Col("cantidad", "Cantidad", TipoDato.Cantidad, apoyo: "unidad", ancho: 64),
                ventas,
            ],
            _ => [Col("nombre", vistas.First(v => v.Id == vista).Texto, apoyo: vista == "cliente" ? "detalle" : null), ventas],
        };

        List<ColumnaReporte> montos = rentabilidad
            ?
            [
                Col("valorVenta", "Vendido sin IGV", TipoDato.Moneda, suma: true, ancho: 74),
                Col("costo", "Costo", TipoDato.Moneda, suma: true, ancho: 70),
                Col("ganancia", "Ganancia", TipoDato.Moneda, suma: true, destacada: true, ancho: 70),
                ColMargen(),
            ]
            : [
                Col("importe", "Importe", TipoDato.Moneda, suma: true, ancho: 70),
                Col("costo", "Costo", TipoDato.Moneda, suma: true, ancho: 70),
                Col("ganancia", "Ganancia", TipoDato.Moneda, suma: true, destacada: true, ancho: 70),
                ColMargen(),
            ];

        var valorTotal = filtradas.Sum(l => l.ValorVenta);
        var costoTotal = filtradas.Sum(l => l.Costo);
        var gananciaTotal = valorTotal - costoTotal;
        var margen = Pct(gananciaTotal, valorTotal);

        return new ReporteResponse
        {
            Titulo = rentabilidad ? "Reporte de rentabilidad" : "Reporte de ventas",
            Vista = vista,
            Vistas = vistas,
            ConFechas = true,
            Desde = primero,
            Hasta = ultimo,
            Columnas = [.. propias, .. montos],
            Filas = filas.ToList(),
            Filtros = filtros,
            Resumen = rentabilidad
                ?
                [
                    Resumen("Vendido sin IGV", valorTotal, tono: "sys"),
                    Resumen("Costo", costoTotal, tono: "warning"),
                    Resumen("Ganancia", gananciaTotal, tono: gananciaTotal < 0 ? "danger" : "success"),
                    Resumen("Margen", margen ?? 0, TipoDato.Porcentaje, tono: gananciaTotal < 0 ? "danger" : "neutral"),
                ]
                :
                [
                    Resumen("Ventas", filtradas.Select(l => l.NotaVentaId).Distinct().Count(), TipoDato.Entero, "sys"),
                    Resumen("Importe", filtradas.Sum(l => l.Importe), nota: "Lo cobrado, con IGV"),
                    Resumen("Costo", costoTotal, tono: "warning"),
                    Resumen("Ganancia", gananciaTotal, tono: gananciaTotal < 0 ? "danger" : "success",
                        nota: margen is decimal m ? $"Margen {m.ToString("0.0", Peru)}%" : null),
                ],
            Aviso = soloPropio ? "Solo ves las ventas que te tocan: el reporte no es de todo el negocio." : null,
            Nota = "Ganancia: lo vendido sin IGV menos el costo de la mercadería, como en Mis ganancias. " +
                   "Margen: ganancia sobre lo vendido sin IGV.",
        };
    }

    private static string TextoFormaPago(string forma) => forma switch
    {
        FormaPagoVenta.Contado => "Contado",
        FormaPagoVenta.Credito => "Crédito",
        _ => forma,
    };
}
