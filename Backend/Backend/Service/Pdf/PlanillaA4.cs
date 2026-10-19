using System.Globalization;
using Backend.Dtos.Responses;
using Backend.Models;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// La planilla de una semana en una hoja: una fila por trabajador con cada concepto, lo que se le
/// paga y una casilla para que firme al recibirlo.
///
/// Es el papel del pago: las boletas son de cada trabajador, esta es la del negocio. Los totales
/// salen de la planilla tal como la calculó el sistema, no se rehacen aquí.
/// </summary>
public sealed class PlanillaA4(EmpresaResponse empresa, PlanillaResponse planilla, DateTime emitido) : IDocument
{
    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    private string Semana => $"{planilla.Desde:dd/MM} al {planilla.Hasta:dd/MM/yyyy}";

    private string Estado => planilla.Estado switch
    {
        EstadoPlanilla.Borrador => "BORRADOR",
        EstadoPlanilla.Pagada => "PAGADA",
        EstadoPlanilla.Anulada => "ANULADA",
        _ => planilla.Estado,
    };

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            ReporteA4.Hoja(page, apaisada: true, $"Planilla del {Semana}", emitido);
            page.Header().Element(Cabecera);
            page.Content().PaddingVertical(8).Column(col =>
            {
                if (planilla.Detalle.Count == 0)
                {
                    col.Item().Element(c => ReporteA4.Vacio(c, "Esta planilla no tiene a nadie."));
                    return;
                }

                col.Item().Element(Tabla);

                var ajustes = planilla.Detalle.Where(d => !string.IsNullOrWhiteSpace(d.NotaAjuste)).ToList();
                if (ajustes.Count > 0)
                {
                    col.Item().Element(c => ReporteA4.Titulo(c, "AJUSTES A MANO"));
                    foreach (var d in ajustes)
                        col.Item().Text($"{d.Empleado}: {d.NotaAjuste}").FontSize(7.5f);
                }

                col.Item().PaddingTop(28).Row(row =>
                {
                    row.RelativeItem().PaddingRight(40).Element(c => ReporteA4.Firma(c, "ELABORADO POR"));
                    row.RelativeItem().PaddingHorizontal(20).Element(c => ReporteA4.Firma(c, "REVISADO POR"));
                    row.RelativeItem().PaddingLeft(40).Element(c => ReporteA4.Firma(c, "APROBADO POR", empresa.RazonSocial));
                });
            });
        });

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Element(c => Comprobante.Membrete(c, empresa, ["PLANILLA SEMANAL", Semana, Estado]));

            if (planilla.Estado == EstadoPlanilla.Anulada)
                col.Item().PaddingTop(6).Element(c => Comprobante.Anulado(c, "PLANILLA ANULADA: no tiene validez."));

            col.Item().PaddingTop(8).Element(c => Comprobante.Datos(c,
            [
                new("EMPLEADOS", planilla.Detalle.Count.ToString(Peru)),
                new("COSTO DE PLANILLA", Textos.Monto(planilla.TotalCostoLaboral)),
                new("FALTANTES DESCONTADOS", Textos.Monto(planilla.TotalFaltantes)),
                new("ADELANTOS DESCONTADOS", Textos.Monto(planilla.TotalAdelantos)),
                new("NETO A PAGAR", Textos.Monto(planilla.TotalNeto)),
                new("ESTADO", Estado),
                new("PAGADA EL", planilla.FechaPago is DateTime f ? Zona.ALocal(f).ToString("dd/MM/yyyy HH:mm", Peru) : "—"),
                new("SALIÓ DE", planilla.CuentaFinanciera ?? "—"),
            ], columnas: 4, nota: planilla.Estado == EstadoPlanilla.Borrador
                ? "BORRADOR: los montos pueden cambiar hasta que se pague."
                : null));
        });

    private void Tabla(IContainer container)
    {
        var filas = planilla.Detalle.OrderBy(d => d.Empleado, StringComparer.Create(Peru, true)).ToList();

        ReporteA4.Marco(container).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(18);   // n°
                c.RelativeColumn();     // empleado
                c.ConstantColumn(54);   // dni
                c.ConstantColumn(54);   // sueldo
                c.ConstantColumn(62);   // faltas y permisos
                c.ConstantColumn(50);   // feriados
                c.ConstantColumn(50);   // bonos
                c.ConstantColumn(52);   // otros
                c.ConstantColumn(52);   // faltantes
                c.ConstantColumn(54);   // adelantos
                c.ConstantColumn(60);   // neto
                c.ConstantColumn(92);   // firma
            });

            tabla.Header(h =>
            {
                ReporteA4.Encabezado(h.Cell(), "N°", primera: true);
                ReporteA4.Encabezado(h.Cell(), "EMPLEADO");
                ReporteA4.Encabezado(h.Cell(), "DNI");
                ReporteA4.Encabezado(h.Cell(), "SUELDO");
                ReporteA4.Encabezado(h.Cell(), "FALTAS Y PERM.");
                ReporteA4.Encabezado(h.Cell(), "FERIADOS");
                ReporteA4.Encabezado(h.Cell(), "BONOS");
                ReporteA4.Encabezado(h.Cell(), "OTROS DESC.");
                ReporteA4.Encabezado(h.Cell(), "FALTANTES");
                ReporteA4.Encabezado(h.Cell(), "ADELANTOS");
                ReporteA4.Encabezado(h.Cell(), "NETO");
                ReporteA4.Encabezado(h.Cell(), "FIRMA");
            });

            var n = 0;
            foreach (var d in filas)
            {
                n++;
                ReporteA4.Celda(tabla.Cell(), n.ToString(Peru), centro: true, primera: true);
                ReporteA4.Celda(tabla.Cell(), d.Empleado, d.Cargo);
                ReporteA4.Celda(tabla.Cell(), d.Documento ?? "—", centro: true);
                ReporteA4.Celda(tabla.Cell(), Textos.Numero(d.SueldoSemanal), derecha: true);
                ReporteA4.Celda(tabla.Cell(), ReporteA4.MontoORaya(d.DescuentoInasistencias),
                    d.DiasNoPagados > 0 ? $"{d.DiasNoPagados} día{(d.DiasNoPagados == 1 ? "" : "s")}" : null, derecha: true);
                ReporteA4.Celda(tabla.Cell(), ReporteA4.MontoORaya(d.ExtraFeriados), derecha: true);
                ReporteA4.Celda(tabla.Cell(), ReporteA4.MontoORaya(d.Bonos), derecha: true);
                ReporteA4.Celda(tabla.Cell(), ReporteA4.MontoORaya(d.OtrosDescuentos), derecha: true);
                ReporteA4.Celda(tabla.Cell(), ReporteA4.MontoORaya(d.DescuentoFaltantes), derecha: true);
                ReporteA4.Celda(tabla.Cell(), ReporteA4.MontoORaya(d.DescuentoAdelantos), derecha: true);
                ReporteA4.Celda(tabla.Cell(), Textos.Numero(d.Neto), derecha: true, fuerte: true);
                // Alta a propósito: es donde firma el trabajador al recibir su pago.
                tabla.Cell().BorderLeft(Comprobante.Linea).BorderBottom(0.5f).BorderColor(Colores.BordeTabla).MinHeight(26);
            }

            ReporteA4.Total(tabla.Cell(), "TOTALES", primera: true, columnas: 3);
            ReporteA4.Total(tabla.Cell(), Textos.Numero(filas.Sum(d => d.SueldoSemanal)));
            ReporteA4.Total(tabla.Cell(), ReporteA4.MontoORaya(filas.Sum(d => d.DescuentoInasistencias)));
            ReporteA4.Total(tabla.Cell(), ReporteA4.MontoORaya(filas.Sum(d => d.ExtraFeriados)));
            ReporteA4.Total(tabla.Cell(), ReporteA4.MontoORaya(filas.Sum(d => d.Bonos)));
            ReporteA4.Total(tabla.Cell(), ReporteA4.MontoORaya(filas.Sum(d => d.OtrosDescuentos)));
            ReporteA4.Total(tabla.Cell(), ReporteA4.MontoORaya(planilla.TotalFaltantes));
            ReporteA4.Total(tabla.Cell(), ReporteA4.MontoORaya(planilla.TotalAdelantos));
            ReporteA4.Total(tabla.Cell(), Textos.Numero(planilla.TotalNeto));
            ReporteA4.Total(tabla.Cell(), string.Empty);
        });
    }
}
