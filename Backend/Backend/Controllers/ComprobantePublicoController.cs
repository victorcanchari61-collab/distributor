using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;

namespace Backend.Controllers;

/// <summary>
/// El enlace que se manda por WhatsApp. Al abrirlo el navegador BAJA el PDF y ahí termina: no hay página, ni visor,
/// ni nada que quede cargando. Por eso la respuesta es una descarga (<c>Content-Disposition: attachment</c>) y no un
/// PDF para ver en el navegador.
///
/// Es público —el cliente no tiene cuenta—, así que no se identifica por el número del comprobante (se adivina:
/// serie y correlativo son de dominio público) sino por un token aleatorio de 32 caracteres. Solo se sirven los
/// comprobantes que SUNAT aceptó.
/// </summary>
[ApiController]
[AllowAnonymous]
[Route("api/publico/comprobante")]
public class ComprobantePublicoController : ControllerBase
{
    /// <summary>
    /// Cuánto se guarda el PDF ya hecho. Generarlo es lo caro; un enlace que se abre varias veces (el cliente que
    /// vuelve a bajarlo, la vista previa que WhatsApp pide al recibir el mensaje) no debe volver a armarlo cada vez.
    /// </summary>
    private static readonly TimeSpan Vigencia = TimeSpan.FromMinutes(15);

    private readonly IComprobanteElectronicoService _comprobantes;
    private readonly IPdfService _pdf;
    private readonly IMemoryCache _cache;

    public ComprobantePublicoController(IComprobanteElectronicoService comprobantes, IPdfService pdf, IMemoryCache cache)
    {
        _comprobantes = comprobantes;
        _pdf = pdf;
        _cache = cache;
    }

    /// <summary>Baja el PDF. <c>?formato=ticket</c> para el de 80 mm; sin nada, A4.</summary>
    [HttpGet("{token}")]
    public async Task<IActionResult> Descargar(string token, [FromQuery] string? formato)
    {
        // Los tokens son hexadecimales de 32: cualquier otra cosa ni se busca en la base.
        if (token.Length != 32 || !token.All(Uri.IsHexDigit)) return NotFound();

        var ticket = string.Equals(formato, "ticket", StringComparison.OrdinalIgnoreCase);
        var clave = $"cpe-pdf:{token}:{(ticket ? "t" : "a")}";

        if (!_cache.TryGetValue(clave, out (byte[] Contenido, string Nombre) pdf))
        {
            if (await _comprobantes.IdPorTokenAsync(token) is not int id) return NotFound();

            pdf = await _pdf.ComprobanteAsync(id, ticket ? FormatoPdf.Ticket : FormatoPdf.A4);
            _cache.Set(clave, pdf, Vigencia);
        }

        // Quien tiene el enlace baja el archivo; que ningún buscador o intermediario lo indexe ni lo guarde.
        Response.Headers.CacheControl = "private, no-store";
        Response.Headers["X-Robots-Tag"] = "noindex, nofollow";
        Response.Headers["X-Content-Type-Options"] = "nosniff";

        // Con nombre de archivo, File() responde "attachment": el navegador descarga en vez de abrir.
        return File(pdf.Contenido, "application/pdf", pdf.Nombre);
    }
}
