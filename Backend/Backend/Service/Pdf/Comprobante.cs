using Backend.Dtos.Responses;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// El diseño de todos los papeles A4, dibujado en un solo sitio.
///
/// Sigue el formato del sistema anterior, que es el que ya conocen quienes lo
/// entregan y lo reciben: el logo arriba a la izquierda con los datos de
/// contacto debajo, un recuadro grueso a la derecha con lo que identifica el
/// papel, los datos en una caja, la tabla con sus verticales y, en los
/// comprobantes, el importe en letras, las observaciones y el total. Todo en
/// negro, en negrita y con letra de serifa (<see cref="Letra"/>).
///
/// Existe para que la nota de venta, el pedido de dos copias y los reportes
/// del despacho sean EL MISMO diseño y no varios parecidos: con una maqueta por
/// papel, cualquier arreglo en una dejaba las otras distintas.
///
/// La escala multiplica los tamaños: la hoja completa va a 1 y la media hoja
/// del pedido de dos copias algo menos, porque tiene menos ancho para lo mismo.
/// </summary>
public static class Comprobante
{
    /// <summary>El borde fino de las cajas, la tabla y los totales.</summary>
    public const float Linea = 0.75f;

    /// <summary>La letra de base de un papel A4: serifa, negrita y negro.</summary>
    public static TextStyle Estilo(TextStyle estilo, float tamaño) =>
        estilo.FontFamily(Letra.Serif).FontSize(tamaño).Bold().FontColor(Colores.Texto);

    // --- Lo común a todos los papeles ---

    /// <summary>
    /// El logo y el contacto de la empresa a la izquierda, y a la derecha el
    /// recuadro grueso con lo que identifica el papel: RUC, tipo y número en un
    /// comprobante; el reporte y su despacho en un reporte. Es lo primero que
    /// se busca al tenerlo en la mano.
    /// </summary>
    public static void Membrete(
        IContainer container, EmpresaResponse empresa, IReadOnlyList<string> recuadro, float e = 1f) =>
        container.Row(row =>
        {
            row.RelativeItem().PaddingRight(10 * e).Column(emisor =>
            {
                emisor.Item().Height(62 * e).AlignLeft().Image(Marca.Logo).FitHeight();

                emisor.Item().PaddingTop(4 * e).Column(contacto =>
                {
                    if (!string.IsNullOrWhiteSpace(empresa.Telefono))
                        contacto.Item().Text($"Central Telefónica: {empresa.Telefono}").FontSize(9 * e);

                    var correo = Textos.Juntar(" | ",
                        string.IsNullOrWhiteSpace(empresa.Email) ? null : $"Email: {empresa.Email.ToLowerInvariant()}",
                        string.IsNullOrWhiteSpace(empresa.SitioWeb) ? null : $"Web: {Textos.Web(empresa.SitioWeb)}");
                    if (correo is not null)
                        contacto.Item().Text(correo).FontSize(9 * e);

                    var direccion = Textos.Juntar(" — ", empresa.Direccion, Textos.Zona(empresa));
                    if (direccion is not null)
                        contacto.Item().Text(txt =>
                        {
                            txt.Span("Dirección: ").FontSize(9 * e);
                            txt.Span(direccion).FontSize(7.5f * e);
                        });
                });
            });

            row.ConstantItem(185 * e).Height(80 * e)
                .Border(1.5f).BorderColor(Colores.BordeRuc)
                .AlignMiddle().PaddingHorizontal(4 * e).Column(caja =>
                {
                    caja.Spacing(7 * e);
                    foreach (var linea in recuadro)
                        caja.Item().AlignCenter().Text(linea).FontSize(11 * e);
                });
        });

    /// <summary>La franja roja de un papel sin validez: lo único que va en color.</summary>
    public static void Anulado(IContainer container, string texto) =>
        container.Background(Colores.AnuladoFondo)
            .Border(1).BorderColor(Colores.Anulado).Padding(4)
            .AlignCenter().Text(texto).FontColor(Colores.Anulado);

    /// <summary>
    /// Los datos en una caja, en columnas: son datos cortos, y en fila
    /// ocuparían media hoja. La nota, si hay, va debajo a todo el ancho —lo que
    /// se filtró en un reporte—, porque en una columna se partiría en pedazos.
    /// </summary>
    public static void Datos(
        IContainer container, IReadOnlyList<DatoImprimible> datos, int columnas, float e = 1f, string? nota = null) =>
        container.Border(Linea).BorderColor(Colores.Linea).Padding(3 * e).Table(tabla =>
        {
            tabla.ColumnsDefinition(cols =>
            {
                for (var i = 0; i < columnas; i++) cols.RelativeColumn();
            });

            foreach (var dato in datos)
                tabla.Cell().Padding(2 * e).Text(txt =>
                {
                    txt.DefaultTextStyle(x => x.FontSize(7 * e));
                    txt.Span($"{dato.Etiqueta}: ");
                    txt.Span(dato.Valor);
                });

            if (nota is not null)
                tabla.Cell().ColumnSpan((uint)columnas).Padding(2 * e).Text(nota).FontSize(7 * e);
        });

    /// <summary>La casilla de un título de tabla: cerrada abajo, centrada.</summary>
    public static IContainer Encabezado(IContainer container, float e = 1f) =>
        container.BorderBottom(Linea).BorderColor(Colores.BordeTabla)
            .PaddingVertical(3 * e).PaddingHorizontal(2 * e).AlignCenter()
            .DefaultTextStyle(x => x.FontSize(7 * e));

    // --- El comprobante: nota de venta, compra, pedido y los de inventario ---

    /// <summary>El membrete con RUC, tipo y número, y debajo a quién va.</summary>
    public static void Cabecera(IContainer container, DocumentoImprimible doc, float e = 1f) =>
        container.Column(col =>
        {
            col.Item().Element(c => Membrete(c, doc.Empresa, [$"RUC: {doc.Empresa.Ruc}", doc.Titulo, $"#: {doc.Numero}"], e));

            if (doc.Anulado)
                col.Item().PaddingTop(6 * e).Element(c => Anulado(c, "DOCUMENTO ANULADO — SIN VALIDEZ"));

            // Tres columnas en la hoja entera; en la media hoja no caben.
            col.Item().PaddingTop(8 * e).Element(c => Datos(c, DatosDe(doc), e >= 1f ? 3 : 2, e));
        });

    private static List<DatoImprimible> DatosDe(DocumentoImprimible doc)
    {
        var datos = new List<DatoImprimible>();
        // Solo si de verdad hay documento. Un ajuste no tiene RUC de nadie, y
        // un "RUC/DNI: —" en su cabecera hace buscar un dato que no existe.
        if (!string.IsNullOrWhiteSpace(doc.ParteDocumento))
            datos.Add(new DatoImprimible("RUC/DNI", doc.ParteDocumento));
        datos.Add(new DatoImprimible(doc.EtiquetaParte.ToUpperInvariant(), doc.ParteNombre));
        if (!string.IsNullOrWhiteSpace(doc.ParteDireccion))
            datos.Add(new DatoImprimible("DIRECCIÓN", doc.ParteDireccion));
        if (doc.Usuario is { Length: > 0 } usuario)
            datos.Add(new DatoImprimible(doc.EtiquetaUsuario, usuario));
        datos.Add(new DatoImprimible("FECHA", doc.Fecha.ToString("dd/MM/yyyy HH:mm")));
        // La moneda solo cuando hay importes: en una transferencia sin
        // precios no dice nada.
        if (doc.Total > 0)
            datos.Add(new DatoImprimible("MONEDA", "SOLES"));
        // Lo propio de cada documento — condición de pago, almacén, orden.
        datos.AddRange(doc.Datos.Select(d => d with { Etiqueta = d.Etiqueta.ToUpperInvariant() }));
        if (!string.IsNullOrWhiteSpace(doc.ParteTelefono))
            datos.Add(new DatoImprimible("CELULAR", doc.ParteTelefono));
        return datos;
    }

    /// <summary>
    /// El ancho de cada columna, en el orden de la tabla; null es la
    /// descripción, la única que crece. Lo usan la tabla y su marco, así las
    /// verticales caen siempre donde caen las columnas.
    /// </summary>
    private static float?[] Anchos(DocumentoImprimible doc, float e) =>
        (doc.MostrarCodigo
            ? new float?[] { 28, 55, null, 52, 58, 66 }
            : new float?[] { 28, null, 52, 58, 66 })
        .Select(a => a * e).ToArray();

    /*
     * El marco y las verticales, a todo el alto, como las filas en blanco del
     * papel anterior: se estiran hasta el borde de abajo haya tres lineas o
     * treinta. Entre filas no hay lineas; las separa su propio aire.
     */
    private static void Marco(IContainer container, float?[] anchos) =>
        container.Border(Linea).BorderColor(Colores.BordeTabla).ExtendVertical().Row(row =>
        {
            for (var i = 0; i < anchos.Length; i++)
            {
                var celda = anchos[i] is { } ancho ? row.ConstantItem(ancho) : row.RelativeItem();
                // La ultima no lleva: su vertical es el marco.
                if (i < anchos.Length - 1) celda.BorderRight(Linea).BorderColor(Colores.BordeTabla);
            }
        });

    /// <summary>
    /// Las líneas del documento. La cabecera se repite en cada hoja: en una
    /// venta de cuarenta líneas, una segunda hoja sin encabezados es una lista
    /// de números sin significado.
    /// </summary>
    public static void Tabla(IContainer container, DocumentoImprimible doc, float e = 1f)
    {
        var anchos = Anchos(doc, e);

        container.Layers(capas =>
        {
            capas.Layer().Element(c => Marco(c, anchos));
            capas.PrimaryLayer().Table(tabla =>
            {
                tabla.ColumnsDefinition(cols =>
                {
                    foreach (var ancho in anchos)
                        if (ancho is { } fijo) cols.ConstantColumn(fijo);
                        else cols.RelativeColumn();
                });

                tabla.Header(cab =>
                {
                    cab.Cell().Element(c => Encabezado(c, e)).Text("ITEM");
                    if (doc.MostrarCodigo) cab.Cell().Element(c => Encabezado(c, e)).Text("CÓDIGO");
                    cab.Cell().Element(c => Encabezado(c, e)).Text("DESCRIPCIÓN");
                    cab.Cell().Element(c => Encabezado(c, e)).Text("CANTIDAD");
                    cab.Cell().Element(c => Encabezado(c, e)).Text(doc.EtiquetaImporte.ToUpperInvariant());
                    cab.Cell().Element(c => Encabezado(c, e)).Text("SUB TOTAL");
                });

                IContainer Celda(IContainer c) =>
                    c.PaddingVertical(2 * e).PaddingHorizontal(3 * e).DefaultTextStyle(x => x.FontSize(7.5f * e));

                var numero = 0;
                foreach (var linea in doc.Lineas)
                {
                    numero++;
                    tabla.Cell().Element(Celda).AlignCenter().Text($"{numero}");
                    if (doc.MostrarCodigo) tabla.Cell().Element(Celda).AlignCenter().Text(linea.Codigo);
                    // La presentación va entre paréntesis pegada al nombre y no
                    // en su columna: es parte de qué se vendió —"Atún Cama
                    // (Caja x24)"— y aparte obliga a leer dos sitios. Manda
                    // sobre la unidad base: si se vendió por cajas, "UND" dice
                    // otra cosa que lo que se acordó.
                    tabla.Cell().Element(Celda).Text(
                        (linea.Presentacion ?? linea.Unidad) is { Length: > 0 } medida
                            ? $"{linea.Producto} ({medida})"
                            : linea.Producto);
                    tabla.Cell().Element(Celda).AlignCenter().Text(Textos.Cantidad(linea.Cantidad));
                    tabla.Cell().Element(Celda).AlignCenter().Text(Textos.Numero(linea.PrecioUnitario));
                    tabla.Cell().Element(Celda).AlignCenter().Text(Textos.Numero(linea.Importe));
                }
            });
        });
    }

    /// <summary>
    /// El importe en letras, las observaciones y el total.
    ///
    /// Sin los pagos: el papel es el documento de lo vendido o comprado, no el
    /// estado de su cobro, que cambia después de imprimirlo.
    /// </summary>
    public static void Pie(IContainer container, DocumentoImprimible doc, float e = 1f) =>
        container.Column(col =>
        {
            col.Item().PaddingTop(6 * e).Border(Linea).BorderColor(Colores.Linea)
                .PaddingVertical(3 * e).PaddingHorizontal(5 * e)
                .Text($"SON: {MontoEnLetras.Soles(doc.Total)}").FontSize(7.5f * e);

            col.Item().PaddingTop(6 * e).Row(row =>
            {
                row.RelativeItem().PaddingRight(10 * e).Column(obs =>
                {
                    obs.Item().Text("Observaciones:").FontSize(7.5f * e);
                    if (!string.IsNullOrWhiteSpace(doc.Observacion))
                        obs.Item().PaddingTop(2 * e).Text(doc.Observacion).FontSize(7.5f * e);
                });

                row.ConstantItem(185 * e).Border(Linea).BorderColor(Colores.BordeTabla).Column(totales =>
                {
                    // Solo la nota de venta trae el desglose de IGV; los demás
                    // documentos lo dejan en cero y muestran solo el total.
                    if (doc.OpGravada > 0) totales.Item().Element(c => FilaTotal(c, "Op. Gravada:", doc.OpGravada, e));
                    if (doc.Igv > 0) totales.Item().Element(c => FilaTotal(c, "IGV:", doc.Igv, e));
                    if (doc.OpExonerada > 0) totales.Item().Element(c => FilaTotal(c, "Op. Exonerada:", doc.OpExonerada, e));
                    totales.Item().Element(c => FilaTotal(c, "Total a Pagar:", doc.Total, e));
                });
            });
        });

    /// <summary>Una fila de los totales: el rótulo y el monto separados por una vertical.</summary>
    private static void FilaTotal(IContainer container, string rotulo, decimal monto, float e) =>
        container.DefaultTextStyle(x => x.FontSize(9 * e)).Row(row =>
        {
            row.RelativeItem().PaddingVertical(2 * e).PaddingHorizontal(5 * e).AlignRight().Text(rotulo);
            row.ConstantItem(80 * e).BorderLeft(Linea).BorderColor(Colores.BordeTabla)
                .PaddingVertical(2 * e).PaddingHorizontal(5 * e).AlignRight().Text(Textos.Monto(monto));
        });

    /// <summary>
    /// El comprobante entero en un recuadro, para la media hoja del pedido de
    /// dos copias, donde no hay cabecera ni pie de página que lo repartan.
    /// </summary>
    public static void Dibujar(IContainer container, DocumentoImprimible doc, float tablaMm, float e, bool copia) =>
        container.Column(col =>
        {
            // La palabra COPIA arriba y fuera del recuadro: quien recibe los dos
            // papeles tiene que distinguirlos de un vistazo, sin leerlos.
            col.Item().Height(10 * e).Text(copia ? "COPIA" : string.Empty).FontSize(7 * e);

            col.Item().Element(c => Cabecera(c, doc, e));

            /*
             * Alto MINIMO, no fijo ni estirado: el "SON" y el total caen
             * siempre en el mismo sitio en las dos mitades, y un pedido mas
             * largo puede seguir en otra hoja en vez de quedarse sin sitio.
             */
            col.Item().PaddingTop(6 * e).MinHeight(tablaMm, Unit.Millimetre).Element(c => Tabla(c, doc, e));

            col.Item().Element(c => Pie(c, doc, e));
        });
}
