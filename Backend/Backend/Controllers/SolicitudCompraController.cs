using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Lo que el almacén pide que se compre. De una solicitud sale la orden de compra (en OrdenCompra, con
/// <c>solicitudCompraId</c>); esta pantalla no maneja costos ni proveedores.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SolicitudCompraController : ControllerBase
{
    private readonly ISolicitudCompraService _solicitudes;

    public SolicitudCompraController(ISolicitudCompraService solicitudes)
    {
        _solicitudes = solicitudes;
    }

    /// <summary>Quién la pide, tomado del token.</summary>
    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [Permiso("compras.solicitudes", Accion.Ver)]
    public async Task<IActionResult> GetAll([FromQuery] string? estado) => Ok(await _solicitudes.GetAllAsync(estado));

    [HttpGet("{id:int}")]
    [Permiso("compras.solicitudes", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _solicitudes.GetAsync(id));

    /// <summary>Los productos del almacén que están bajo su mínimo, con una cantidad sugerida.</summary>
    [HttpGet("sugerencias")]
    [Permiso("compras.solicitudes", Accion.Crear)]
    public async Task<IActionResult> Sugerencias([FromQuery] int almacenId) =>
        Ok(await _solicitudes.SugerenciasAsync(almacenId));

    [HttpPost]
    [Permiso("compras.solicitudes", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CrearSolicitudCompraRequest request)
    {
        var creada = await _solicitudes.CrearAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = creada.Id }, creada);
    }

    [HttpPut("{id:int}")]
    [Permiso("compras.solicitudes", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] CrearSolicitudCompraRequest request) =>
        Ok(await _solicitudes.ActualizarAsync(id, request));

    /// <summary>Del borrador al administrador: la solicitud pasa a Pendiente y Compras la ve.</summary>
    [HttpPost("{id:int}/enviar")]
    [Permiso("compras.solicitudes", Accion.Crear)]
    public async Task<IActionResult> Enviar(int id) => Ok(await _solicitudes.EnviarAsync(id));

    /// <summary>Quien la pidió la retira: solo mientras es borrador o está Pendiente.</summary>
    [HttpDelete("{id:int}")]
    [Permiso("compras.solicitudes", Accion.Anular)]
    public async Task<IActionResult> Anular(int id)
    {
        await _solicitudes.AnularAsync(id);
        return NoContent();
    }

    /// <summary>Compras no la atiende y dice por qué. Es de quien atiende (Confirmar), no de quien pide.</summary>
    [HttpPost("{id:int}/rechazar")]
    [Permiso("compras.solicitudes", Accion.Confirmar)]
    public async Task<IActionResult> Rechazar(int id, [FromBody] RechazarSolicitudCompraRequest request) =>
        Ok(await _solicitudes.RechazarAsync(id, request));
}
