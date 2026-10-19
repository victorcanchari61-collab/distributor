using System.Globalization;
using Backend.Dtos.Responses;
using Backend.Models;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// Los adelantos y préstamos a los trabajadores: cuánto se dio, cómo se descuenta, cuánto ya se
/// descontó en cada planilla y cuánto falta.
///
/// Primero lo que todavía se debe —es lo que se viene a mirar—, y después lo ya descontado. Los
/// anulados no van: nunca salieron de verdad.
/// </summary>
public sealed class AdelantosA4(EmpresaResponse empresa, IReadOnlyList<AdelantoResponse> adelantos, DateTime emitido) : IDocument
{
    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            ReporteA4.Hoja(page, apaisada: true, "Adelantos y préstamos", emitido);
            page.Header().Element(Cabecera);
            page.Content().PaddingVertical(8).Column(col =>
            {
                if (adelantos.Count == 0)
                {
                    col.Item().Element(c => ReporteA4.Vacio(c, "No hay adelantos registrados."));
                    return;
                }

                col.Item().Element(Tabla);
            });
        });

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Element(c => Comprobante.Membrete(c, empresa,
                ["ADELANTOS Y", "PRÉSTAMOS", $"{emitido:dd/MM/yyyy HH:mm}"]));

            var pendientes = adelantos.Where(a => a.Estado == EstadoAdelanto.Pendiente).ToList();
            col.Item().PaddingTop(8).Element(c => Comprobante.Datos(c,
            [
                new("POR DESCONTAR", pendientes.Count.ToString(Peru)),
                new("TRABAJADORES QUE DEBEN", pendientes.Select(a => a.EmpleadoId).Distinct().Count().ToString(Peru)),
                new("ENTREGADO", Textos.Monto(adelantos.Sum(a => a.Monto))),
                new("DESCONTADO", Textos.Monto(adelantos.Sum(a => a.Descontado))),
                new("FALTA DESCONTAR", Textos.Monto(adelantos.Sum(a => a.Saldo))),
            ], columnas: 5, nota: "No incluye los adelantos anulados."));
        });

    private void Tabla(IContainer container)
    {
        var filas = adelantos
            .OrderBy(a => a.Estado == EstadoAdelanto.Pendiente ? 0 : 1)
            .ThenBy(a => a.Empleado, StringComparer.Create(Peru, true))
            .ThenBy(a => a.Fecha)
            .ToList();

        ReporteA4.Marco(container).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(54);   // fecha
                c.RelativeColumn(1.2f); // empleado
                c.ConstantColumn(62);   // monto
                c.RelativeColumn(1.5f); // cómo se descuenta
                c.RelativeColumn(0.8f); // salió de
                c.ConstantColumn(64);   // descontado
                c.ConstantColumn(64);   // falta
                c.ConstantColumn(78);   // estado
            });

            tabla.Header(h =>
            {
                ReporteA4.Encabezado(h.Cell(), "FECHA", primera: true);
                ReporteA4.Encabezado(h.Cell(), "EMPLEADO");
                ReporteA4.Encabezado(h.Cell(), "MONTO");
                ReporteA4.Encabezado(h.Cell(), "CÓMO SE DESCUENTA");
                ReporteA4.Encabezado(h.Cell(), "SALIÓ DE");
                ReporteA4.Encabezado(h.Cell(), "DESCONTADO");
                ReporteA4.Encabezado(h.Cell(), "FALTA");
                ReporteA4.Encabezado(h.Cell(), "ESTADO");
            });

            foreach (var a in filas)
            {
                ReporteA4.Celda(tabla.Cell(), a.Fecha.ToString("dd/MM/yyyy", Peru), centro: true, primera: true);
                ReporteA4.Celda(tabla.Cell(), a.Empleado, Textos.Juntar(" · ", a.Cargo, a.Observacion));
                ReporteA4.Celda(tabla.Cell(), Textos.Numero(a.Monto), derecha: true);
                ReporteA4.Celda(tabla.Cell(), ComoSeDescuenta(a), Descuentos(a));
                ReporteA4.Celda(tabla.Cell(), a.CuentaFinanciera ?? "—");
                ReporteA4.Celda(tabla.Cell(), ReporteA4.MontoORaya(a.Descontado), derecha: true);
                ReporteA4.Celda(tabla.Cell(), ReporteA4.MontoORaya(a.Saldo), derecha: true, fuerte: a.Saldo > 0);
                ReporteA4.Celda(tabla.Cell(), a.Estado == EstadoAdelanto.Pendiente ? "Por descontar" : "Descontado", centro: true);
            }

            ReporteA4.Total(tabla.Cell(), "TOTALES", primera: true, columnas: 2);
            ReporteA4.Total(tabla.Cell(), Textos.Numero(filas.Sum(a => a.Monto)));
            ReporteA4.Total(tabla.Cell(), string.Empty, columnas: 2);
            ReporteA4.Total(tabla.Cell(), Textos.Numero(filas.Sum(a => a.Descontado)));
            ReporteA4.Total(tabla.Cell(), Textos.Numero(filas.Sum(a => a.Saldo)));
            ReporteA4.Total(tabla.Cell(), string.Empty);
        });
    }

    /// <summary>"Todo de una vez, desde la semana del 12/10" o "S/ 100.00 por semana, desde la del 12/10".</summary>
    private static string ComoSeDescuenta(AdelantoResponse a) =>
        a.CuotaSemanal is decimal cuota && cuota > 0
            ? $"{Textos.Monto(cuota)} por semana, desde la del {a.DescontarDesde:dd/MM}"
            : $"Todo de una vez, en la semana del {a.DescontarDesde:dd/MM}";

    /// <summary>Lo descontado en cada planilla: "12/10: S/ 60.00 · 19/10: S/ 100.00".</summary>
    private static string? Descuentos(AdelantoResponse a) =>
        a.Descuentos.Count == 0
            ? null
            : "Descontado: " + string.Join(" · ", a.Descuentos.OrderBy(d => d.Desde)
                .Select(d => $"semana del {d.Desde:dd/MM}: {Textos.Monto(d.Monto)}"));
}
