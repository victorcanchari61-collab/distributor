using System.Globalization;
using Backend.Dtos.Responses;
using Backend.Models;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// Las boletas de pago de una planilla semanal: lo que cobró cada trabajador y por qué.
///
/// Dos por hoja, con una línea para cortar: es un papel corto que se le da a cada uno para que
/// firme que recibió, y una hoja por persona sería medio papel en blanco. Los montos son los de la
/// planilla tal como la ve la pantalla: este papel no suma nada por su cuenta.
///
/// Si la planilla no está pagada lo dice en rojo: un borrador impreso no puede pasar por un pago.
/// </summary>
public sealed class BoletasPlanillaA4(
    EmpresaResponse empresa,
    PlanillaResponse planilla,
    IReadOnlyList<PlanillaDetalleResponse> detalles) : IDocument
{
    private const float Linea = Comprobante.Linea;

    /// <summary>El alto de cada boleta: media hoja A4 menos los márgenes y el corte.</summary>
    private const float AltoBoleta = 372;

    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.Margin(1, Unit.Centimetre);
            page.DefaultTextStyle(x => Comprobante.Estilo(x, 8));

            page.Content().Column(col =>
            {
                for (var i = 0; i < detalles.Count; i++)
                {
                    var detalle = detalles[i];
                    col.Item().Height(AltoBoleta).Element(c => Boleta(c, detalle));

                    if (i % 2 == 0 && i < detalles.Count - 1)
                    {
                        // Por donde se corta: la de arriba y la de abajo son de dos personas.
                        col.Item().PaddingVertical(9).Row(row =>
                        {
                            row.RelativeItem().AlignMiddle().LineHorizontal(0.5f).LineDashPattern([4f, 3f]);
                            row.AutoItem().PaddingHorizontal(6).Text("cortar aquí").FontSize(6.5f);
                            row.RelativeItem().AlignMiddle().LineHorizontal(0.5f).LineDashPattern([4f, 3f]);
                        });
                    }
                    else if (i < detalles.Count - 1)
                    {
                        col.Item().PageBreak();
                    }
                }
            });
        });

    private void Boleta(IContainer container, PlanillaDetalleResponse d) =>
        container.Column(col =>
        {
            col.Item().Element(c => Comprobante.Membrete(c, empresa,
                ["BOLETA DE PAGO", "SEMANAL", $"{planilla.Desde:dd/MM} al {planilla.Hasta:dd/MM/yyyy}"], e: 0.8f));

            if (planilla.Estado == EstadoPlanilla.Borrador)
                col.Item().PaddingTop(5).Element(c => Comprobante.Anulado(c,
                    "BORRADOR: esta planilla todavía no se pagó. Los montos pueden cambiar."));
            else if (planilla.Estado == EstadoPlanilla.Anulada)
                col.Item().PaddingTop(5).Element(c => Comprobante.Anulado(c,
                    "PLANILLA ANULADA: este pago se revirtió. Sin validez."));

            col.Item().PaddingTop(6).Element(c => Comprobante.Datos(c, Datos(d), columnas: 3, e: 1.1f));

            col.Item().PaddingTop(6).Element(c => Conceptos(c, d));

            col.Item().PaddingTop(4).Text($"SON: {MontoEnLetras.Soles(d.Neto)}").FontSize(7.5f);

            if (planilla.Estado == EstadoPlanilla.Borrador && d.DiasSinMarcar > 0)
                col.Item().PaddingTop(2).Text(
                    $"Ojo: {d.DiasSinMarcar} {(d.DiasSinMarcar == 1 ? "día" : "días")} sin marcar en la asistencia se pagan como trabajados.")
                    .FontSize(7);

            // Las firmas al pie de la boleta, se acabe donde se acabe la tabla.
            col.Item().ExtendVertical().AlignBottom().Row(row =>
            {
                row.RelativeItem().PaddingRight(30).Element(c => Firma(c, "RECIBÍ CONFORME", d.Empleado,
                    d.Documento is null ? null : $"DNI {d.Documento}"));
                row.RelativeItem().PaddingLeft(30).Element(c => Firma(c, "EL EMPLEADOR", empresa.RazonSocial,
                    $"RUC {empresa.Ruc}"));
            });
        });

    private List<DatoImprimible> Datos(PlanillaDetalleResponse d)
    {
        var datos = new List<DatoImprimible>
        {
            new("TRABAJADOR", d.Empleado),
            new("DOCUMENTO", d.Documento ?? "—"),
            new("CARGO", d.Cargo ?? "—"),
            new("SEMANA", $"{planilla.Desde:dd/MM/yyyy} al {planilla.Hasta:dd/MM/yyyy}"),
            new("SUELDO SEMANAL", Textos.Monto(d.SueldoSemanal)),
        };

        if (planilla.Estado == EstadoPlanilla.Pagada && planilla.FechaPago is DateTime pago)
            datos.Add(new("PAGADO EL", Zona.ALocal(pago).ToString("dd/MM/yyyy HH:mm", Peru)));
        else
            datos.Add(new("ESTADO", planilla.Estado == EstadoPlanilla.Anulada ? "ANULADA" : "BORRADOR"));

        return datos;
    }

    /// <summary>Lo que suma y lo que resta, en dos columnas, y abajo lo que recibe.</summary>
    private static void Conceptos(IContainer container, PlanillaDetalleResponse d)
    {
        var filas = new List<(string Concepto, string? Detalle, decimal Ingreso, decimal Descuento)>
        {
            ("Sueldo semanal", null, d.SueldoSemanal, 0),
        };
        if (d.DescuentoInasistencias > 0)
            filas.Add(("Días no pagados", $"{d.DiasNoPagados} {(d.DiasNoPagados == 1 ? "día" : "días")}: faltas, permisos o fuera de contrato", 0, d.DescuentoInasistencias));
        if (d.ExtraFeriados > 0)
            filas.Add(("Feriados trabajados", "Se pagan doble", d.ExtraFeriados, 0));
        if (d.Bonos > 0)
            filas.Add(("Bonos", d.NotaAjuste, d.Bonos, 0));
        if (d.OtrosDescuentos > 0)
            filas.Add(("Otros descuentos", d.NotaAjuste, 0, d.OtrosDescuentos));
        if (d.DescuentoFaltantes > 0)
            filas.Add(("Faltantes de caja", "Cierres de caja con faltante", 0, d.DescuentoFaltantes));
        if (d.DescuentoAdelantos > 0)
            filas.Add(("Adelantos", d.AdelantosSaldo > d.DescuentoAdelantos
                ? $"Queda por descontar {Textos.Monto(d.AdelantosSaldo - d.DescuentoAdelantos)}"
                : null, 0, d.DescuentoAdelantos));

        container.Border(Linea).BorderColor(Colores.BordeTabla).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.RelativeColumn();
                c.ConstantColumn(85);
                c.ConstantColumn(85);
            });

            tabla.Header(h =>
            {
                h.Cell().Element(c => Comprobante.Encabezado(c)).Text("CONCEPTO");
                h.Cell().Element(c => Comprobante.Encabezado(c)).Text("INGRESOS");
                h.Cell().Element(c => Comprobante.Encabezado(c)).Text("DESCUENTOS");
            });

            foreach (var (concepto, detalle, ingreso, descuento) in filas)
            {
                tabla.Cell().PaddingVertical(2.5f).PaddingHorizontal(5).Column(c =>
                {
                    c.Item().Text(concepto).FontSize(8);
                    if (!string.IsNullOrWhiteSpace(detalle)) c.Item().Text(detalle).FontSize(6.5f);
                });
                tabla.Cell().PaddingVertical(2.5f).PaddingHorizontal(5).AlignRight()
                    .Text(ingreso > 0 ? Textos.Monto(ingreso) : "").FontSize(8);
                tabla.Cell().PaddingVertical(2.5f).PaddingHorizontal(5).AlignRight()
                    .Text(descuento > 0 ? Textos.Monto(descuento) : "").FontSize(8);
            }

            var ingresos = filas.Sum(f => f.Ingreso);
            var descuentos = filas.Sum(f => f.Descuento);
            tabla.Cell().BorderTop(Linea).BorderColor(Colores.BordeTabla).PaddingVertical(3).PaddingHorizontal(5)
                .Text("TOTALES").FontSize(8);
            tabla.Cell().BorderTop(Linea).BorderColor(Colores.BordeTabla).PaddingVertical(3).PaddingHorizontal(5)
                .AlignRight().Text(Textos.Monto(ingresos)).FontSize(8);
            tabla.Cell().BorderTop(Linea).BorderColor(Colores.BordeTabla).PaddingVertical(3).PaddingHorizontal(5)
                .AlignRight().Text(Textos.Monto(descuentos)).FontSize(8);

            // Lo que se le paga, a todo el ancho y en grande: es lo que se viene a mirar.
            tabla.Cell().ColumnSpan(2).BorderTop(1.2f).BorderColor(Colores.BordeTabla).Background(Colores.Cabecera)
                .PaddingVertical(4).PaddingHorizontal(5).Text("NETO A PAGAR").FontSize(10);
            tabla.Cell().BorderTop(1.2f).BorderColor(Colores.BordeTabla).Background(Colores.Cabecera)
                .PaddingVertical(4).PaddingHorizontal(5).AlignRight().Text(Textos.Monto(d.Neto)).FontSize(10);
        });
    }

    private static void Firma(IContainer container, string titulo, string nombre, string? documento) =>
        container.Column(col =>
        {
            col.Item().Height(28);
            col.Item().LineHorizontal(0.75f);
            col.Item().PaddingTop(2).AlignCenter().Text(titulo).FontSize(7);
            col.Item().AlignCenter().Text(nombre).FontSize(7);
            if (documento is not null) col.Item().AlignCenter().Text(documento).FontSize(6.5f);
        });
}
