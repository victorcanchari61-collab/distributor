using System.Globalization;
using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// Los reportes de los dashboards. Este archivo tiene lo común —fechas, vistas, búsqueda,
/// totales y lo filtrado en palabras—; cada dashboard arma el suyo en su propio archivo
/// (ReportesService.Ventas.cs, .Cobranza.cs, ...).
///
/// Los números salen de las mismas fuentes que los gráficos del dashboard: un reporte que no
/// cuadra con su gráfico es peor que no tener reporte.
/// </summary>
public partial class ReportesService(
    AppDbContext context,
    IGananciaService ganancias,
    IPermisoService permisos,
    IUsuarioActual usuarioActual) : IReportesService
{
    private const int MaximoDias = 366;

    private static readonly CultureInfo Peru = CultureInfo.GetCultureInfo("es-PE");
    private static readonly StringComparer Orden = StringComparer.Create(Peru, true);

    public async Task<ReporteResponse> GenerarAsync(string tablero, ReporteRequest request)
    {
        var reporte = tablero switch
        {
            "ventas" => await LineasVendidasAsync(request, rentabilidad: false),
            "rentabilidad" => await LineasVendidasAsync(request, rentabilidad: true),
            "cobranza" => await CobranzaAsync(request),
            "compras" => await ComprasAsync(request),
            "inventario" => await InventarioAsync(request),
            "reparto" => await RepartoAsync(request),
            _ => throw new NotFoundException($"No hay reporte de {tablero}"),
        };

        reporte.Tablero = tablero;
        Terminar(reporte, request);
        return reporte;
    }

    // ------------------------------------------------------------- Lo común

    /// <summary>Sin fechas, los últimos 30 días; como mucho, un año.</summary>
    private static (DateTime Primero, DateTime Ultimo) Rango(ReporteRequest request)
    {
        var ultimo = request.Hasta?.Date ?? Zona.Hoy;
        var primero = request.Desde?.Date ?? ultimo.AddDays(-29);

        if (primero > ultimo)
            throw new BadRequestException("El \"desde\" no puede ser después del \"hasta\".");
        if ((ultimo - primero).TotalDays >= MaximoDias)
            throw new BadRequestException($"Elige un rango de hasta {MaximoDias} días.");

        return (primero, ultimo);
    }

    /// <summary>La vista pedida si existe; si no, la primera.</summary>
    private static string VistaDe(ReporteRequest request, List<VistaReporte> vistas) =>
        vistas.Any(v => v.Id == request.Vista) ? request.Vista! : vistas[0].Id;

    private static VistaReporte V(string id, string texto) => new() { Id = id, Texto = texto };

    private static ColumnaReporte Col(
        string clave, string titulo, string tipo = TipoDato.Texto,
        bool suma = false, string? apoyo = null, bool destacada = false, float ancho = 0) =>
        new() { Clave = clave, Titulo = titulo, Tipo = tipo, Suma = suma, Apoyo = apoyo, Destacada = destacada, Ancho = ancho };

    /// <summary>El margen: su total es ganancia sobre lo vendido sin IGV, no la suma de márgenes.</summary>
    private static ColumnaReporte ColMargen() => new()
    {
        Clave = "margen", Titulo = "Margen", Tipo = TipoDato.Porcentaje,
        Numerador = "ganancia", Denominador = "valorVenta", Ancho = 52,
    };

    /// <summary>Un filtro de lista con los valores que aparecen, ordenados y sin repetir.</summary>
    private static FiltroReporte Filtro(string clave, string titulo, IEnumerable<string> valores) => new()
    {
        Clave = clave,
        Titulo = titulo,
        Opciones = valores.Where(v => !string.IsNullOrWhiteSpace(v)).Distinct().OrderBy(v => v, Orden)
            .Select(v => new OpcionReporte { Valor = v, Texto = v }).ToList(),
    };

    /// <summary>Un filtro cuyo valor no es lo que se lee (un id, un código).</summary>
    private static FiltroReporte Filtro(string clave, string titulo, IEnumerable<(string Valor, string Texto)> opciones) => new()
    {
        Clave = clave,
        Titulo = titulo,
        Opciones = opciones.DistinctBy(o => o.Valor).OrderBy(o => o.Texto, Orden)
            .Select(o => new OpcionReporte { Valor = o.Valor, Texto = o.Texto }).ToList(),
    };

    private static Dictionary<string, object?> Fila(string clave, params (string Clave, object? Valor)[] valores)
    {
        var fila = new Dictionary<string, object?> { ["clave"] = clave };
        foreach (var (k, v) in valores) fila[k] = v;
        return fila;
    }

    private static decimal R2(decimal valor) => Math.Round(valor, 2);

    private static decimal? Pct(decimal numerador, decimal denominador) =>
        denominador != 0 ? Math.Round(numerador / denominador * 100, 1) : null;

    private static ResumenReporte Resumen(string titulo, decimal valor, string tipo = TipoDato.Moneda, string tono = "neutral", string? nota = null) =>
        new() { Titulo = titulo, Valor = tipo == TipoDato.Moneda ? R2(valor) : valor, Tipo = tipo, Tono = tono, Nota = nota };

    /// <summary>"Lunes", del día de calle.</summary>
    private static string DiaSemana(DateTime dia)
    {
        var texto = dia.ToString("dddd", Peru);
        return char.ToUpper(texto[0], Peru) + texto[1..];
    }

    /// <summary>
    /// Lo que se hace igual en todos: la búsqueda (sobre las columnas de texto y su apoyo), los
    /// totales de las columnas que suman y los cocientes, y lo filtrado dicho con palabras.
    /// </summary>
    private static void Terminar(ReporteResponse reporte, ReporteRequest request)
    {
        if (!string.IsNullOrWhiteSpace(request.Buscar))
        {
            var buscar = request.Buscar.Trim();
            var claves = reporte.Columnas
                .Where(c => c.Tipo == TipoDato.Texto)
                .SelectMany(c => new[] { c.Clave, c.Apoyo })
                .OfType<string>()
                .ToList();

            reporte.Filas = reporte.Filas
                .Where(f => claves.Any(k => f.TryGetValue(k, out var v) && v is string s
                                            && s.Contains(buscar, StringComparison.OrdinalIgnoreCase)))
                .ToList();
        }

        decimal Suma(string clave) => reporte.Filas
            .Sum(f => f.TryGetValue(clave, out var v) && v is not null and not string and not DateTime ? Convert.ToDecimal(v, Peru) : 0m);

        var totales = new Dictionary<string, object?>();
        foreach (var c in reporte.Columnas.Where(c => c.Suma))
            totales[c.Clave] = c.Tipo == TipoDato.Entero ? (object)(int)Suma(c.Clave) : R2(Suma(c.Clave));
        foreach (var c in reporte.Columnas.Where(c => c.Numerador is not null && c.Denominador is not null))
            totales[c.Clave] = Pct(Suma(c.Numerador!), Suma(c.Denominador!));
        reporte.Totales = totales;

        var partes = reporte.Filtros
            .Select(f => request.Filtro(f.Clave) is string valor
                ? $"{f.Titulo.ToLower(Peru)} {f.Opciones.FirstOrDefault(o => o.Valor == valor)?.Texto ?? valor}"
                : null)
            .Append(string.IsNullOrWhiteSpace(request.Buscar) ? null : $"búsqueda «{request.Buscar.Trim()}»")
            .OfType<string>()
            .ToList();
        reporte.Filtrado = partes.Count == 0 ? null : string.Join(" · ", partes);
    }
}
