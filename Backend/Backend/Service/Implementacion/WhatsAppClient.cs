using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace Backend.Service.Implementacion;

/// <summary>
/// Lo que se configura del envío por WhatsApp en appsettings (sección "WhatsApp"). Si el envío está activo, el
/// mensaje y la empresa se eligen en Configuración > Empresa.
/// </summary>
public class WhatsAppOpciones
{
    /// <summary>El microservicio propio (whatsapp-service/, Baileys). Corre en la misma máquina: http://127.0.0.1:3334</summary>
    public string Url { get; set; } = "http://127.0.0.1:3334";

    /// <summary>El mismo token que el WHATSAPP_TOKEN del microservicio. Vacío: no se puede enviar.</summary>
    public string Token { get; set; } = string.Empty;

    public int TimeoutSegundos { get; set; } = 10;

    /// <summary>
    /// La dirección pública del sistema, como la abre el cliente: https://sistema.titanicd.pe. Si está vacía se usa la
    /// de la petición, que detrás de un proxy sin cabeceras reenviadas puede salir como http.
    /// </summary>
    public string UrlPublica { get; set; } = string.Empty;
}

/// <summary>Cómo está el microservicio: conectado, esperando que se escanee el QR, o inalcanzable.</summary>
public record EstadoWhatsAppServicio(string Estado, int EnCola, string? Qr, string? Error);

/// <summary>El microservicio de WhatsApp. Nunca lanza: un fallo de WhatsApp no debe tumbar a quien lo llama.</summary>
public interface IWhatsAppClient
{
    /// <summary>Encola el mensaje en el microservicio (que lo manda con una pausa entre mensajes). Devuelve el error si lo hubo.</summary>
    Task<(bool Ok, string? Error)> EnviarAsync(string telefono, string mensaje);

    Task<EstadoWhatsAppServicio> EstadoAsync();

    /// <summary>Cierra la sesión vinculada y pide un QR nuevo.</summary>
    Task<bool> DesvincularAsync();
}

public class WhatsAppClient : IWhatsAppClient
{
    private readonly HttpClient _http;
    private readonly WhatsAppOpciones _opciones;
    private readonly ILogger<WhatsAppClient> _logger;

    public WhatsAppClient(HttpClient http, IOptions<WhatsAppOpciones> opciones, ILogger<WhatsAppClient> logger)
    {
        _opciones = opciones.Value;
        _logger = logger;
        _http = http;
        _http.BaseAddress = new Uri(_opciones.Url.TrimEnd('/') + "/");
        _http.Timeout = TimeSpan.FromSeconds(Math.Max(1, _opciones.TimeoutSegundos));
    }

    public async Task<(bool Ok, string? Error)> EnviarAsync(string telefono, string mensaje)
    {
        if (string.IsNullOrWhiteSpace(_opciones.Token))
            return (false, "Falta el token de WhatsApp en la configuración del servidor");

        try
        {
            using var peticion = new HttpRequestMessage(HttpMethod.Post, "enviar")
            {
                Content = JsonContent.Create(new { telefono, mensaje }),
            };
            peticion.Headers.Add("X-Token", _opciones.Token);

            using var respuesta = await _http.SendAsync(peticion);
            if (respuesta.IsSuccessStatusCode) return (true, null);

            var cuerpo = await respuesta.Content.ReadAsStringAsync();
            _logger.LogWarning("WhatsApp rechazó el mensaje ({Estado}): {Cuerpo}", (int)respuesta.StatusCode, cuerpo);
            return (false, respuesta.StatusCode == System.Net.HttpStatusCode.UnprocessableEntity
                ? "El teléfono no es válido para WhatsApp"
                : "El servicio de WhatsApp no aceptó el mensaje");
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
        {
            _logger.LogWarning(e, "No se pudo hablar con el servicio de WhatsApp");
            return (false, "No se pudo conectar con el servicio de WhatsApp");
        }
    }

    public async Task<EstadoWhatsAppServicio> EstadoAsync()
    {
        try
        {
            var estado = await _http.GetFromJsonAsync<EstadoJson>("estado");
            return new EstadoWhatsAppServicio(estado?.Estado ?? "error", estado?.EnCola ?? 0, estado?.Qr, null);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException)
        {
            return new EstadoWhatsAppServicio("sin-servicio", 0, null, "No se pudo conectar con el servicio de WhatsApp");
        }
    }

    public async Task<bool> DesvincularAsync()
    {
        if (string.IsNullOrWhiteSpace(_opciones.Token)) return false;

        try
        {
            using var peticion = new HttpRequestMessage(HttpMethod.Post, "desvincular");
            peticion.Headers.Add("X-Token", _opciones.Token);
            using var respuesta = await _http.SendAsync(peticion);
            return respuesta.IsSuccessStatusCode;
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
        {
            _logger.LogWarning(e, "No se pudo desvincular WhatsApp");
            return false;
        }
    }

    private class EstadoJson
    {
        [JsonPropertyName("estado")] public string? Estado { get; set; }
        [JsonPropertyName("en_cola")] public int EnCola { get; set; }
        [JsonPropertyName("qr")] public string? Qr { get; set; }
    }
}
