using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// Muchos pedidos en un solo archivo, dos copias por hoja.
///
/// Cada pedido ocupa una hoja A4 apaisada partida en dos mitades iguales: la
/// izquierda es el original y la derecha la copia. Así, de una sola impresión
/// salen los dos papeles que hacen falta — uno se queda el cliente y el otro
/// vuelve firmado — y se corta la hoja por el medio.
///
/// Va en un archivo único y no en uno por pedido porque el caso real es sacar
/// la carga entera de un camión: con veinte archivos, quien imprime tiene que
/// abrirlos de uno en uno.
/// </summary>
public sealed class PedidosLoteA4(IReadOnlyList<DocumentoImprimible> pedidos) : IDocument
{
    /// <summary>
    /// Alto mínimo de la tabla, en milímetros.
    ///
    /// Es lo que queda de la media hoja apaisada después de la cabecera, la
    /// rejilla de datos y el pie. Fijarlo aquí es lo que hace que todas las
    /// copias salgan con la misma geometría.
    /// </summary>
    private const float TablaMm = 140;

    public void Compose(IDocumentContainer container)
    {
        foreach (var pedido in pedidos)
        {
            container.Page(page =>
            {
                // Apaisada: es lo que permite las dos mitades de ancho util.
                page.Size(PageSizes.A4.Landscape());
                page.Margin(8, Unit.Millimetre);
                page.DefaultTextStyle(x => x.FontSize(7.5f).SemiBold().FontColor(Colores.Texto));

                page.Content().Row(row =>
                {
                    row.RelativeItem().Element(c => Media(c, pedido, copia: false));
                    // El canal por donde se corta.
                    row.ConstantItem(12);
                    row.RelativeItem().Element(c => Media(c, pedido, copia: true));
                });
            });
        }
    }

    /// <summary>Una de las dos mitades de la hoja.</summary>
    private static void Media(IContainer container, DocumentoImprimible doc, bool copia) =>
        HojaPedido.Dibujar(container, doc, TablaMm, escala: 1f, copia: copia);
}
