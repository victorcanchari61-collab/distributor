using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>El reparto del día: qué pedidos van en qué camión.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DespachoController : ControllerBase
{
    private readonly IDespachoService _despachos;

    public DespachoController(IDespachoService despachos)
    {
        _despachos = despachos;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [Permiso("tms.despachos", Accion.Ver)]
    public async Task<IActionResult> GetAll([FromQuery] string? estado) =>
        Ok(await _despachos.GetAllAsync(estado));

    [HttpGet("resumen")]
    [Permiso("tms.despachos", Accion.Ver)]
    public async Task<IActionResult> Resumen() => Ok(await _despachos.GetResumenAsync());

    [HttpGet("{id:int}")]
    [Permiso("tms.despachos", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _despachos.GetAsync(id));

    /// <summary>Los pedidos que se pueden cargar en esa ruta.</summary>
    [HttpGet("disponibles")]
    [Permiso("tms.despachos", Accion.Ver)]
    public async Task<IActionResult> Disponibles([FromQuery] int rutaId, [FromQuery] int? despachoId) =>
        Ok(await _despachos.PedidosDisponiblesAsync(rutaId, despachoId));

    [HttpPost]
    [Permiso("tms.despachos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] DespachoRequest request)
    {
        var creado = await _despachos.CrearAsync(request, UsuarioId);
        return CreatedAtAction(nameof(GetById), new { id = creado.Id }, creado);
    }

    [HttpPut("{id:int}")]
    [Permiso("tms.despachos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] DespachoRequest request) =>
        Ok(await _despachos.ActualizarAsync(id, request));

    [HttpPatch("{id:int}/anular")]
    [Permiso("tms.despachos", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _despachos.AnularAsync(id));
}
