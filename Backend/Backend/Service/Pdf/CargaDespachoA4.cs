using System.Globalization;
using Backend.Dtos.Responses;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// Reporte de carga: qué productos hay que subir al camión.
///
/// Suma los pedidos por producto y presentación, sin separar por cliente: al
/// cargar no importa de quién es cada bolsa, sino cuántas hay que subir de cada
/// cosa. Al lado va lo mismo en la unidad base —kilos—, que es lo que se pesa.
///
/// Se puede recortar por mercado y por unidad de medida (solo las bolsas, solo
/// los sacos), y separar en un bloque por mercado cuando el camión se carga en
/// el orden en que va a repartir. Lo que se filtró va escrito en la cabecera:
/// un papel recortado que no lo dice pasa por el total del camión.
///
/// Sale de los pedidos como están AHORA: un aumento o un pedido anulado a
/// última hora ya se ve al volver a sacarlo.
/// </summary>
public sealed class CargaDespachoA4(
    EmpresaResponse empresa,
    DespachoResponse despacho,
    IReadOnlyList<LineaCargaResponse> lineas,
    string? filtros,
    bool porMercado,
    bool aumentos = false) : IDocument
{
    private const float Linea = Comprobante.Linea;

    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(1.2f, Unit.Centimetre);
            page.DefaultTextStyle(x => Comprobante.Estilo(x, 8));

            page.Header().Element(Cabecera);
            // En una columna: puesto directo en el cuerpo de la hoja, el marco
            // se estiraba hasta el pie aunque las filas acabaran antes.
            page.Content().PaddingVertical(8).Column(col => col.Item().Element(Contenido));
            page.Footer().AlignCenter().Text(t =>
            {
                t.DefaultTextStyle(x => x.FontSize(7.5f));
                t.Span($"{despacho.Numero} · Página ");
                t.CurrentPageNumber();
                t.Span(" de ");
                t.TotalPages();
            });
        });

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Element(c => Comprobante.Membrete(c, empresa,
                ["REPORTE DE CARGA", $"{(despacho.Rutas.Count > 1 ? "RUTAS" : "CAMIÓN")} {despacho.Ruta}", $"#: {despacho.Numero}"]));

            if (despacho.Estado == "ANULADO")
                col.Item().PaddingTop(6).Element(c => Comprobante.Anulado(c, "DESPACHO ANULADO — SIN VALIDEZ"));

            col.Item().PaddingTop(8).Element(c => Comprobante.Datos(c,
                [
                    new DatoImprimible("REPARTO", despacho.Fecha.ToString("dd/MM/yyyy")),
                    new DatoImprimible("VEHÍCULO", despacho.Vehiculo),
                    new DatoImprimible("CONDUCTOR", despacho.Conductor),
                ],
                columnas: 3,
                nota: filtros is null ? null : $"FILTRADO: {filtros}"));
        });

    private void Contenido(IContainer container)
    {
        if (lineas.Count == 0)
        {
            container.Border(Linea).BorderColor(Colores.Linea).Padding(20).AlignCenter()
                .Text("No hay productos con esos filtros.");
            return;
        }

        if (!porMercado)
        {
            container.Element(c => Tabla(c, lineas, aumentos));
            return;
        }

        // Un bloque por mercado, en el orden de la ruta.
        var mercados = lineas
            .GroupBy(l => (l.MercadoId, l.Mercado))
            .OrderBy(g => int.TryParse(g.Key.Mercado, out _) ? 0 : 1)
            .ThenBy(g => int.TryParse(g.Key.Mercado, out var n) ? n : int.MaxValue)
            .ThenBy(g => g.Key.Mercado);

        container.Column(col =>
        {
            var primero = true;
            foreach (var mercado in mercados)
            {
                col.Item().PaddingTop(primero ? 0 : 10).PaddingBottom(3)
                    .Text($"MERCADO {mercado.Key.Mercado}").FontSize(10);
                col.Item().Element(c => Tabla(c, mercado.ToList(), aumentos));
                primero = false;
            }
        });
    }

    /// <summary>Una tabla: sumada por producto y presentación, sin importar el mercado.</summary>
    private static void Tabla(IContainer container, IReadOnlyList<LineaCargaResponse> filas, bool aumentos)
    {
        var sumadas = filas
            .GroupBy(l => (l.ProductoId, l.PresentacionId))
            .Select(g =>
            {
                var l = g.First();
                return (l.Codigo, l.Producto, l.Presentacion, l.Factor, l.UnidadBase,
                    Cantidad: g.Sum(x => x.Cantidad), EnBase: g.Sum(x => x.EnUnidadBase));
            })
            // Por producto, y dentro de cada uno de la presentación más grande a
            // la más chica: el saco primero, luego las bolsas, al final el suelto.
            .OrderBy(l => l.Producto, StringComparer.OrdinalIgnoreCase)
            .ThenByDescending(l => l.Factor)
            .ToList();

        container.Border(Linea).BorderColor(Colores.BordeTabla).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(28);  // ítem
                c.ConstantColumn(56);  // código
                c.RelativeColumn();    // producto
                c.ConstantColumn(90);  // presentación
                c.ConstantColumn(56);  // cantidad
                c.ConstantColumn(70);  // equivale
            });

            // Se repite en cada hoja.
            tabla.Header(h =>
            {
                Encabezado(h.Cell(), "ITEM", primera: true);
                Encabezado(h.Cell(), "CÓDIGO");
                Encabezado(h.Cell(), "PRODUCTO");
                Encabezado(h.Cell(), "PRESENTACIÓN");
                Encabezado(h.Cell(), "CANTIDAD");
                Encabezado(h.Cell(), "EQUIVALE");
            });

            var item = 0;
            foreach (var producto in sumadas.GroupBy(l => (l.Codigo, l.Producto, l.UnidadBase)))
            {
                foreach (var l in producto)
                {
                    item++;
                    Celda(tabla.Cell(), item.ToString(Peru), centro: true, primera: true);
                    Celda(tabla.Cell(), l.Codigo);
                    Celda(tabla.Cell(), l.Producto);
                    Celda(tabla.Cell(), l.Presentacion);
                    Celda(tabla.Cell(), Cifra(l.Cantidad, aumentos), derecha: true, fuerte: true);
                    Celda(tabla.Cell(), $"{Cifra(l.EnBase, aumentos)} {l.UnidadBase}", derecha: true);
                }
            }
        });
    }

    /// <summary>
    /// Una cantidad. En un corte de aumentos lleva su signo —"+4", "−2"—: lo que
    /// sube es lo que hay que agregar al camión, y lo que baja, lo que hay que
    /// sacar. Sin el signo, una baja se leería como algo más por cargar.
    /// </summary>
    private static string Cifra(decimal valor, bool aumentos) =>
        aumentos && valor > 0 ? "+" + Textos.Cantidad(valor) : Textos.Cantidad(valor);

    // Cada casilla lleva su vertical a la izquierda, menos la primera: el
    // borde de la tabla ya la pone. Sin líneas entre filas, como el resto.
    private static IContainer Vertical(IContainer celda, bool primera) =>
        primera ? celda : celda.BorderLeft(Linea).BorderColor(Colores.BordeTabla);

    private static void Encabezado(IContainer celda, string texto, bool primera = false) =>
        Comprobante.Encabezado(Vertical(celda, primera)).Text(texto);

    private static void Celda(
        IContainer celda, string texto, bool derecha = false, bool fuerte = false,
        bool centro = false, bool primera = false)
    {
        var c = Vertical(celda, primera).PaddingVertical(2.5f).PaddingHorizontal(4);
        c = derecha ? c.AlignRight() : centro ? c.AlignCenter() : c.AlignLeft();
        var t = c.Text(texto);
        if (fuerte) t.FontSize(9);
    }
}
