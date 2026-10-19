using QuestPDF.Elements.Table;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// Lo común de los reportes de listado de RR. HH.: la hoja, el pie con la página y las casillas de
/// la tabla.
///
/// La tabla va como la de las novedades: el marco, una vertical entre columnas y una línea fina
/// entre filas, sin rejilla cerrada. Así los cuatro reportes se leen como de la misma familia y un
/// cambio de estilo se hace una sola vez.
/// </summary>
public static class ReporteA4
{
    private const float Linea = Comprobante.Linea;

    /// <summary>El tamaño, el margen, la letra y el pie con "Página 1 de 3".</summary>
    public static void Hoja(PageDescriptor page, bool apaisada, string nombre, DateTime emitido)
    {
        page.Size(apaisada ? PageSizes.A4.Landscape() : PageSizes.A4);
        page.Margin(1.2f, Unit.Centimetre);
        page.DefaultTextStyle(x => Comprobante.Estilo(x, 8));
        page.Footer().AlignCenter().Text(t =>
        {
            t.DefaultTextStyle(x => x.FontSize(7.5f));
            t.Span($"{nombre} · emitido {emitido:dd/MM/yyyy HH:mm} · Página ");
            t.CurrentPageNumber();
            t.Span(" de ");
            t.TotalPages();
        });
    }

    /// <summary>El marco de la tabla.</summary>
    public static IContainer Marco(IContainer container) =>
        container.Border(Linea).BorderColor(Colores.BordeTabla);

    // Cada casilla lleva su vertical a la izquierda, menos la primera: el marco ya la pone.
    private static IContainer Vertical(IContainer celda, bool primera) =>
        primera ? celda : celda.BorderLeft(Linea).BorderColor(Colores.BordeTabla);

    public static void Encabezado(IContainer celda, string texto, bool primera = false, string? fondo = null)
    {
        var c = Vertical(celda, primera);
        if (fondo is not null) c = c.Background(fondo);
        Comprobante.Encabezado(c).Text(texto);
    }

    /// <summary>Una casilla con su dato y, debajo, una línea de apoyo más chica.</summary>
    public static void Celda(
        IContainer celda, string texto, string? apoyo = null,
        bool derecha = false, bool centro = false, bool fuerte = false, bool primera = false,
        string? fondo = null, float tamaño = 8)
    {
        var c = Vertical(celda, primera).BorderBottom(0.5f).BorderColor(Colores.BordeTabla);
        if (fondo is not null) c = c.Background(fondo);
        c = c.PaddingVertical(2.5f).PaddingHorizontal(centro ? 1 : 4);
        var alineada = derecha ? c.AlignRight() : centro ? c.AlignCenter() : c.AlignLeft();

        alineada.Column(col =>
        {
            col.Item().Text(texto).FontSize(fuerte ? tamaño + 1 : tamaño);
            if (!string.IsNullOrWhiteSpace(apoyo))
                col.Item().Text(apoyo).FontSize(6.5f);
        });
    }

    /// <summary>La casilla de un total: con la línea de arriba que la separa de las filas.</summary>
    public static void Total(ITableCellContainer celda, string texto, bool primera = false, uint columnas = 1, bool derecha = true)
    {
        var c = celda.ColumnSpan(columnas).BorderTop(Linea).BorderColor(Colores.BordeTabla);
        if (!primera) c = c.BorderLeft(Linea).BorderColor(Colores.BordeTabla);
        c = c.PaddingVertical(4).PaddingHorizontal(4);
        (derecha ? c.AlignRight() : c.AlignLeft()).Text(texto);
    }

    /// <summary>El título de un bloque dentro del reporte: "ACTIVOS (3)", "OBSERVACIONES".</summary>
    public static void Titulo(IContainer container, string texto) =>
        container.PaddingTop(10).PaddingBottom(3).Text(texto).FontSize(9);

    /// <summary>El recuadro de un reporte sin filas, para que no salga una hoja en blanco.</summary>
    public static void Vacio(IContainer container, string texto) =>
        container.Border(Linea).BorderColor(Colores.Linea).Padding(20).AlignCenter().Text(texto);

    /// <summary>Una firma: el espacio para firmar, la línea y quién firma.</summary>
    public static void Firma(IContainer container, string titulo, string? nombre = null) =>
        container.Column(col =>
        {
            col.Item().Height(34);
            col.Item().LineHorizontal(0.75f);
            col.Item().PaddingTop(2).AlignCenter().Text(titulo).FontSize(7);
            if (nombre is not null) col.Item().AlignCenter().Text(nombre).FontSize(7);
        });

    /// <summary>Un importe en su columna, o una raya si es cero: los ceros no se leen, se cuentan.</summary>
    public static string MontoORaya(decimal valor) => valor == 0 ? "—" : Textos.Numero(valor);
}
