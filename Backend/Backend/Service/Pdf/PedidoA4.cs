using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// Un pedido en una hoja A4 vertical.
///
/// Dibuja EXACTAMENTE lo mismo que cada mitad de la hoja de dos copias — la
/// misma clase lo pinta — solo que a lo ancho de la hoja entera y con la letra
/// algo mayor. Así el papel es reconocible como el mismo documento, salga en
/// un formato o en el otro.
/// </summary>
public sealed class PedidoA4(DocumentoImprimible doc) : IDocument
{
    /// <summary>
    /// Alto mínimo de la tabla, en milímetros.
    ///
    /// Es lo que queda de la hoja vertical tras la cabecera, la rejilla de
    /// datos y el pie. Medido, no estimado: subirlo más manda los totales a
    /// una segunda página.
    /// </summary>
    private const float TablaMm = 200;

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(10, Unit.Millimetre);
            page.DefaultTextStyle(x => x.SemiBold().FontColor(Colores.Texto));

            page.Content().Element(c => HojaPedido.Dibujar(c, doc, TablaMm, escala: 1.3f, copia: false));
        });
}
