using System.Globalization;
using Backend.Dtos.Responses;
using Backend.Models;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// Reporte de novedades de entrega: lo que no llegó al cliente y por qué.
///
/// Sale con los mismos filtros y el mismo orden que la pantalla, y lo que se
/// filtró va escrito en la cabecera: un papel recortado que no lo dice pasa por
/// el total de todo. Apaisado porque cada fila lleva ocho datos y en vertical
/// se cortaría el motivo, que es justo lo que se viene a leer.
///
/// Sin rejilla de celdas: solo el marco y la raya bajo la cabecera, como el
/// resto de los papeles de reparto.
/// </summary>
public sealed class NovedadesA4(
    IReadOnlyList<NovedadResponse> filas,
    int total,
    string? filtros,
    DateTime emitido) : IDocument
{
    private const float Linea = 0.75f;

    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.Size(PageSizes.A4.Landscape());
            page.Margin(1.2f, Unit.Centimetre);
            // Semibold de base: la letra fina se pierde al fotocopiar la hoja o
            // al mandarla por foto, que es como circula de verdad.
            page.DefaultTextStyle(x => x.FontSize(8.5f).SemiBold().FontColor(Colores.Texto));

            page.Header().Element(Cabecera);
            page.Content().PaddingVertical(8).Element(Contenido);
            page.Footer().AlignCenter().Text(t =>
            {
                t.DefaultTextStyle(x => x.FontSize(7.5f));
                t.Span($"Novedades de entrega · emitido {emitido:dd/MM/yyyy HH:mm} · Página ");
                t.CurrentPageNumber();
                t.Span(" de ");
                t.TotalPages();
            });
        });

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Text("Reporte de Novedades de Entrega")
                .FontSize(14).Bold().FontColor(Colores.Fuerte);

            col.Item().PaddingTop(2).Text($"Emitido {emitido:dd/MM/yyyy HH:mm}").FontSize(9);

            col.Item().PaddingTop(3).Text(filtros is null ? "Sin filtros: todas las novedades vigentes." : $"Filtrado: {filtros}")
                .FontSize(8).Bold();

            col.Item().PaddingTop(3).Text(Resumen()).FontSize(8);

            if (total > filas.Count)
                col.Item().PaddingTop(4).Background(Colores.AnuladoFondo)
                    .Border(1).BorderColor(Colores.Anulado).Padding(3)
                    .Text($"Se muestran las primeras {filas.Count} de {total}. Acota con los filtros para ver el resto.")
                    .Bold().FontColor(Colores.Anulado);
        });

    /// <summary>Cuántas hay y cuánto valen, con el estado de la revisión.</summary>
    private string Resumen()
    {
        string Cuenta(string estado) => filas.Count(f => f.Estado == estado).ToString(Peru);

        return $"{filas.Count.ToString(Peru)} novedades   ·   No entregado {Textos.Monto(filas.Sum(f => f.Importe))}"
               + $"   ·   Por revisar {Cuenta(EstadoNovedad.Pendiente)}"
               + $"   ·   Recibidas {Cuenta(EstadoNovedad.Recibida)}"
               + $"   ·   Faltantes {Cuenta(EstadoNovedad.Faltante)}"
               + $"   ·   Sin retorno {Cuenta(EstadoNovedad.SinRetorno)}";
    }

    private void Contenido(IContainer container)
    {
        if (filas.Count == 0)
        {
            container.Border(Linea).BorderColor(Colores.Linea).Padding(20).AlignCenter()
                .Text("No hay novedades con esos filtros.");
            return;
        }

        container.Border(Linea).BorderColor(Colores.Linea).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(50);   // fecha
                c.RelativeColumn(1.6f); // producto
                c.ConstantColumn(105);  // no entregado
                c.ConstantColumn(62);   // importe
                c.RelativeColumn(1.5f); // motivo
                c.RelativeColumn(1.4f); // pedido y cliente
                c.ConstantColumn(50);   // despacho
                c.ConstantColumn(78);   // estado
            });

            // Se repite en cada hoja: una segunda página sin cabecera es una
            // lista de números sin decir cuál es cuál.
            tabla.Header(h =>
            {
                Encabezado(h.Cell(), "FECHA");
                Encabezado(h.Cell(), "PRODUCTO");
                Encabezado(h.Cell(), "NO ENTREGADO");
                Encabezado(h.Cell(), "IMPORTE", derecha: true);
                Encabezado(h.Cell(), "MOTIVO");
                Encabezado(h.Cell(), "PEDIDO / CLIENTE");
                Encabezado(h.Cell(), "DESPACHO");
                Encabezado(h.Cell(), "ESTADO");
            });

            foreach (var f in filas)
            {
                Celda(tabla.Cell(), Zona.ALocal(f.Fecha).ToString("dd/MM/yy", Peru));

                Celda(tabla.Cell(), f.Producto, f.Codigo);

                Celda(tabla.Cell(), Cantidad(f, f.CantidadNoEntregada), fuerte: true);

                Celda(tabla.Cell(), Textos.Monto(f.Importe), derecha: true);

                Celda(tabla.Cell(), f.Motivo, f.Observacion);

                Celda(tabla.Cell(), f.Pedido, f.Cliente);

                Celda(tabla.Cell(), f.Despacho ?? "—");

                Celda(tabla.Cell(), TextoEstado(f.Estado), Revision(f), anulada: f.Estado == EstadoNovedad.Anulada);
            }

            // El total va en la propia tabla, en la misma columna que el importe.
            tabla.Cell().ColumnSpan(3).BorderTop(Linea).BorderColor(Colores.Linea)
                .PaddingVertical(4).PaddingHorizontal(4).AlignRight().Text("TOTAL").Bold();
            tabla.Cell().BorderTop(Linea).BorderColor(Colores.Linea)
                .PaddingVertical(4).PaddingHorizontal(4).AlignRight()
                .Text(Textos.Monto(filas.Sum(f => f.Importe))).Bold();
            tabla.Cell().ColumnSpan(4).BorderTop(Linea).BorderColor(Colores.Linea).Text(string.Empty);
        });
    }

    /// <summary>Lo no entregado dicho como se cuenta en el almacén: "9 Caja 12UND + 5 UND".</summary>
    private static string Cantidad(NovedadResponse f, decimal baseUnidades)
    {
        if (f.Factor <= 1 || string.IsNullOrEmpty(f.Presentacion))
            return $"{Textos.Cantidad(baseUnidades)} {f.UnidadBase}";

        var cajas = decimal.Floor(baseUnidades / f.Factor + 0.000001m);
        var sueltas = Math.Round(baseUnidades - cajas * f.Factor, 4);

        var partes = new List<string>();
        if (cajas > 0) partes.Add($"{Textos.Cantidad(cajas)} {f.Presentacion}");
        if (sueltas > 0) partes.Add($"{Textos.Cantidad(sueltas)} {f.UnidadBase}");
        return partes.Count == 0 ? $"0 {f.UnidadBase}" : string.Join(" + ", partes);
    }

    /// <summary>Lo que el encargado encontró al contar, si ya lo contó.</summary>
    private static string? Revision(NovedadResponse f)
    {
        if (f.VerificadoEn is null) return null;

        var volvio = f.CantidadRegresada ?? 0;
        var texto = $"Volvió {Cantidad(f, volvio)}";
        return f.Estado == EstadoNovedad.Faltante
            ? $"{texto}; faltó {Cantidad(f, Math.Max(f.CantidadNoEntregada - volvio, 0))}"
            : texto;
    }

    private static string TextoEstado(string estado) => estado switch
    {
        EstadoNovedad.Pendiente => "Por revisar",
        EstadoNovedad.Recibida => "Recibida",
        EstadoNovedad.Faltante => "Faltante",
        EstadoNovedad.SinRetorno => "Sin retorno",
        EstadoNovedad.Anulada => "Anulada",
        _ => estado,
    };

    private static void Encabezado(IContainer celda, string texto, bool derecha = false)
    {
        var c = celda.BorderBottom(Linea).BorderColor(Colores.Linea).PaddingVertical(4).PaddingHorizontal(4);
        (derecha ? c.AlignRight() : c.AlignLeft()).Text(texto).Bold().FontSize(8);
    }

    /// <summary>Una celda con su dato y, debajo, una línea de apoyo más chica.</summary>
    private static void Celda(
        IContainer celda, string texto, string? apoyo = null,
        bool derecha = false, bool fuerte = false, bool anulada = false)
    {
        var c = celda.BorderBottom(Linea).BorderColor(Colores.LineaSuave).PaddingVertical(2.5f).PaddingHorizontal(4);
        var alineada = derecha ? c.AlignRight() : c.AlignLeft();

        alineada.Column(col =>
        {
            var t = col.Item().Text(texto);
            if (fuerte) t.Bold();
            if (anulada) t.FontColor(Colores.Anulado);

            if (!string.IsNullOrWhiteSpace(apoyo))
                col.Item().Text(apoyo).FontSize(7.5f);
        });
    }
}
