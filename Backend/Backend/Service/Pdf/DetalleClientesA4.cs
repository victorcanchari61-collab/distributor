using System.Globalization;
using Backend.Dtos.Responses;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// Detalle por cliente de un camión: a quién se le entrega y cuánto se cobra.
///
/// Es la hoja con la que sale el repartidor y con la que la oficina cuadra la
/// cobranza al volver. Una fila por pedido, ordenada por mercado, que es el
/// orden en que el camión recorre la ruta: así se lee de arriba abajo mientras
/// se reparte, sin saltar de un extremo de la ruta al otro.
///
/// Sin rejilla de celdas: solo el marco y la raya bajo la cabecera. Es un papel
/// de uso diario y de muchas hojas, y la tinta de las líneas se nota.
/// </summary>
public sealed class DetalleClientesA4(DespachoResponse despacho) : IDocument
{
    private const float Linea = 0.75f;

    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    /// <summary>
    /// Los pedidos en el orden del reparto.
    ///
    /// El mercado se ordena como número cuando lo es: los mercados de la ruta se
    /// llaman 1, 7, 8, 11, y ordenados como texto el 11 saldría antes que el 7.
    /// </summary>
    private readonly List<DespachoPedidoResponse> _filas = despacho.Detalle
        .OrderBy(p => int.TryParse(p.Mercado, out _) ? 0 : 1)
        .ThenBy(p => int.TryParse(p.Mercado, out var n) ? n : int.MaxValue)
        .ThenBy(p => p.Mercado ?? string.Empty, StringComparer.OrdinalIgnoreCase)
        .ThenBy(p => p.Cliente, StringComparer.OrdinalIgnoreCase)
        .ToList();

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(1.2f, Unit.Centimetre);
            // Semibold de base: la letra fina se pierde al fotocopiar la hoja o
            // al mandarla por foto, que es como circula de verdad.
            page.DefaultTextStyle(x => x.FontSize(8.5f).SemiBold().FontColor(Colores.Texto));

            page.Header().Element(Cabecera);
            page.Content().PaddingVertical(8).Element(Tabla);
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
            // "CAMIÓN 1": la ruta, porque un camión recorre una sola ruta y así
            // es como la llaman en el almacén.
            col.Item().Text($"Detalle por Cliente - CAMIÓN {despacho.Ruta}")
                .FontSize(14).Bold().FontColor(Colores.Fuerte);

            col.Item().Text(Rango()).FontSize(10).Bold();

            col.Item().PaddingTop(4).Text(t =>
            {
                t.DefaultTextStyle(x => x.FontSize(8));
                t.Span($"Despacho {despacho.Numero}");
                t.Span($"   ·   Vehículo {despacho.Vehiculo}");
                t.Span($"   ·   Conductor {despacho.Conductor}");
            });

            if (despacho.Estado == "ANULADO")
                col.Item().PaddingTop(6).Background(Colores.AnuladoFondo)
                    .Border(1).BorderColor(Colores.Anulado).Padding(4)
                    .AlignCenter().Text("DESPACHO ANULADO — SIN VALIDEZ")
                    .Bold().FontColor(Colores.Anulado);
        });

    /// <summary>
    /// Del primer al último pedido del camión.
    ///
    /// No la fecha del despacho: lo que se carga un martes se tomó el lunes y
    /// también el mismo martes, y el rango es lo que dice qué pedidos entraron.
    /// </summary>
    private string Rango()
    {
        if (_filas.Count == 0) return despacho.Fecha.ToString("dd/MM/yyyy");

        var desde = _filas.Min(p => p.Fecha).Date;
        var hasta = _filas.Max(p => p.Fecha).Date;
        return $"DEL {desde:dd/MM/yyyy} AL {hasta:dd/MM/yyyy}";
    }

    private void Tabla(IContainer container) =>
        container.Border(Linea).BorderColor(Colores.Linea).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(28);  // ítem
                c.ConstantColumn(62);  // documento
                c.RelativeColumn();    // cliente
                c.ConstantColumn(52);  // mercado
                c.ConstantColumn(62);  // pedido
                c.ConstantColumn(66);  // total
            });

            // Se repite en cada hoja: una segunda página sin cabecera es una
            // lista de números sin decir cuál es cuál.
            tabla.Header(h =>
            {
                Encabezado(h.Cell(), "ITEM", derecha: true);
                Encabezado(h.Cell(), "DOC");
                Encabezado(h.Cell(), "CLIENTE");
                Encabezado(h.Cell(), "MERCADO", centro: true);
                Encabezado(h.Cell(), "DOC. PEDIDO", centro: true);
                Encabezado(h.Cell(), "TOTAL", derecha: true);
            });

            var item = 0;
            foreach (var p in _filas)
            {
                item++;
                Celda(tabla.Cell(), item.ToString(Peru), derecha: true);
                Celda(tabla.Cell(), p.ClienteDocumento ?? "—");
                Celda(tabla.Cell(), p.Cliente);
                Celda(tabla.Cell(), p.Mercado ?? "—", centro: true);
                Celda(tabla.Cell(), p.Numero, centro: true);
                Celda(tabla.Cell(), p.Total.ToString("N2", Peru), derecha: true);
            }

            // El total del camión: lo que el repartidor tendría que traer si
            // todo se cobrara al contado. La raya lo separa de la última fila.
            tabla.Cell().ColumnSpan(5).BorderTop(Linea).BorderColor(Colores.Linea)
                .PaddingVertical(4).PaddingHorizontal(4).AlignRight()
                .Text($"{_filas.Count} {(_filas.Count == 1 ? "CLIENTE" : "CLIENTES")}   ·   TOTAL")
                .Bold();

            tabla.Cell().BorderTop(Linea).BorderColor(Colores.Linea)
                .PaddingVertical(4).PaddingHorizontal(4).AlignRight()
                .Text(_filas.Sum(p => p.Total).ToString("N2", Peru)).Bold().FontSize(9.5f);
        });

    private static void Encabezado(IContainer celda, string texto, bool derecha = false, bool centro = false)
    {
        var c = celda.BorderBottom(Linea).BorderColor(Colores.Linea)
            .PaddingVertical(4).PaddingHorizontal(4);
        c = derecha ? c.AlignRight() : centro ? c.AlignCenter() : c.AlignLeft();
        c.Text(texto).Bold().FontSize(8);
    }

    private static void Celda(IContainer celda, string texto, bool derecha = false, bool centro = false)
    {
        var c = celda.PaddingVertical(2.5f).PaddingHorizontal(4);
        c = derecha ? c.AlignRight() : centro ? c.AlignCenter() : c.AlignLeft();
        c.Text(texto);
    }
}
