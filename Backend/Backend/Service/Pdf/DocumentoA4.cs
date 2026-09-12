using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// El documento en hoja completa, para impresora de oficina y para archivar.
///
/// Va todo enmarcado — cabecera, rejilla de datos, tabla y totales — porque
/// es como se lee un comprobante: cada dato en su casilla y no en una lista
/// suelta, de modo que quien lo revisa encuentra el RUC o la forma de pago
/// siempre en el mismo sitio sin tener que leer el papel entero.
///
/// La tabla repite su cabecera en cada hoja: en una venta de cuarenta líneas,
/// una segunda hoja sin encabezados es una lista de números sin significado.
/// </summary>
public sealed class DocumentoA4(DocumentoImprimible doc) : IDocument
{
    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(1.2f, Unit.Centimetre);
            // Semibold de base, no normal: la letra fina de 8 pt se pierde al
            // fotocopiar el documento o al mandarlo por foto, que es como
            // circula de verdad.
            page.DefaultTextStyle(x => x.FontSize(9).SemiBold().FontColor(Colores.Texto));

            page.Header().Element(Cabecera);
            page.Content().PaddingVertical(8).Element(Contenido);
            page.Footer().Element(Pie);
        });

    // --- Cabecera: emisor a la izquierda, documento en su recuadro ---

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Row(row =>
            {
                row.RelativeItem().PaddingRight(10).Column(emisor =>
                {
                    emisor.Item().AlignCenter().Text(doc.Empresa.RazonSocial)
                        .FontSize(13).Bold().FontColor(Colores.Fuerte);

                    var direccion = Textos.Juntar(" — ", doc.Empresa.Direccion, Textos.Zona(doc.Empresa));
                    if (direccion is not null)
                        emisor.Item().AlignCenter().Text(direccion).FontSize(8);

                    if (!string.IsNullOrWhiteSpace(doc.Empresa.Telefono))
                        emisor.Item().AlignCenter().Text($"Cel.: {doc.Empresa.Telefono}").FontSize(8);

                    if (!string.IsNullOrWhiteSpace(doc.Empresa.Email))
                        emisor.Item().AlignCenter().Text(doc.Empresa.Email.ToUpperInvariant())
                            .FontSize(8).FontColor(Colores.Suave);
                });

                // El recuadro del documento: lo primero que se busca al tenerlo
                // en la mano, y por eso va aparte y con borde propio.
                row.ConstantItem(190).Border(1).BorderColor(Colores.Linea).Column(caja =>
                {
                    caja.Item().Padding(4).AlignCenter()
                        .Text($"R.U.C. {doc.Empresa.Ruc}").FontSize(9).SemiBold();

                    caja.Item().BorderTop(1).BorderColor(Colores.Linea)
                        .Padding(4).AlignCenter()
                        .Text(doc.Titulo).FontSize(9.5f).Bold().FontColor(Colores.Fuerte);

                    caja.Item().BorderTop(1).BorderColor(Colores.Linea).Padding(4)
                        .AlignCenter().Text(doc.Numero).FontSize(12).Bold();
                });
            });

            if (doc.Anulado)
                col.Item().PaddingTop(6).Background(Colores.AnuladoFondo)
                    .Border(1).BorderColor(Colores.Anulado).Padding(4)
                    .AlignCenter().Text("DOCUMENTO ANULADO — SIN VALIDEZ")
                    .Bold().FontColor(Colores.Anulado);

            col.Item().PaddingTop(8).Element(Datos);
        });

    /// <summary>
    /// La rejilla de datos: a quién va y en qué condiciones.
    ///
    /// En dos columnas y no en una lista porque son ocho datos cortos; puestos
    /// en fila ocuparían media hoja y obligarían a recorrerla para encontrar
    /// uno.
    /// </summary>
    private void Datos(IContainer container)
    {
        var izquierda = new List<DatoImprimible>
        {
            new(doc.EtiquetaParte.ToUpperInvariant(), doc.ParteNombre),
            new("RUC/DNI", doc.ParteDocumento ?? "—"),
        };
        if (!string.IsNullOrWhiteSpace(doc.ParteDireccion))
            izquierda.Add(new DatoImprimible("DIRECCIÓN", doc.ParteDireccion));
        if (!string.IsNullOrWhiteSpace(doc.ParteTelefono))
            izquierda.Add(new DatoImprimible("TELÉFONO", doc.ParteTelefono));

        var derecha = new List<DatoImprimible>
        {
            new("F. EMISIÓN", doc.Fecha.ToString("dd/MM/yyyy")),
            new("HORA", doc.Fecha.ToString("HH:mm")),
        };
        // Lo propio de cada documento — almacén, forma de pago, orden — se
        // reparte a la derecha, que es la columna donde sobra sitio. Las
        // etiquetas se igualan en mayúsculas: mezcladas con las de arriba, la
        // rejilla parece dos tablas pegadas en vez de una.
        derecha.AddRange(doc.Datos.Select(d => d with { Etiqueta = d.Etiqueta.ToUpperInvariant() }));
        if (doc.Usuario is { Length: > 0 } usuario)
            derecha.Insert(0, new DatoImprimible("VENDEDOR", usuario));

        container.Border(1).BorderColor(Colores.Linea).Padding(6).Row(row =>
        {
            row.RelativeItem().Element(c => Columna(c, izquierda));
            row.ConstantItem(14);
            row.RelativeItem().Element(c => Columna(c, derecha));
        });
    }

    private static void Columna(IContainer container, IReadOnlyList<DatoImprimible> datos) =>
        container.Column(col =>
        {
            foreach (var dato in datos)
                col.Item().PaddingVertical(1).Row(fila =>
                {
                    fila.ConstantItem(80).Text(dato.Etiqueta)
                        .FontSize(8).Bold().FontColor(Colores.Fuerte);
                    fila.ConstantItem(8).Text(":").FontColor(Colores.Suave);
                    fila.RelativeItem().Text(dato.Valor).FontSize(8);
                });
        });

    // --- Cuerpo: las líneas, lo que suman y con qué se pagó ---

    private void Contenido(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Element(Tabla);
            col.Item().PaddingTop(6).Element(EnLetras);
            col.Item().PaddingTop(6).Element(Cierre);
        });

    private void Tabla(IContainer container) =>
        container.Border(1).BorderColor(Colores.Linea).Table(tabla =>
        {
            // La descripción va antes que la cantidad: primero qué es y luego
            // cuánto, que es el orden en que se lee una línea en voz alta al
            // despachar. Además es la única columna que crece, y puesta entre
            // números los partiría en dos bloques.
            tabla.ColumnsDefinition(cols =>
            {
                cols.ConstantColumn(28);   // ítem
                if (doc.MostrarCodigo) cols.ConstantColumn(62);
                cols.RelativeColumn();     // descripción
                cols.ConstantColumn(48);   // cantidad
                cols.ConstantColumn(64);   // unidad
                cols.ConstantColumn(56);   // precio unitario
                cols.ConstantColumn(68);   // subtotal
            });

            tabla.Header(cab =>
            {
                cab.Cell().Element(Encabezado).Text("ÍTEM");
                if (doc.MostrarCodigo) cab.Cell().Element(Encabezado).Text("CÓDIGO");
                cab.Cell().Element(Encabezado).Text("DESCRIPCIÓN");
                cab.Cell().Element(Encabezado).AlignRight().Text("CANT.");
                cab.Cell().Element(Encabezado).Text("UNIDAD");
                cab.Cell().Element(Encabezado).AlignRight().Text("P. UNI.");
                cab.Cell().Element(Encabezado).AlignRight().Text("SUB TOTAL");
            });

            var numero = 0;
            foreach (var linea in doc.Lineas)
            {
                numero++;
                tabla.Cell().Element(Celda).Text($"{numero}").FontColor(Colores.Suave);
                if (doc.MostrarCodigo) tabla.Cell().Element(Celda).Text(linea.Codigo);
                tabla.Cell().Element(Celda).Text(linea.Producto);
                tabla.Cell().Element(Celda).AlignRight().Text(Textos.Cantidad(linea.Cantidad));
                // La presentación manda sobre la unidad base: si se vendió por
                // cajas, "3 UND" diría otra cosa que lo que salió del almacén.
                tabla.Cell().Element(Celda).Text(linea.Presentacion ?? linea.Unidad);
                tabla.Cell().Element(Celda).AlignRight().Text(linea.PrecioUnitario.ToString("N2"));
                tabla.Cell().Element(Celda).AlignRight().Text(linea.Importe.ToString("N2"));
            }
        });

    private static IContainer Encabezado(IContainer container) =>
        container.BorderBottom(1).BorderRight(1).BorderColor(Colores.Linea)
            .PaddingVertical(4).PaddingHorizontal(4)
            .DefaultTextStyle(x => x.Bold().FontSize(8).FontColor(Colores.Fuerte));

    // Rejilla completa, con las verticales: sin ellas, en una linea de dos
    // renglones no se sabe a que columna pertenece cada numero.
    private static IContainer Celda(IContainer container) =>
        container.BorderBottom(1).BorderRight(1).BorderColor(Colores.LineaSuave)
            .PaddingVertical(3).PaddingHorizontal(4);

    private void EnLetras(IContainer container) =>
        container.Border(1).BorderColor(Colores.Linea).Padding(5).Text(txt =>
        {
            txt.Span("SON: ").FontSize(8).SemiBold().FontColor(Colores.Fuerte);
            txt.Span(MontoEnLetras.Soles(doc.Total)).FontSize(8);
        });

    /// <summary>La observación a la izquierda y los totales a su derecha.</summary>
    private void Cierre(IContainer container) =>
        container.Row(row =>
        {
            row.RelativeItem().Border(1).BorderColor(Colores.Linea).Padding(5).Column(col =>
            {
                col.Item().Text("OBSERVACIONES").FontSize(7).SemiBold().FontColor(Colores.Suave);
                col.Item().PaddingTop(2).Text(doc.Observacion ?? "—").FontSize(8);
            });

            row.ConstantItem(10);
            row.ConstantItem(230).Element(Totales);
        });

    private void Totales(IContainer container) =>
        container.Border(1).BorderColor(Colores.Linea).Column(col =>
        {
            col.Item().Element(c => FilaTotal(c, "SUBTOTAL", doc.Total));
            col.Item().Element(c => FilaTotal(c, "TOTAL", doc.Total, destacado: true));

            if (doc.Pagos.Count == 0) return;

            // Los pagos van dentro de la misma caja, debajo del total: son la
            // continuación de esa cuenta, no un bloque aparte.
            foreach (var pago in doc.Pagos)
                col.Item().Element(c => FilaTotal(c, pago.Metodo, pago.Monto, tenue: true));

            col.Item().Element(c => FilaTotal(c, "PAGADO", doc.TotalPagado));

            // El saldo solo se pinta cuando existe: un "SALDO S/ 0.00" en una
            // venta al contado hace dudar de si falta algo.
            if (doc.Saldo > 0)
                col.Item().Element(c => FilaTotal(c, "SALDO PENDIENTE", doc.Saldo, destacado: true));
        });

    private static void FilaTotal(
        IContainer container,
        string rotulo,
        decimal monto,
        bool destacado = false,
        bool tenue = false)
    {
        // Sin fondos: en el papel un gris de relleno se ensucia al fotocopiar y
        // compite con la propia cifra. Lo que destaca el total es el cuerpo de
        // la letra, no un recuadro detras.
        container.BorderBottom(1).BorderColor(Colores.LineaSuave).PaddingVertical(3).PaddingHorizontal(6).Row(row =>
        {
            var rotuloTexto = row.RelativeItem().Text(rotulo)
                .FontSize(destacado ? 9 : 8)
                .FontColor(tenue ? Colores.Suave : Colores.Fuerte);

            var montoTexto = row.ConstantItem(90).AlignRight().Text(Textos.Monto(monto))
                .FontSize(destacado ? 10 : 8)
                .FontColor(tenue ? Colores.Suave : Colores.Fuerte);

            if (!destacado) return;
            rotuloTexto.Bold();
            montoTexto.Bold();
        });
    }

    private void Pie(IContainer container) =>
        container.PaddingTop(4).Column(col =>
        {
            if (!string.IsNullOrWhiteSpace(doc.Aviso))
                col.Item().PaddingBottom(2).Text(doc.Aviso).FontSize(6.5f).FontColor(Colores.Suave);

            col.Item().Row(row =>
            {
                row.RelativeItem().Text($"Emitido el {DateTime.Now:dd/MM/yyyy HH:mm}")
                    .FontSize(6.5f).FontColor(Colores.Suave);

                row.ConstantItem(110).AlignRight().Text(txt =>
                {
                    txt.DefaultTextStyle(x => x.FontSize(6.5f).FontColor(Colores.Suave));
                    txt.Span("Página ");
                    txt.CurrentPageNumber();
                    txt.Span(" de ");
                    txt.TotalPages();
                });
            });
        });
}
