using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Backend.Exceptions;
using Microsoft.Extensions.Options;

namespace Backend.Service.Implementacion;

/// <summary>
/// Lo que se configura de la facturación electrónica en appsettings (sección "Facturacion"). Lo que es de cada
/// empresa —RUC, usuario y clave SOL, ubigeo, modo pruebas o producción— vive en la empresa (Configuración > Empresas).
/// </summary>
public class FacturacionOpciones
{
    /// <summary>La API que firma los XML y los manda a SUNAT: http://host/api/v1/</summary>
    public string ApiUrl { get; set; } = string.Empty;

    /// <summary>Plazo de una venta a crédito, en días: SUNAT pide la fecha de cada cuota.</summary>
    public int DiasCredito { get; set; } = 30;
}

/// <summary>Un XML firmado, listo para guardar y enviar.</summary>
public record XmlGenerado(string NombreArchivo, string Hash, string QrInfo, string Xml);

/// <summary>Lo que dice la API del certificado que se le mandó a revisar.</summary>
public record CertificadoGuardado(string Mensaje, string? Titular, DateTime? VigenteHasta, bool Vencido, List<string> Advertencias);

/// <summary>Lo que SUNAT respondió a un envío.</summary>
public class RespuestaSunat
{
    /// <summary>Hubo respuesta de SUNAT (CDR). Si no, el envío falló antes: se puede reintentar.</summary>
    public bool Recibida { get; set; }

    public bool Aceptado { get; set; }
    public string? Codigo { get; set; }
    public string? Mensaje { get; set; }
    public List<string> Notas { get; set; } = [];
    public byte[]? CdrZip { get; set; }
}

/// <summary>Lo que respondió SUNAT a una comunicación de baja (o a la consulta de su ticket).</summary>
public class RespuestaBaja
{
    public bool Aceptada { get; set; }

    /// <summary>SUNAT todavía la procesa: se consulta de nuevo con el ticket.</summary>
    public bool Pendiente { get; set; }

    public string? Ticket { get; set; }
    public string? Codigo { get; set; }
    public string? Mensaje { get; set; }
    public byte[]? CdrZip { get; set; }
}

/// <summary>La API de facturación electrónica (api-factu): genera y firma el XML, y lo envía a SUNAT.</summary>
public interface IFactuClient
{
    Task<XmlGenerado> GenerarComprobanteAsync(object cuerpo);
    Task<XmlGenerado> GenerarNotaAsync(object cuerpo);
    /// <summary>Le pide a la API que revise el certificado .pem (clave, vigencia, de quién es). La API no lo guarda.</summary>
    Task<CertificadoGuardado> ValidarCertificadoAsync(string ruc, string pem);

    Task<RespuestaSunat> EnviarAsync(string entorno, string ruc, string usuarioSol, string claveSol, string nombreArchivo, string xml);

    /// <summary>Firma y envía una comunicación de baja; la API espera a SUNAT unos segundos y, si no alcanza, devuelve el ticket.</summary>
    Task<RespuestaBaja> EnviarBajaAsync(object cuerpo);

    /// <summary>Consulta en SUNAT cómo va una baja con su ticket.</summary>
    Task<RespuestaBaja> ConsultarTicketAsync(string entorno, string ruc, string usuarioSol, string claveSol, string ticket);
}

public class FactuClient : IFactuClient
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = null };

    private readonly HttpClient _http;
    private readonly FacturacionOpciones _opciones;
    private readonly ILogger<FactuClient> _logger;

    public FactuClient(HttpClient http, IOptions<FacturacionOpciones> opciones, ILogger<FactuClient> logger)
    {
        _http = http;
        _opciones = opciones.Value;
        _logger = logger;

        if (!string.IsNullOrWhiteSpace(_opciones.ApiUrl))
            _http.BaseAddress = new Uri(_opciones.ApiUrl.TrimEnd('/') + "/");
        // Firmar es rápido; enviar a SUNAT puede tardar. Un corte a los 60 s deja el comprobante en "Generado" y se
        // reintenta, que es mejor que dejar la petición colgada.
        // Una baja espera a SUNAT hasta unos 40 segundos más: por eso el margen.
        _http.Timeout = TimeSpan.FromSeconds(100);
    }

    public Task<XmlGenerado> GenerarComprobanteAsync(object cuerpo) => GenerarAsync("generar/comprobante", cuerpo);

    public Task<XmlGenerado> GenerarNotaAsync(object cuerpo) => GenerarAsync("generar/nota", cuerpo);

    private async Task<XmlGenerado> GenerarAsync(string ruta, object cuerpo)
    {
        using var raiz = await PostAsync(ruta, cuerpo);
        var r = raiz.RootElement;

        if (!Verdadero(r, "estado") || !r.TryGetProperty("data", out var data))
            throw new BadRequestException($"La API de facturación no pudo generar el comprobante: {Detalle(r)}");

        return new XmlGenerado(
            Texto(data, "nombre_archivo") ?? string.Empty,
            Texto(data, "hash") ?? string.Empty,
            Texto(data, "qr_info") ?? string.Empty,
            Texto(data, "contenido_xml") ?? string.Empty);
    }

    public async Task<CertificadoGuardado> ValidarCertificadoAsync(string ruc, string pem)
    {
        using var raiz = await PostAsync("validar/certificado", new { certificado = pem, ruc });
        var r = raiz.RootElement;

        if (!Verdadero(r, "estado"))
            throw new BadRequestException(Texto(r, "mensaje") ?? "La API de facturación no aceptó el certificado");

        string? titular = null;
        DateTime? hasta = null;
        var vencido = false;
        var advertencias = new List<string>();

        if (r.TryGetProperty("data", out var data) && data.ValueKind == JsonValueKind.Object)
        {
            if (data.TryGetProperty("certificado", out var cert) && cert.ValueKind == JsonValueKind.Object)
            {
                titular = Texto(cert, "titular");
                if (DateTime.TryParse(Texto(cert, "vigente_hasta"), out var v)) hasta = v.Date;
                vencido = Verdadero(cert, "vencido");
            }

            if (data.TryGetProperty("advertencias", out var adv) && adv.ValueKind == JsonValueKind.Array)
                advertencias = adv.EnumerateArray().Select(a => a.ToString()).Where(a => a.Length > 0).ToList();
        }

        return new CertificadoGuardado(Texto(r, "mensaje") ?? "Certificado válido.", titular, hasta, vencido, advertencias);
    }

    public async Task<RespuestaSunat> EnviarAsync(
        string entorno, string ruc, string usuarioSol, string claveSol, string nombreArchivo, string xml)
    {
        var cuerpo = new
        {
            endpoint = entorno,
            ruc,
            usuario = usuarioSol,
            clave = claveSol,
            nombre_documento = nombreArchivo,
            contenido_documento = xml,
        };

        using var raiz = await PostAsync("enviar/documento/electronico", cuerpo);
        var r = raiz.RootElement;

        var respuesta = new RespuestaSunat
        {
            Aceptado = Verdadero(r, "estado") && !(r.TryGetProperty("aceptado", out var a) && a.ValueKind == JsonValueKind.False),
            Codigo = Texto(r, "codigo_cdr"),
            Mensaje = Texto(r, "mensaje"),
        };

        if (r.TryGetProperty("notas", out var notas) && notas.ValueKind == JsonValueKind.Array)
            respuesta.Notas = notas.EnumerateArray().Select(n => n.ToString()).Where(n => n.Length > 0).ToList();

        // Con CDR hubo respuesta de SUNAT (aceptó o rechazó). Sin CDR, el envío no llegó a una decisión.
        var cdr = Texto(r, "cdr");
        if (!string.IsNullOrEmpty(cdr))
        {
            respuesta.Recibida = true;
            respuesta.CdrZip = Convert.FromBase64String(cdr);
        }

        return respuesta;
    }

    public async Task<RespuestaBaja> EnviarBajaAsync(object cuerpo)
    {
        using var raiz = await PostAsync("enviar/comunicacion/baja", cuerpo);
        return LeerBaja(raiz.RootElement);
    }

    public async Task<RespuestaBaja> ConsultarTicketAsync(string entorno, string ruc, string usuarioSol, string claveSol, string ticket)
    {
        using var raiz = await PostAsync(
            $"consulta/documento/ticker-see/{Uri.EscapeDataString(ticket)}",
            new { endpoint = entorno, ruc, usuario = usuarioSol, clave = claveSol });
        var r = raiz.RootElement;
        var baja = LeerBaja(r);
        baja.Ticket ??= ticket;
        return baja;
    }

    /// <summary>
    /// Las dos respuestas (enviar y consultar) se parecen: aceptada, pendiente (SUNAT sigue procesando, código 0098) o
    /// rechazada. Una baja que SUNAT no acepta no deja el comprobante dado de baja.
    /// </summary>
    private static RespuestaBaja LeerBaja(JsonElement r)
    {
        var mensaje = Texto(r, "mensaje");
        var respuesta = new RespuestaBaja
        {
            Ticket = Texto(r, "ticket"),
            Codigo = Texto(r, "codigo_cdr"),
            Mensaje = mensaje,
        };

        var cdr = Texto(r, "cdr");
        if (!string.IsNullOrEmpty(cdr)) respuesta.CdrZip = Convert.FromBase64String(cdr);

        var aceptadoCampo = !r.TryGetProperty("aceptado", out var a) || a.ValueKind != JsonValueKind.False;
        if (Verdadero(r, "estado") && aceptadoCampo && (respuesta.Codigo is null or "0"))
        {
            respuesta.Aceptada = true;
            return respuesta;
        }

        // Sigue en proceso: lo dice el flag de la API o el código 0098 de SUNAT en el mensaje.
        respuesta.Pendiente = Verdadero(r, "pendiente")
            || (mensaje?.Contains("0098") ?? false)
            || (mensaje?.Contains("todavía está procesando", StringComparison.OrdinalIgnoreCase) ?? false);
        return respuesta;
    }

    /// <summary>Manda el JSON y devuelve la respuesta. Un corte de red o un error 5xx no es una respuesta: se avisa.</summary>
    private async Task<JsonDocument> PostAsync(string ruta, object cuerpo)
    {
        HttpResponseMessage respuesta;
        try
        {
            respuesta = await _http.PostAsJsonAsync(ruta, cuerpo, Json);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
        {
            _logger.LogWarning(e, "No se pudo llamar a la API de facturación ({Ruta})", ruta);
            throw new AppException(StatusCodes.Status502BadGateway,
                "No pudimos comunicarnos con la API de facturación. Intenta de nuevo en un momento.");
        }

        using (respuesta)
        {
            var texto = await respuesta.Content.ReadAsStringAsync();
            try
            {
                return JsonDocument.Parse(texto);
            }
            catch (JsonException)
            {
                _logger.LogWarning("La API de facturación respondió {Estado} sin JSON en {Ruta}", (int)respuesta.StatusCode, ruta);
                throw new AppException(StatusCodes.Status502BadGateway,
                    $"La API de facturación respondió con un error ({(int)respuesta.StatusCode}).");
            }
        }
    }

    /// <summary>El motivo de un rechazo de la API: su mensaje y, si lo hay, cada dato que no pasó la validación.</summary>
    private static string Detalle(JsonElement r)
    {
        var mensaje = Texto(r, "mensaje") ?? "sin detalle";
        if (!r.TryGetProperty("errores", out var errores) || errores.ValueKind != JsonValueKind.Object) return mensaje;

        var campos = errores.EnumerateObject()
            .Select(e => $"{e.Name}: {string.Join(" ", e.Value.EnumerateArray().Select(m => m.ToString()))}");
        return $"{mensaje} {string.Join("; ", campos)}";
    }

    private static bool Verdadero(JsonElement e, string nombre) =>
        e.TryGetProperty(nombre, out var v) && v.ValueKind == JsonValueKind.True;

    private static string? Texto(JsonElement e, string nombre) =>
        e.TryGetProperty(nombre, out var v) && v.ValueKind != JsonValueKind.Null ? v.ToString() : null;
}
