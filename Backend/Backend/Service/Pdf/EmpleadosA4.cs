using System.Globalization;
using Backend.Dtos.Responses;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// El padrón de empleados: quién trabaja hoy en el negocio y, aparte, quién ya se fue.
///
/// Los cesados van en su propio bloque y no mezclados: el papel se usa sobre todo para saber con
/// quién se cuenta, y una lista donde cada tercera fila ya no trabaja obliga a leerla entera.
/// </summary>
public sealed class EmpleadosA4(EmpresaResponse empresa, IReadOnlyList<EmpleadoResponse> empleados, DateTime emitido) : IDocument
{
    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    private readonly List<EmpleadoResponse> activos = Ordenar(empleados.Where(e => e.Activo));
    private readonly List<EmpleadoResponse> fuera = Ordenar(empleados.Where(e => !e.Activo));

    private static List<EmpleadoResponse> Ordenar(IEnumerable<EmpleadoResponse> lista) =>
        lista.OrderBy(e => e.Apellidos, StringComparer.Create(Peru, true))
            .ThenBy(e => e.Nombres, StringComparer.Create(Peru, true))
            .ToList();

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            ReporteA4.Hoja(page, apaisada: false, "Padrón de empleados", emitido);
            page.Header().Element(Cabecera);
            page.Content().PaddingVertical(4).Column(col =>
            {
                if (activos.Count + fuera.Count == 0)
                {
                    col.Item().PaddingTop(6).Element(c => ReporteA4.Vacio(c, "Todavía no hay empleados registrados."));
                    return;
                }

                col.Item().Element(c => ReporteA4.Titulo(c, $"ACTIVOS ({activos.Count})"));
                col.Item().Element(c => Tabla(c, activos, cesados: false));

                if (fuera.Count > 0)
                {
                    col.Item().Element(c => ReporteA4.Titulo(c, $"CESADOS E INACTIVOS ({fuera.Count})"));
                    col.Item().Element(c => Tabla(c, fuera, cesados: true));
                }
            });
        });

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Element(c => Comprobante.Membrete(c, empresa,
                ["PADRÓN DE", "EMPLEADOS", $"{emitido:dd/MM/yyyy HH:mm}"]));

            var planilla = activos.Sum(e => e.SueldoSemanal ?? 0);
            col.Item().PaddingTop(8).Element(c => Comprobante.Datos(c,
            [
                new("ACTIVOS", activos.Count.ToString(Peru)),
                new("CESADOS E INACTIVOS", fuera.Count.ToString(Peru)),
                new("CON USUARIO", activos.Concat(fuera).Count(e => e.UsuarioId is not null).ToString(Peru)),
                new("PLANILLA SEM.", Textos.Monto(planilla)),
            ], columnas: 4, nota: "PLANILLA SEM.: la suma de los sueldos semanales de los activos, sin descuentos ni extras."));
        });

    private static void Tabla(IContainer container, List<EmpleadoResponse> lista, bool cesados)
    {
        if (lista.Count == 0)
        {
            ReporteA4.Vacio(container, "Nadie en este grupo.");
            return;
        }

        ReporteA4.Marco(container).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(20);   // n°
                c.ConstantColumn(62);   // documento
                c.RelativeColumn(1.6f); // apellidos y nombres
                c.ConstantColumn(54);   // ingreso
                c.ConstantColumn(62);   // teléfono o cese
                c.ConstantColumn(62);   // sueldo
                c.RelativeColumn();     // usuario
            });

            tabla.Header(h =>
            {
                ReporteA4.Encabezado(h.Cell(), "N°", primera: true);
                ReporteA4.Encabezado(h.Cell(), "DOCUMENTO");
                ReporteA4.Encabezado(h.Cell(), "APELLIDOS Y NOMBRES");
                ReporteA4.Encabezado(h.Cell(), "INGRESO");
                ReporteA4.Encabezado(h.Cell(), cesados ? "CESE" : "TELÉFONO");
                ReporteA4.Encabezado(h.Cell(), "SUELDO SEM.");
                ReporteA4.Encabezado(h.Cell(), "USUARIO");
            });

            var n = 0;
            foreach (var e in lista)
            {
                n++;
                ReporteA4.Celda(tabla.Cell(), n.ToString(Peru), centro: true, primera: true);
                ReporteA4.Celda(tabla.Cell(), e.Documento, e.TipoDoc == "DNI" ? null : e.TipoDoc);
                ReporteA4.Celda(tabla.Cell(), $"{e.Apellidos}, {e.Nombres}", Textos.Juntar(" · ", e.Cargo, e.Area));
                ReporteA4.Celda(tabla.Cell(), Fecha(e.FechaIngreso), centro: true);
                ReporteA4.Celda(tabla.Cell(),
                    cesados ? (e.FechaCese is null ? "Desactivado" : Fecha(e.FechaCese)) : e.Telefono ?? "—",
                    centro: true);
                ReporteA4.Celda(tabla.Cell(), e.SueldoSemanal is decimal s ? Textos.Numero(s) : "—", derecha: true);
                ReporteA4.Celda(tabla.Cell(), e.Usuario ?? "—");
            }
        });
    }

    private static string Fecha(DateTime? fecha) => fecha?.ToString("dd/MM/yyyy", Peru) ?? "—";
}
