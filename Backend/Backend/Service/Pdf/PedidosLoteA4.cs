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
    private const float TablaMm = 134;

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
    private static void Media(IContainer container, DocumentoImprimible doc, bool copia)
    {
        container.Column(col =>
        {
            // La palabra COPIA arriba y fuera del marco, como en el papel de
            // toda la vida: quien recibe los dos tiene que distinguirlos de un
            // vistazo, sin leerlos.
            col.Item().Height(10).Text(copia ? "COPIA" : string.Empty)
                .FontSize(7).Bold().FontColor(Colores.Fuerte);

            col.Item().Element(c => Cabecera(c, doc));
            col.Item().PaddingTop(4).Element(c => Datos(c, doc));

            /*
             * Alto MINIMO, no fijo ni estirado.
             *
             * Minimo, para que un pedido de tres lineas y otro de catorce
             * tengan el marco del mismo alto y el "SON" y la caja del total
             * caigan siempre en el mismo sitio: si no, las dos mitades de la
             * hoja quedan descuadradas y el corte por el medio no sirve.
             *
             * Y minimo y no fijo porque un pedido mas largo tiene que poder
             * seguir en otra hoja en vez de quedarse sin sitio. Estirarlo al
             * total disponible tampoco vale: se come el hueco del pie y manda
             * los totales a la pagina siguiente.
             */
            col.Item().PaddingTop(4).MinHeight(TablaMm, Unit.Millimetre).Element(c => Tabla(c, doc));

            col.Item().PaddingTop(3).Element(c => Cierre(c, doc));
        });
    }

    private static void Cabecera(IContainer container, DocumentoImprimible doc) =>
        container.Row(row =>
        {
            row.RelativeItem().PaddingRight(6).Column(emisor =>
            {
                emisor.Item().Text(doc.Empresa.RazonSocial).FontSize(9).Bold().FontColor(Colores.Fuerte);

                if (!string.IsNullOrWhiteSpace(doc.Empresa.Telefono))
                    emisor.Item().Text($"Central Telefónica: {doc.Empresa.Telefono}").FontSize(6.5f);

                if (!string.IsNullOrWhiteSpace(doc.Empresa.Email))
                    emisor.Item().Text($"Email: {doc.Empresa.Email}").FontSize(6.5f);

                var direccion = Textos.Juntar(" — ", doc.Empresa.Direccion, Textos.Zona(doc.Empresa));
                if (direccion is not null)
                    emisor.Item().Text($"Dirección: {direccion}").FontSize(6.5f);
            });

            row.ConstantItem(150).Border(1).BorderColor(Colores.Linea).Padding(4).Column(caja =>
            {
                caja.Item().Text($"RUC: {doc.Empresa.Ruc}").FontSize(7).SemiBold();
                caja.Item().PaddingTop(3).Text($"{doc.Titulo} #: {doc.Numero}").FontSize(8).Bold();
            });
        });

    private static void Datos(IContainer container, DocumentoImprimible doc) =>
        container.Border(1).BorderColor(Colores.Linea).Padding(4).Row(row =>
        {
            row.RelativeItem().Column(izq =>
            {
                izq.Item().Element(c => Dato(c, doc.EtiquetaParte.ToUpperInvariant(), doc.ParteNombre));
                if (!string.IsNullOrWhiteSpace(doc.ParteDireccion))
                    izq.Item().Element(c => Dato(c, "DIRECCIÓN", doc.ParteDireccion));
                if (!string.IsNullOrWhiteSpace(doc.ParteDocumento))
                    izq.Item().Element(c => Dato(c, "RUC/DNI", doc.ParteDocumento));
                izq.Item().Element(c => Dato(c, "MONEDA", "SOLES"));
            });

            row.ConstantItem(8);

            row.ConstantItem(130).Column(der =>
            {
                if (doc.Usuario is { Length: > 0 } usuario)
                    der.Item().Element(c => Dato(c, doc.EtiquetaUsuario, usuario));

                der.Item().Element(c => Dato(c, "FECHA", doc.Fecha.ToString("dd/MM/yyyy")));

                foreach (var dato in doc.Datos)
                    der.Item().Element(c => Dato(c, dato.Etiqueta.ToUpperInvariant(), dato.Valor));
            });
        });

    private static void Dato(IContainer container, string etiqueta, string? valor) =>
        container.PaddingBottom(1).Text(txt =>
        {
            txt.Span($"{etiqueta}: ").FontSize(6.5f).Bold().FontColor(Colores.Fuerte);
            txt.Span(valor ?? "—").FontSize(6.5f);
        });

    private static void Tabla(IContainer container, DocumentoImprimible doc) =>
        container.Border(1).BorderColor(Colores.Linea).Table(tabla =>
        {
            tabla.ColumnsDefinition(cols =>
            {
                cols.ConstantColumn(24);   // ítem
                cols.ConstantColumn(44);   // cantidad
                cols.RelativeColumn();     // descripción
                cols.ConstantColumn(46);   // precio
                cols.ConstantColumn(50);   // subtotal
            });

            tabla.Header(cab =>
            {
                cab.Cell().Element(Encabezado).AlignCenter().Text("ITEM");
                cab.Cell().Element(Encabezado).AlignCenter().Text("CANTIDAD");
                cab.Cell().Element(Encabezado).AlignCenter().Text("DESCRIPCION");
                cab.Cell().Element(Encabezado).AlignCenter().Text("PRECIO");
                cab.Cell().Element(Encabezado).AlignCenter().Text("SUB TOTAL");
            });

            var numero = 0;
            foreach (var linea in doc.Lineas)
            {
                numero++;
                tabla.Cell().Element(Celda).AlignCenter().Text($"{numero}").FontSize(6.5f);
                tabla.Cell().Element(Celda).AlignCenter()
                    .Text(Textos.Cantidad(linea.Cantidad)).FontSize(6.5f);
                tabla.Cell().Element(Celda).Text(linea.Producto).FontSize(6.5f).Bold();
                tabla.Cell().Element(Celda).AlignRight()
                    .Text(linea.PrecioUnitario.ToString("N2")).FontSize(6.5f);
                tabla.Cell().Element(Celda).AlignRight()
                    .Text(linea.Importe.ToString("N2")).FontSize(6.5f);
            }
        });

    private static IContainer Encabezado(IContainer container) =>
        container.BorderBottom(1).BorderRight(1).BorderColor(Colores.Linea)
            .PaddingVertical(2).PaddingHorizontal(2)
            .DefaultTextStyle(x => x.Bold().FontSize(6.5f).FontColor(Colores.Fuerte));

    private static IContainer Celda(IContainer container) =>
        container.BorderBottom(1).BorderRight(1).BorderColor(Colores.LineaSuave)
            .PaddingVertical(1).PaddingHorizontal(2);

    private static void Cierre(IContainer container, DocumentoImprimible doc) =>
        container.Column(col =>
        {
            col.Item().Border(1).BorderColor(Colores.Linea).Padding(3).Text(txt =>
            {
                txt.Span("SON: ").FontSize(6.5f).Bold().FontColor(Colores.Fuerte);
                txt.Span(MontoEnLetras.Soles(doc.Total)).FontSize(6.5f);
            });

            col.Item().PaddingTop(3).Row(row =>
            {
                row.RelativeItem().Column(obs =>
                {
                    obs.Item().Text("Observaciones:").FontSize(6.5f).Bold().FontColor(Colores.Fuerte);
                    obs.Item().Text(doc.Observacion ?? string.Empty).FontSize(6.5f);
                });

                row.ConstantItem(150).Border(1).BorderColor(Colores.Linea).Padding(3).Row(caja =>
                {
                    caja.RelativeItem().Text("Total a Pagar:").FontSize(7).Bold().FontColor(Colores.Fuerte);
                    caja.ConstantItem(70).AlignRight()
                        .Text(Textos.Monto(doc.Total)).FontSize(7.5f).Bold().FontColor(Colores.Fuerte);
                });
            });
        });
}
