using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// El mismo documento en rollo térmico de 80 mm, el de la camioneta.
///
/// No es el A4 estrechado, es otra maqueta. En 72 mm útiles no caben cinco
/// columnas: el nombre del producto se parte en cuatro renglones y la tabla
/// deja de leerse. Aquí cada línea ocupa dos renglones — qué es arriba, la
/// cuenta abajo — que es como están hechos los tickets de toda la vida.
///
/// El alto no se fija: el rollo no tiene páginas, se corta donde termina el
/// documento. Por eso tampoco hay numeración de página ni pie repetido.
/// </summary>
public sealed class DocumentoTicket(DocumentoImprimible doc) : IDocument
{
    /// <summary>Ancho del papel. Los 80 mm son del rollo; el resto es margen.</summary>
    private const float AnchoMm = 80;

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.ContinuousSize(AnchoMm, Unit.Millimetre);
            page.MarginHorizontal(4, Unit.Millimetre);
            page.MarginVertical(5, Unit.Millimetre);

            // Todo en negro puro y sin grises finos: la térmica no tiene medias
            // tintas, un gris claro sale como nada.
            page.DefaultTextStyle(x => x.FontSize(8).FontColor(Colores.Fuerte));

            page.Content().Element(Contenido);
        });

    private void Contenido(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Element(Cabecera);
            col.Item().PaddingTop(4).Element(Separador);
            col.Item().PaddingTop(4).Element(Destinatario);
            col.Item().PaddingTop(4).Element(Separador);
            col.Item().PaddingTop(4).Element(Lineas);
            col.Item().PaddingTop(3).Element(Separador);
            col.Item().PaddingTop(4).Element(Totales);

            if (!string.IsNullOrWhiteSpace(doc.Observacion))
                col.Item().PaddingTop(5).Text(doc.Observacion).FontSize(7);

            col.Item().PaddingTop(6).Element(Pie);
        });

    private static void Separador(IContainer container) =>
        container.LineHorizontal(0.6f).LineColor(Colores.Linea);

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().AlignCenter().Text(doc.Empresa.RazonSocial)
                .FontSize(10).Bold();

            col.Item().AlignCenter().Text($"RUC {doc.Empresa.Ruc}").FontSize(8);

            if (!string.IsNullOrWhiteSpace(doc.Empresa.Direccion))
                col.Item().AlignCenter().Text(doc.Empresa.Direccion).FontSize(7);

            if (!string.IsNullOrWhiteSpace(doc.Empresa.Telefono))
                col.Item().AlignCenter().Text($"Tel. {doc.Empresa.Telefono}").FontSize(7);

            col.Item().PaddingTop(5).AlignCenter().Text(doc.Titulo).FontSize(9).Bold();
            col.Item().AlignCenter().Text(doc.Numero).FontSize(11).Bold();
            col.Item().AlignCenter().Text(doc.Fecha.ToString("dd/MM/yyyy HH:mm")).FontSize(7.5f);

            if (doc.Anulado)
                col.Item().PaddingTop(4).Border(1).BorderColor(Colores.Fuerte).Padding(3)
                    .AlignCenter().Text("ANULADO — SIN VALIDEZ").FontSize(9).Bold();
        });

    private void Destinatario(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Text($"{doc.EtiquetaParte}: {doc.ParteNombre}").SemiBold();

            if (!string.IsNullOrWhiteSpace(doc.ParteDocumento))
                col.Item().Text($"Doc. {doc.ParteDocumento}").FontSize(7.5f);

            if (!string.IsNullOrWhiteSpace(doc.ParteDireccion))
                col.Item().Text(doc.ParteDireccion).FontSize(7.5f);

            foreach (var dato in doc.Datos)
                col.Item().Text($"{dato.Etiqueta}: {dato.Valor}").FontSize(7.5f);
        });

    private void Lineas(IContainer container) =>
        container.Column(col =>
        {
            foreach (var linea in doc.Lineas)
            {
                col.Item().PaddingBottom(3).Column(item =>
                {
                    // Qué es, entero y sin recortar: el nombre puede ocupar dos
                    // renglones, y es preferible a un producto irreconocible.
                    var nombre = string.IsNullOrWhiteSpace(linea.Presentacion)
                        ? linea.Producto
                        : $"{linea.Producto} ({linea.Presentacion})";
                    item.Item().Text(nombre).FontSize(8);

                    // Y cuánto costó, sangrado para que se lea como su cuenta.
                    item.Item().PaddingLeft(6).Row(row =>
                    {
                        row.RelativeItem().Text(
                                $"{Textos.Cantidad(linea.Cantidad)} {linea.Unidad} x {Textos.Monto(linea.PrecioUnitario)}")
                            .FontSize(7.5f);

                        row.ConstantItem(62).AlignRight()
                            .Text(Textos.Monto(linea.Importe)).FontSize(8).SemiBold();
                    });
                });
            }
        });

    private void Totales(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Row(row =>
            {
                row.RelativeItem().Text("TOTAL").FontSize(11).Bold();
                row.ConstantItem(80).AlignRight().Text(Textos.Monto(doc.Total)).FontSize(12).Bold();
            });

            if (doc.Pagos.Count == 0) return;

            foreach (var pago in doc.Pagos)
                col.Item().PaddingTop(2).Row(row =>
                {
                    row.RelativeItem().Text(pago.Metodo).FontSize(7.5f);
                    row.ConstantItem(70).AlignRight().Text(Textos.Monto(pago.Monto)).FontSize(7.5f);
                });

            if (doc.Saldo > 0)
                col.Item().PaddingTop(3).Row(row =>
                {
                    row.RelativeItem().Text("SALDO PENDIENTE").FontSize(9).Bold();
                    row.ConstantItem(80).AlignRight().Text(Textos.Monto(doc.Saldo)).FontSize(9).Bold();
                });
        });

    private void Pie(IContainer container) =>
        container.Column(col =>
        {
            // El importe en letras, igual que en la hoja A4: un número se
            // retoca con un trazo, la letra no.
            col.Item().PaddingTop(4).AlignCenter()
                .Text($"SON: {MontoEnLetras.Soles(doc.Total)}").FontSize(6.5f);

            if (!string.IsNullOrWhiteSpace(doc.Aviso))
                col.Item().PaddingTop(5).AlignCenter().Text(doc.Aviso).FontSize(6.5f);

            if (doc.Usuario is { Length: > 0 } usuario)
                col.Item().PaddingTop(3).AlignCenter().Text($"Atendido por {usuario}").FontSize(6.5f);
        });
}
