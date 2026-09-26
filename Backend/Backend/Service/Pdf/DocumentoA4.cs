using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// El documento en hoja completa, para impresora de oficina y para archivar:
/// nota de venta, pedido, compra, orden y los de inventario.
///
/// El diseño es el de <see cref="Comprobante"/>, el mismo de la media hoja del
/// pedido de dos copias. Aquí solo se reparte en la hoja: el membrete y los
/// datos como cabecera de página, que se repite si el documento sigue en otra
/// hoja, y la tabla con el total en el cuerpo.
/// </summary>
public sealed class DocumentoA4(DocumentoImprimible doc) : IDocument
{
    /// <summary>
    /// Alto mínimo de la tabla, en milímetros: lo que queda de la hoja tras la
    /// cabecera, los datos y el bloque del total.
    /// </summary>
    private const float TablaMm = 170;

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(1.2f, Unit.Centimetre);
            page.DefaultTextStyle(x => Comprobante.Estilo(x, 9));

            page.Header().Element(c => Comprobante.Cabecera(c, doc));
            page.Content().PaddingVertical(6).Column(col =>
            {
                /*
                 * Alto minimo: el importe en letras y el total caen siempre a
                 * la misma altura, tenga el documento tres lineas o treinta.
                 *
                 * Minimo y no fijo para que un documento largo pueda seguir en
                 * la hoja siguiente en lugar de quedarse sin sitio.
                 */
                col.Item().MinHeight(TablaMm, Unit.Millimetre).Element(c => Comprobante.Tabla(c, doc));

                // El importe en letras y el total van juntos: si no caben al
                // final de la hoja, pasan enteros a la siguiente.
                col.Item().ShowEntire().Element(c => Comprobante.Pie(c, doc));
            });
            page.Footer().Element(Pie);
        });

    private static void Pie(IContainer container) =>
        container.PaddingTop(4).DefaultTextStyle(x => x.FontSize(6.5f)).Row(row =>
        {
            row.RelativeItem().Text($"Emitido el {DateTime.Now:dd/MM/yyyy HH:mm}");

            row.ConstantItem(110).AlignRight().Text(txt =>
            {
                txt.Span("Página ");
                txt.CurrentPageNumber();
                txt.Span(" de ");
                txt.TotalPages();
            });
        });
}
