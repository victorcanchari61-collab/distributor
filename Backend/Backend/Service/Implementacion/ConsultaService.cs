using System.Text.Json;
using System.Text.RegularExpressions;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// Consulta RUC y DNI contra apisperu.
///
/// La llamada se hace desde el backend a proposito: el token es una credencial
/// y desde el navegador quedaria a la vista de cualquiera en el bundle. El
/// frontend solo ve /api/consulta/..., ya autenticado con el JWT del sistema.
/// </summary>
public partial class ConsultaService : IConsultaService
{
    private readonly HttpClient _http;
    private readonly string _token;
    private readonly ILogger<ConsultaService> _logger;

    public ConsultaService(HttpClient http, IConfiguration configuration,
        ILogger<ConsultaService> logger)
    {
        _http = http;
        _logger = logger;
        _token = configuration["ApisPeru:Token"] ?? string.Empty;

        var baseUrl = configuration["ApisPeru:BaseUrl"] ?? "https://dniruc.apisperu.com/api/v1/";
        _http.BaseAddress = new Uri(baseUrl);
        _http.Timeout = TimeSpan.FromSeconds(15);
    }

    public async Task<ConsultaRucResponse> ConsultarRucAsync(string ruc)
    {
        if (!SoloDigitos(11).IsMatch(ruc))
        {
            throw new BadRequestException("El RUC debe tener 11 dígitos");
        }

        using var doc = await ConsultarAsync($"ruc/{ruc}", "RUC");

        var raiz = doc.RootElement;
        return new ConsultaRucResponse
        {
            Ruc = Texto(raiz, "ruc") ?? ruc,
            RazonSocial = Texto(raiz, "razonSocial") ?? string.Empty,
            NombreComercial = Texto(raiz, "nombreComercial"),
            Direccion = Texto(raiz, "direccion"),
            Departamento = Capitalizar(Texto(raiz, "departamento")),
            Provincia = Capitalizar(Texto(raiz, "provincia")),
            Distrito = Capitalizar(Texto(raiz, "distrito")),
            Estado = Texto(raiz, "estado"),
            Condicion = Texto(raiz, "condicion")
        };
    }

    public async Task<ConsultaDniResponse> ConsultarDniAsync(string dni)
    {
        if (!SoloDigitos(8).IsMatch(dni))
        {
            throw new BadRequestException("El DNI debe tener 8 dígitos");
        }

        using var doc = await ConsultarAsync($"dni/{dni}", "DNI");

        var raiz = doc.RootElement;
        var nombres = Texto(raiz, "nombres") ?? string.Empty;
        var paterno = Texto(raiz, "apellidoPaterno") ?? string.Empty;
        var materno = Texto(raiz, "apellidoMaterno") ?? string.Empty;

        return new ConsultaDniResponse
        {
            Dni = Texto(raiz, "dni") ?? dni,
            Nombres = nombres,
            ApellidoPaterno = paterno,
            ApellidoMaterno = materno,
            NombreCompleto = string.Join(' ',
                new[] { nombres, paterno, materno }.Where(p => !string.IsNullOrWhiteSpace(p)))
        };
    }

    /// <summary>
    /// Llama al proveedor y devuelve el JSON ya validado. Ojo: cuando no
    /// encuentra el documento responde 200 con {"success": false}, asi que no
    /// basta con mirar el codigo HTTP.
    /// </summary>
    private async Task<JsonDocument> ConsultarAsync(string ruta, string tipo)
    {
        if (string.IsNullOrWhiteSpace(_token))
        {
            throw new AppException(StatusCodes.Status503ServiceUnavailable,
                "La consulta en línea no está configurada");
        }

        HttpResponseMessage respuesta;
        try
        {
            respuesta = await _http.GetAsync($"{ruta}?token={_token}");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "No se pudo contactar al servicio de consulta de {Tipo}", tipo);
            throw new AppException(StatusCodes.Status503ServiceUnavailable,
                $"No pudimos consultar el {tipo} en línea. Inténtalo de nuevo o ingresa los datos a mano");
        }

        var cuerpo = await respuesta.Content.ReadAsStringAsync();

        if (!respuesta.IsSuccessStatusCode)
        {
            _logger.LogWarning("Consulta de {Tipo} respondió {Codigo}: {Cuerpo}",
                tipo, (int)respuesta.StatusCode, cuerpo);

            throw new AppException(StatusCodes.Status503ServiceUnavailable,
                $"El servicio de consulta de {tipo} no está disponible");
        }

        var doc = JsonDocument.Parse(cuerpo);

        if (doc.RootElement.TryGetProperty("success", out var exito) &&
            exito.ValueKind == JsonValueKind.False)
        {
            doc.Dispose();
            throw new NotFoundException($"No encontramos ningún {tipo} con ese número");
        }

        return doc;
    }

    private static string? Texto(JsonElement elemento, string propiedad)
    {
        if (!elemento.TryGetProperty(propiedad, out var valor)) return null;
        if (valor.ValueKind != JsonValueKind.String) return null;

        var texto = valor.GetString();
        return string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();
    }

    /// <summary>SUNAT devuelve todo en mayusculas: "LIMA" queda como "Lima".</summary>
    private static string? Capitalizar(string? texto)
    {
        if (string.IsNullOrWhiteSpace(texto)) return texto;

        return string.Join(' ', texto.Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Select(palabra => palabra.Length == 1
                ? palabra.ToUpperInvariant()
                : char.ToUpperInvariant(palabra[0]) + palabra[1..].ToLowerInvariant()));
    }

    private static Regex SoloDigitos(int largo) => new($"^[0-9]{{{largo}}}$");
}
