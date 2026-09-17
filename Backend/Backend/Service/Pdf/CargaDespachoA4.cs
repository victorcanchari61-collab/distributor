using System.Globalization;
using Backend.Dtos.Responses;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>Un producto en una presentación, sumado de todos los pedidos del camión.</summary>
public sealed record LineaCarga(
    string Codigo,
    string Producto,
    string Presentacion,
    decimal Factor,
    string UnidadBase,
    decimal Cantidad,
    decimal EnUnidadBase,
    int Pedidos);

/// <summary>
/// Reporte de carga: qué productos hay que subir al camión.
///
/// Suma todos los pedidos del despacho por producto y presentación, sin separar
/// por cliente: al cargar no importa de quién es cada bolsa, sino cuántas hay
/// que subir de cada cosa. Al lado va lo mismo en la unidad base —kilos—, que
/// es lo que se pesa y lo que dice cuántos sacos hay que abrir.
///
/// Sale de los pedidos como están AHORA: un aumento o un pedido anulado a
/// última hora ya se ve al volver a sacarlo.
/// </summary>
public sealed class CargaDespachoA4(DespachoResponse despacho, IReadOnlyList<LineaCarga> lineas) : IDocument
{
    private const float Linea = 0.75f;

    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(1.2f, Unit.Centimetre);
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
            col.Item().Text($"Reporte de Carga - CAMIÓN {despacho.Ruta}")
                .FontSize(14).Bold().FontColor(Colores.Fuerte);

            col.Item().Text($"REPARTO {despacho.Fecha:dd/MM/yyyy}").FontSize(10).Bold();

            col.Item().PaddingTop(4).Text(t =>
            {
                t.DefaultTextStyle(x => x.FontSize(8));
                t.Span($"Despacho {despacho.Numero}");
                t.Span($"   ·   Vehículo {despacho.Vehiculo}");
                t.Span($"   ·   Conductor {despacho.Conductor}");
                t.Span($"   ·   {despacho.Pedidos} pedidos");
            });

            if (despacho.Estado == "ANULADO")
                col.Item().PaddingTop(6).Background(Colores.AnuladoFondo)
                    .Border(1).BorderColor(Colores.Anulado).Padding(4)
                    .AlignCenter().Text("DESPACHO ANULADO — SIN VALIDEZ")
                    .Bold().FontColor(Colores.Anulado);
        });

    private void Tabla(IContainer container) =>
        container.Border(Linea).BorderColor(Colores.Linea).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(28);  // ítem
                c.ConstantColumn(56);  // código
                c.RelativeColumn();    // producto
                c.ConstantColumn(90);  // presentación
                c.ConstantColumn(56);  // cantidad
                c.ConstantColumn(70);  // en unidad base
            });

            tabla.Header(h =>
            {
                Encabezado(h.Cell(), "ITEM", derecha: true);
                Encabezado(h.Cell(), "CÓDIGO");
                Encabezado(h.Cell(), "PRODUCTO");
                Encabezado(h.Cell(), "PRESENTACIÓN");
                Encabezado(h.Cell(), "CANTIDAD", derecha: true);
                Encabezado(h.Cell(), "EQUIVALE", derecha: true);
            });

            var item = 0;
            // Por producto: todas las presentaciones de uno juntas, y bajo ellas
            // su total en la unidad base, que es lo que se pesa.
            foreach (var producto in lineas.GroupBy(l => (l.Codigo, l.Producto, l.UnidadBase)))
            {
                foreach (var l in producto)
                {
                    item++;
                    Celda(tabla.Cell(), item.ToString(Peru), derecha: true);
                    Celda(tabla.Cell(), l.Codigo);
                    Celda(tabla.Cell(), l.Producto);
                    Celda(tabla.Cell(), l.Presentacion);
                    Celda(tabla.Cell(), Textos.Cantidad(l.Cantidad), derecha: true, fuerte: true);
                    Celda(tabla.Cell(), $"{Textos.Cantidad(l.EnUnidadBase)} {l.UnidadBase}", derecha: true);
                }

                // El total del producto solo cuando va en más de una presentación:
                // con una sola, repetiría la fila de arriba.
                if (producto.Count() > 1)
                {
                    tabla.Cell().ColumnSpan(5).PaddingVertical(2).PaddingHorizontal(4).AlignRight()
                        .Text($"Total {producto.Key.Producto}").FontSize(8).Bold();
                    tabla.Cell().BorderTop(Linea).BorderColor(Colores.Linea)
                        .PaddingVertical(2).PaddingHorizontal(4).AlignRight()
                        .Text($"{Textos.Cantidad(producto.Sum(l => l.EnUnidadBase))} {producto.Key.UnidadBase}")
                        .FontSize(8).Bold();
                }
            }
        });

    private static void Encabezado(IContainer celda, string texto, bool derecha = false)
    {
        var c = celda.BorderBottom(Linea).BorderColor(Colores.Linea).PaddingVertical(4).PaddingHorizontal(4);
        (derecha ? c.AlignRight() : c.AlignLeft()).Text(texto).Bold().FontSize(8);
    }

    private static void Celda(IContainer celda, string texto, bool derecha = false, bool fuerte = false)
    {
        var c = celda.PaddingVertical(2.5f).PaddingHorizontal(4);
        var t = (derecha ? c.AlignRight() : c.AlignLeft()).Text(texto);
        if (fuerte) t.Bold().FontSize(9.5f);
    }
}
