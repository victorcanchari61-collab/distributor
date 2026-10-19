using System.Globalization;
using Backend.Dtos.Responses;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;

namespace Backend.Service.Pdf;

/// <summary>
/// El reporte de cualquier dashboard, en papel: dibuja las columnas, filas y totales que trae el
/// reporte, sin saber de qué dashboard es. Así un reporte nuevo sale impreso sin escribir otro PDF.
///
/// Sale de la misma consulta que la pantalla —fechas, vista, filtros y búsqueda— y lo filtrado va
/// escrito en la cabecera: un recorte que no lo dice pasa por el total de todo.
/// </summary>
public sealed class ReporteTableroA4(EmpresaResponse empresa, ReporteResponse reporte, DateTime emitido) : IDocument
{
    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");

    private string Vista => reporte.Vistas.FirstOrDefault(v => v.Id == reporte.Vista)?.Texto ?? reporte.Vista;

    /// <summary>"Reporte de pedidos y reparto" → "PEDIDOS Y REPARTO", para el recuadro.</summary>
    private string Area => (reporte.Titulo.StartsWith("Reporte de ", StringComparison.OrdinalIgnoreCase)
        ? reporte.Titulo["Reporte de ".Length..]
        : reporte.Titulo).ToUpper(Peru);

    private string Periodo => !reporte.ConFechas
        ? $"AL {emitido:dd/MM/yyyy}"
        : reporte.Desde == reporte.Hasta
            ? $"{reporte.Desde:dd/MM/yyyy}"
            : $"{reporte.Desde:dd/MM/yyyy} al {reporte.Hasta:dd/MM/yyyy}";

    public void Compose(IDocumentContainer container) =>
        container.Page(page =>
        {
            ReporteA4.Hoja(page, apaisada: true, $"{reporte.Titulo} · {Vista.ToLower(Peru)}", emitido);
            page.Header().Element(Cabecera);
            page.Content().PaddingVertical(8).Column(col =>
            {
                if (reporte.Filas.Count == 0)
                {
                    col.Item().Element(c => ReporteA4.Vacio(c, "No hay datos con esos filtros."));
                    return;
                }

                col.Item().Element(Tabla);
                if (!string.IsNullOrWhiteSpace(reporte.Nota))
                    col.Item().PaddingTop(4).Text(reporte.Nota).FontSize(6.5f);
            });
        });

    private void Cabecera(IContainer container) =>
        container.Column(col =>
        {
            col.Item().Element(c => Comprobante.Membrete(c, empresa, ["REPORTE", Area, Vista.ToUpper(Peru), Periodo]));

            var nota = Textos.Juntar(" · ",
                reporte.Filtrado is null ? "SIN FILTROS" : $"FILTRADO: {reporte.Filtrado}",
                reporte.Aviso);

            col.Item().PaddingTop(8).Element(c => Comprobante.Datos(c,
                reporte.Resumen.Select(r => new DatoImprimible(r.Titulo.ToUpper(Peru), Formato(r.Valor, r.Tipo, conSimbolo: true))).ToList(),
                columnas: Math.Max(1, reporte.Resumen.Count), nota: nota));
        });

    private void Tabla(IContainer container)
    {
        var columnas = reporte.Columnas;
        // Lo que va antes de la primera columna con total se junta bajo el rótulo "TOTAL".
        var primeraConTotal = columnas.FindIndex(c => reporte.Totales.ContainsKey(c.Clave));

        ReporteA4.Marco(container).Table(tabla =>
        {
            tabla.ColumnsDefinition(c =>
            {
                c.ConstantColumn(22);
                foreach (var col in columnas)
                    if (col.Ancho > 0) c.ConstantColumn(col.Ancho);
                    else c.RelativeColumn();
            });

            tabla.Header(h =>
            {
                ReporteA4.Encabezado(h.Cell(), "N°", primera: true);
                foreach (var col in columnas) ReporteA4.Encabezado(h.Cell(), col.Titulo.ToUpper(Peru));
            });

            var n = 0;
            foreach (var fila in reporte.Filas)
            {
                n++;
                ReporteA4.Celda(tabla.Cell(), n.ToString(Peru), centro: true, primera: true);
                foreach (var col in columnas)
                {
                    var valor = fila.GetValueOrDefault(col.Clave);
                    var apoyo = col.Apoyo is null ? null : fila.GetValueOrDefault(col.Apoyo)?.ToString();
                    ReporteA4.Celda(tabla.Cell(), Formato(valor, col.Tipo), apoyo,
                        derecha: col.Tipo is not (TipoDato.Texto or TipoDato.Fecha), centro: col.Tipo == TipoDato.Fecha,
                        fuerte: col.Destacada);
                }
            }

            if (primeraConTotal < 0) return;

            ReporteA4.Total(tabla.Cell(), "TOTAL", primera: true, columnas: (uint)(1 + primeraConTotal));
            foreach (var col in columnas.Skip(primeraConTotal))
                ReporteA4.Total(tabla.Cell(), reporte.Totales.TryGetValue(col.Clave, out var total) ? Formato(total, col.Tipo) : string.Empty);
        });
    }

    /// <summary>Un valor como se escribe en el papel, según su tipo.</summary>
    private static string Formato(object? valor, string tipo, bool conSimbolo = false)
    {
        if (valor is null) return "—";

        return tipo switch
        {
            TipoDato.Moneda => conSimbolo ? Textos.Monto(Convert.ToDecimal(valor, Peru)) : Textos.Numero(Convert.ToDecimal(valor, Peru)),
            TipoDato.Entero => Convert.ToDecimal(valor, Peru).ToString("N0", Peru),
            TipoDato.Cantidad => Textos.Cantidad(Convert.ToDecimal(valor, Peru)),
            TipoDato.Porcentaje => $"{Convert.ToDecimal(valor, Peru).ToString("0.0", Peru)}%",
            TipoDato.Fecha => valor is DateTime f ? f.ToString("dd/MM/yyyy", Peru) : valor.ToString() ?? "—",
            _ => valor.ToString() is string s && s.Length > 0 ? s : "—",
        };
    }
}
