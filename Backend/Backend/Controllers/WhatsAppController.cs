using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// El servicio de WhatsApp de la empresa (whatsapp-service/): si está vinculado y, si no, el QR para vincularlo con
/// el celular de la empresa. Se maneja desde Configuración > Empresa, así que pide los permisos de esa pantalla.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class WhatsAppController : ControllerBase
{
    private readonly IWhatsAppComprobanteService _whatsapp;

    public WhatsAppController(IWhatsAppComprobanteService whatsapp)
    {
        _whatsapp = whatsapp;
    }

    [HttpGet("estado")]
    [Permiso("config.empresa", Accion.Ver)]
    public async Task<IActionResult> Estado() => Ok(await _whatsapp.EstadoAsync());

    /// <summary>Cierra la sesión vinculada y pide un QR nuevo, para cambiar de celular.</summary>
    [HttpPost("desvincular")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> Desvincular()
    {
        var ok = await _whatsapp.DesvincularAsync();
        return ok
            ? Ok(new { mensaje = "Sesión cerrada. Escanea el QR nuevo con el celular de la empresa." })
            : StatusCode(StatusCodes.Status502BadGateway, new
            {
                statusCode = 502,
                message = "No se pudo desvincular: revisa que el servicio de WhatsApp esté corriendo.",
            });
    }
}
