using System.Globalization;
using Backend.Dtos.Responses;
using Backend.Models;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// La asistencia de un mes en un cuadro: una fila por empleado, una columna por día, y al final
/// cuántas veces vino, llegó tarde, faltó o tuvo permiso.
///
/// Es el papel que se firma o se archiva a fin de mes, así que va como el cuaderno de asistencia de
/// siempre: letras en las casillas y los domingos y feriados sombreados, que no se esperan. Apaisado
/// porque 31 días más los totales no entran de pie.
/// </summary>
public sealed class AsistenciaMesA4(
    EmpresaResponse empresa,
    DateTime desde,
    DateTime hasta,
    IReadOnlyList<EmpleadoAsistenciaResponse> empleados,
    IReadOnlyList<AsistenciaResponse> marcas,
    IReadOnlyList<FeriadoResponse> feriados,
    string? soloEmpleado,
    DateTime hoy,
    DateTime emitido) : IDocument
{
    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    private static readonly string[] Meses =
    [
        "ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO",
        "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE",
    ];

    // Lunes = L ... domingo = D, en el orden de DayOfWeek (domingo primero).
    private static readonly string[] Iniciales = ["D", "L", "M", "M", "J", "V", "S"];

    private static readonly Dictionary<string, string> Abrevia = new()
    {
        [EstadoAsistencia.Presente] = "P",
        [EstadoAsistencia.Tardanza] = "T",
        [EstadoAsistencia.Falta] = "F",
        [EstadoAsistencia.Permiso] = "PM",
    };

    private List<DateTime> Dias => Enumerable.Range(0, (hasta.Date - desde.Date).Days + 1)
        .Select(i => desde.Date.AddDays(i)).ToList();

    private bool EsFeriado(DateTime dia) => feriados.Any(f => f.Fecha.Date == dia);

    private static bool SeEspera(DateTime dia, bool feriado) => dia.DayOfWeek != DayOfWeek.Sunday && !feriado;

    /// <summary>Si trabajaba aquí ese día: ya había entrado y todavía no cesaba.</summary>
    private static bool Trabajaba(EmpleadoAsistenciaResponse e, DateTime dia) =>
        (e.Activo || e.FechaCese is not null)
        && (e.FechaIngreso is null || e.FechaIngreso.Value.Date <= dia)
        && (e.FechaCese is null || e.FechaCese.Value.Date >= dia);

    private AsistenciaResponse? MarcaDe(int empleadoId, DateTime dia) =>
        marcas.FirstOrDefault(m => m.EmpleadoId == empleadoId && m.Fecha.Date == dia);

    /// <summary>Los días de lunes a sábado, no feriados, ya pasados y en contrato, sin marca.</summary>
    private int SinMarcar(EmpleadoAsistenciaResponse e) =>
        Dias.Count(d => d <= hoy && SeEspera(d, EsFeriado(d)) && Trabajaba(e, d) && MarcaDe(e.Id, d) is null);

    private int Cuenta(int empleadoId, string estado) =>
        marcas.Count(m => m.EmpleadoId == empleadoId && m.Estado == estado);

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            ReporteA4.Hoja(page, apaisada: true, "Asistencia del mes", emitido);
            page.Header().Element(Cabecera);
            page.Content().PaddingVertical(8).Column(col =>
            {
                if (empleados.Count == 0)
                {
                    col.Item().Element(c => ReporteA4.Vacio(c, "Nadie trabajaba aquí en este mes."));
                    return;
                }

                col.Item().Element(Cuadro);
                col.Item().PaddingTop(4).Text(
                    "P presente · T tardanza · F falta · PM permiso · — no trabajaba aquí ese día · " +
                    "S/M días sin marcar (lunes a sábado, sin contar feriados) · sombreados: domingos y feriados")
                    .FontSize(6.5f);

                var conNota = marcas.Where(m => !string.IsNullOrWhiteSpace(m.Observacion))
                    .OrderBy(m => m.Fecha).ThenBy(m => m.Empleado).ToList();
                if (conNota.Count > 0)
                {
                    col.Item().Element(c => ReporteA4.Titulo(c, "OBSERVACIONES"));
                    col.Item().Element(c => Observaciones(c, conNota));
                }
            });
        });

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Element(c => Comprobante.Membrete(c, empresa,
                ["ASISTENCIA DEL MES", $"{Meses[desde.Month - 1]} {desde.Year}", $"{emitido:dd/MM/yyyy HH:mm}"]));

            int Total(string estado) => marcas.Count(m => m.Estado == estado);
            var nota = Textos.Juntar(" · ",
                soloEmpleado is null ? null : $"SOLO: {soloEmpleado}",
                feriados.Count == 0
                    ? null
                    : "FERIADOS: " + string.Join(", ", feriados.OrderBy(f => f.Fecha).Select(f => $"{f.Fecha:dd/MM} {f.Nombre}")));

            col.Item().PaddingTop(8).Element(c => Comprobante.Datos(c,
            [
                new("EMPLEADOS", empleados.Count.ToString(Peru)),
                new("PRESENTES", Total(EstadoAsistencia.Presente).ToString(Peru)),
                new("TARDANZAS", Total(EstadoAsistencia.Tardanza).ToString(Peru)),
                new("FALTAS", Total(EstadoAsistencia.Falta).ToString(Peru)),
                new("PERMISOS", Total(EstadoAsistencia.Permiso).ToString(Peru)),
            ], columnas: 5, nota: nota));
        });

    private void Cuadro(IContainer container)
    {
        var dias = Dias;
        string[] totales = ["P", "T", "F", "PM", "S/M"];

        ReporteA4.Marco(container).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.RelativeColumn();
                foreach (var _ in dias) c.ConstantColumn(15.5f);
                foreach (var _ in totales) c.ConstantColumn(21);
            });

            tabla.Header(h =>
            {
                ReporteA4.Encabezado(h.Cell().RowSpan(2), "EMPLEADO", primera: true);
                foreach (var d in dias)
                    ReporteA4.Encabezado(h.Cell(), d.Day.ToString(Peru), fondo: Sombra(d));
                foreach (var t in totales)
                    ReporteA4.Encabezado(h.Cell().RowSpan(2), t);
                foreach (var d in dias)
                    ReporteA4.Encabezado(h.Cell(), Iniciales[(int)d.DayOfWeek], fondo: Sombra(d));
            });

            foreach (var e in empleados)
            {
                ReporteA4.Celda(tabla.Cell(), e.NombreCompleto, e.Cargo, primera: true, tamaño: 7.5f);

                foreach (var d in dias)
                {
                    var marca = MarcaDe(e.Id, d);
                    var texto = marca is not null ? Abrevia.GetValueOrDefault(marca.Estado, "?")
                        : Trabajaba(e, d) ? string.Empty
                        : "—";
                    ReporteA4.Celda(tabla.Cell(), texto, centro: true, fondo: Sombra(d), tamaño: 7);
                }

                ReporteA4.Celda(tabla.Cell(), Cuenta(e.Id, EstadoAsistencia.Presente).ToString(Peru), centro: true, tamaño: 7.5f);
                ReporteA4.Celda(tabla.Cell(), Cuenta(e.Id, EstadoAsistencia.Tardanza).ToString(Peru), centro: true, tamaño: 7.5f);
                ReporteA4.Celda(tabla.Cell(), Cuenta(e.Id, EstadoAsistencia.Falta).ToString(Peru), centro: true, tamaño: 7.5f);
                ReporteA4.Celda(tabla.Cell(), Cuenta(e.Id, EstadoAsistencia.Permiso).ToString(Peru), centro: true, tamaño: 7.5f);
                ReporteA4.Celda(tabla.Cell(), SinMarcar(e).ToString(Peru), centro: true, tamaño: 7.5f);
            }
        });
    }

    /// <summary>Domingos y feriados en gris: no se espera marca, y así se ve de un vistazo.</summary>
    private string? Sombra(DateTime dia) => SeEspera(dia, EsFeriado(dia)) ? null : Colores.Cabecera;

    private static void Observaciones(IContainer container, List<AsistenciaResponse> lista) =>
        ReporteA4.Marco(container).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(56);  // fecha
                c.RelativeColumn(1.2f); // empleado
                c.ConstantColumn(64);  // estado
                c.RelativeColumn(2.5f); // observación
            });

            tabla.Header(h =>
            {
                ReporteA4.Encabezado(h.Cell(), "FECHA", primera: true);
                ReporteA4.Encabezado(h.Cell(), "EMPLEADO");
                ReporteA4.Encabezado(h.Cell(), "ESTADO");
                ReporteA4.Encabezado(h.Cell(), "OBSERVACIÓN");
            });

            foreach (var m in lista)
            {
                ReporteA4.Celda(tabla.Cell(), m.Fecha.ToString("dd/MM/yyyy", Peru), centro: true, primera: true);
                ReporteA4.Celda(tabla.Cell(), m.Empleado);
                ReporteA4.Celda(tabla.Cell(), m.Estado switch
                {
                    EstadoAsistencia.Presente => "Presente",
                    EstadoAsistencia.Tardanza => "Tardanza",
                    EstadoAsistencia.Falta => "Falta",
                    EstadoAsistencia.Permiso => "Permiso",
                    _ => m.Estado,
                });
                ReporteA4.Celda(tabla.Cell(), m.Observacion!);
            }
        });
}
