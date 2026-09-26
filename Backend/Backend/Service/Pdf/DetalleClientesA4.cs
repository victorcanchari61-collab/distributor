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
public sealed class DetalleClientesA4(EmpresaResponse empresa, DespachoResponse despacho) : IDocument
{
    private const float Linea = Comprobante.Linea;

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
            page.DefaultTextStyle(x => Comprobante.Estilo(x, 8));

            page.Header().Element(Cabecera);
            // En una columna: puesto directo en el cuerpo de la hoja, el marco
            // se estiraba hasta el pie aunque las filas acabaran antes.
            page.Content().PaddingVertical(8).Column(col => col.Item().Element(Tabla));
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
            col.Item().Element(c => Comprobante.Membrete(c, empresa,
                ["DETALLE POR CLIENTE", $"CAMIÓN {despacho.Ruta}", $"#: {despacho.Numero}"]));

            if (despacho.Estado == "ANULADO")
                col.Item().PaddingTop(6).Element(c => Comprobante.Anulado(c, "DESPACHO ANULADO — SIN VALIDEZ"));

            col.Item().PaddingTop(8).Element(c => Comprobante.Datos(c,
                [
                    new DatoImprimible("PEDIDOS", Rango()),
                    new DatoImprimible("VEHÍCULO", despacho.Vehiculo),
                    new DatoImprimible("CONDUCTOR", despacho.Conductor),
                ],
                columnas: 3));
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
        container.Border(Linea).BorderColor(Colores.BordeTabla).Table(tabla =>
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
                Encabezado(h.Cell(), "ITEM", primera: true);
                Encabezado(h.Cell(), "DOC");
                Encabezado(h.Cell(), "CLIENTE");
                Encabezado(h.Cell(), "MERCADO");
                Encabezado(h.Cell(), "DOC. PEDIDO");
                Encabezado(h.Cell(), "TOTAL");
            });

            var item = 0;
            foreach (var p in _filas)
            {
                item++;
                Celda(tabla.Cell(), item.ToString(Peru), centro: true, primera: true);
                Celda(tabla.Cell(), p.ClienteDocumento ?? "—");
                Celda(tabla.Cell(), p.Cliente);
                Celda(tabla.Cell(), p.Mercado ?? "—", centro: true);
                Celda(tabla.Cell(), p.Numero, centro: true);
                Celda(tabla.Cell(), p.Total.ToString("N2", Peru), derecha: true);
            }

            // El total del camión: lo que el repartidor tendría que traer si
            // todo se cobrara al contado. La raya lo separa de la última fila.
            tabla.Cell().ColumnSpan(5).BorderTop(Linea).BorderColor(Colores.BordeTabla)
                .PaddingVertical(4).PaddingHorizontal(4).AlignRight()
                .Text($"{_filas.Count} {(_filas.Count == 1 ? "CLIENTE" : "CLIENTES")}   ·   TOTAL");

            tabla.Cell().BorderTop(Linea).BorderLeft(Linea).BorderColor(Colores.BordeTabla)
                .PaddingVertical(4).PaddingHorizontal(4).AlignRight()
                .Text(_filas.Sum(p => p.Total).ToString("N2", Peru)).FontSize(9);
        });

    // Cada casilla lleva su vertical a la izquierda, menos la primera: el
    // borde de la tabla ya la pone. Sin líneas entre filas, como el resto.
    private static IContainer Vertical(IContainer celda, bool primera) =>
        primera ? celda : celda.BorderLeft(Linea).BorderColor(Colores.BordeTabla);

    private static void Encabezado(IContainer celda, string texto, bool primera = false) =>
        Comprobante.Encabezado(Vertical(celda, primera)).Text(texto);

    private static void Celda(
        IContainer celda, string texto, bool derecha = false, bool centro = false, bool primera = false)
    {
        var c = Vertical(celda, primera).PaddingVertical(2.5f).PaddingHorizontal(4);
        c = derecha ? c.AlignRight() : centro ? c.AlignCenter() : c.AlignLeft();
        c.Text(texto);
    }
}
