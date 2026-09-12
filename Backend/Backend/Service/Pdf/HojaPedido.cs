using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// El dibujo de un pedido en papel, sea en media hoja o en una entera.
///
/// Existe para que el A4 y la hoja de dos copias sean EL MISMO diseño y no dos
/// parecidos: antes cada formato tenía su propia maqueta, y cualquier arreglo
/// en una dejaba la otra distinta. Aquí se dibuja una sola vez y cada formato
/// solo decide el ancho, el alto de la tabla y el tamaño de letra.
///
/// La escala multiplica los tamaños de texto: la media hoja va a 1 y la hoja
/// completa un poco más grande, porque tiene el doble de ancho para lo mismo.
/// </summary>
public static class HojaPedido
{
    public static void Dibujar(
        IContainer container,
        DocumentoImprimible doc,
        float tablaMm,
        float escala,
        bool copia)
    {
        container.Column(col =>
        {
            // La palabra COPIA arriba y fuera del marco: quien recibe los dos
            // papeles tiene que distinguirlos de un vistazo, sin leerlos.
            col.Item().Height(10 * escala).Text(copia ? "COPIA" : string.Empty)
                .FontSize(7 * escala).Bold().FontColor(Colores.Fuerte);

            col.Item().Element(c => Cabecera(c, doc, escala));
            col.Item().PaddingTop(4).Element(c => Datos(c, doc, escala));

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
            col.Item().PaddingTop(4).MinHeight(tablaMm, Unit.Millimetre)
                .Element(c => Tabla(c, doc, escala));

            col.Item().PaddingTop(3).Element(c => Cierre(c, doc, escala));
        });
    }

    private static void Cabecera(IContainer container, DocumentoImprimible doc, float e) =>
        container.Row(row =>
        {
            row.RelativeItem().PaddingRight(6).Column(emisor =>
            {
                emisor.Item().Text(doc.Empresa.RazonSocial)
                    .FontSize(9 * e).Bold().FontColor(Colores.Fuerte);

                if (!string.IsNullOrWhiteSpace(doc.Empresa.Telefono))
                    emisor.Item().Text($"Central Telefónica: {doc.Empresa.Telefono}").FontSize(6.5f * e);

                if (!string.IsNullOrWhiteSpace(doc.Empresa.Email))
                    emisor.Item().Text($"Email: {doc.Empresa.Email}").FontSize(6.5f * e);

                var direccion = Textos.Juntar(" — ", doc.Empresa.Direccion, Textos.Zona(doc.Empresa));
                if (direccion is not null)
                    emisor.Item().Text($"Dirección: {direccion}").FontSize(6.5f * e);
            });

            row.ConstantItem(150 * e).Border(1).BorderColor(Colores.Linea).Padding(4).Column(caja =>
            {
                caja.Item().Text($"RUC: {doc.Empresa.Ruc}").FontSize(7 * e).SemiBold();
                caja.Item().PaddingTop(3).Text($"{doc.Titulo} #: {doc.Numero}").FontSize(8 * e).Bold();
            });
        });

    private static void Datos(IContainer container, DocumentoImprimible doc, float e) =>
        container.Border(1).BorderColor(Colores.Linea).Padding(4).Row(row =>
        {
            row.RelativeItem().Column(izq =>
            {
                izq.Item().Element(c => Dato(c, doc.EtiquetaParte.ToUpperInvariant(), doc.ParteNombre, e));
                if (!string.IsNullOrWhiteSpace(doc.ParteDireccion))
                    izq.Item().Element(c => Dato(c, "DIRECCIÓN", doc.ParteDireccion, e));
                if (!string.IsNullOrWhiteSpace(doc.ParteDocumento))
                    izq.Item().Element(c => Dato(c, "RUC/DNI", doc.ParteDocumento, e));
                izq.Item().Element(c => Dato(c, "MONEDA", "SOLES", e));
            });

            row.ConstantItem(8);

            row.ConstantItem(130 * e).Column(der =>
            {
                if (doc.Usuario is { Length: > 0 } usuario)
                    der.Item().Element(c => Dato(c, doc.EtiquetaUsuario, usuario, e));

                der.Item().Element(c => Dato(c, "FECHA", doc.Fecha.ToString("dd/MM/yyyy"), e));

                foreach (var dato in doc.Datos)
                    der.Item().Element(c => Dato(c, dato.Etiqueta.ToUpperInvariant(), dato.Valor, e));
            });
        });

    private static void Dato(IContainer container, string etiqueta, string? valor, float e) =>
        container.PaddingBottom(1).Text(txt =>
        {
            txt.Span($"{etiqueta}: ").FontSize(6.5f * e).Bold().FontColor(Colores.Fuerte);
            txt.Span(valor ?? "—").FontSize(6.5f * e);
        });

    private static void Tabla(IContainer container, DocumentoImprimible doc, float e) =>
        container.Border(1).BorderColor(Colores.Linea).Table(tabla =>
        {
            tabla.ColumnsDefinition(cols =>
            {
                cols.ConstantColumn(24 * e);   // ítem
                cols.ConstantColumn(44 * e);   // cantidad
                cols.RelativeColumn();         // descripción
                cols.ConstantColumn(46 * e);   // precio
                cols.ConstantColumn(50 * e);   // subtotal
            });

            tabla.Header(cab =>
            {
                cab.Cell().Element(c => Encabezado(c, e)).AlignCenter().Text("ITEM");
                cab.Cell().Element(c => Encabezado(c, e)).AlignCenter().Text("CANTIDAD");
                cab.Cell().Element(c => Encabezado(c, e)).AlignCenter().Text("DESCRIPCION");
                cab.Cell().Element(c => Encabezado(c, e)).AlignCenter().Text("PRECIO");
                cab.Cell().Element(c => Encabezado(c, e)).AlignCenter().Text("SUB TOTAL");
            });

            var numero = 0;
            foreach (var linea in doc.Lineas)
            {
                numero++;
                tabla.Cell().Element(Celda).AlignCenter().Text($"{numero}").FontSize(6.5f * e);
                tabla.Cell().Element(Celda).AlignCenter()
                    .Text(Textos.Cantidad(linea.Cantidad)).FontSize(6.5f * e);
                tabla.Cell().Element(Celda).Text(linea.Producto).FontSize(6.5f * e).Bold();
                tabla.Cell().Element(Celda).AlignRight()
                    .Text(linea.PrecioUnitario.ToString("N2")).FontSize(6.5f * e);
                tabla.Cell().Element(Celda).AlignRight()
                    .Text(linea.Importe.ToString("N2")).FontSize(6.5f * e);
            }
        });

    private static IContainer Encabezado(IContainer container, float e) =>
        container.BorderBottom(1).BorderRight(1).BorderColor(Colores.Linea)
            .PaddingVertical(2).PaddingHorizontal(2)
            .DefaultTextStyle(x => x.Bold().FontSize(6.5f * e).FontColor(Colores.Fuerte));

    private static IContainer Celda(IContainer container) =>
        container.BorderBottom(1).BorderRight(1).BorderColor(Colores.LineaSuave)
            .PaddingVertical(1).PaddingHorizontal(2);

    private static void Cierre(IContainer container, DocumentoImprimible doc, float e) =>
        container.Column(col =>
        {
            col.Item().Border(1).BorderColor(Colores.Linea).Padding(3).Text(txt =>
            {
                txt.Span("SON: ").FontSize(6.5f * e).Bold().FontColor(Colores.Fuerte);
                txt.Span(MontoEnLetras.Soles(doc.Total)).FontSize(6.5f * e);
            });

            col.Item().PaddingTop(3).Row(row =>
            {
                row.RelativeItem().Column(obs =>
                {
                    obs.Item().Text("Observaciones:").FontSize(6.5f * e).Bold().FontColor(Colores.Fuerte);
                    obs.Item().Text(doc.Observacion ?? string.Empty).FontSize(6.5f * e);
                });

                row.ConstantItem(150 * e).Border(1).BorderColor(Colores.Linea).Padding(3).Row(caja =>
                {
                    caja.RelativeItem().Text("Total a Pagar:")
                        .FontSize(7 * e).Bold().FontColor(Colores.Fuerte);
                    caja.ConstantItem(70 * e).AlignRight()
                        .Text(Textos.Monto(doc.Total)).FontSize(7.5f * e).Bold().FontColor(Colores.Fuerte);
                });
            });
        });
}
