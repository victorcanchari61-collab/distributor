using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Préstamos recibidos por el negocio.</summary>
[ApiController]
[Route("api/financiamiento")]
[Authorize]
public class FinanciamientoController : ControllerBase
{
    private readonly IFinanciamientoService _financiamientos;

    public FinanciamientoController(IFinanciamientoService financiamientos)
    {
        _financiamientos = financiamientos;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet]
    [Permiso("finanzas.financiamiento", Accion.Ver)]
    public async Task<IActionResult> Listar() => Ok(await _financiamientos.ListarAsync());

    [HttpGet("{id:int}")]
    [Permiso("finanzas.financiamiento", Accion.Ver)]
    public async Task<IActionResult> Get(int id) => Ok(await _financiamientos.GetAsync(id));

    [HttpGet("cuentas")]
    [Permiso("finanzas.financiamiento", Accion.Ver)]
    public async Task<IActionResult> Cuentas() => Ok(await _financiamientos.CuentasAsync());

    [HttpPost]
    [Permiso("finanzas.financiamiento", Accion.Crear)]
    public async Task<IActionResult> Crear([FromBody] CrearFinanciamientoRequest request) =>
        Ok(await _financiamientos.CrearAsync(request, UsuarioId));

    [HttpPost("{id:int}/pagos")]
    [Permiso("finanzas.financiamiento", Accion.Crear)]
    public async Task<IActionResult> RegistrarPago(int id, [FromBody] PagoFinanciamientoRequest request) =>
        Ok(await _financiamientos.RegistrarPagoAsync(id, request, UsuarioId));

    [HttpPatch("{id:int}/pagos/{pagoId:int}/anular")]
    [Permiso("finanzas.financiamiento", Accion.Anular)]
    public async Task<IActionResult> AnularPago(int id, int pagoId) =>
        Ok(await _financiamientos.AnularPagoAsync(id, pagoId, UsuarioId));

    [HttpPatch("{id:int}/anular")]
    [Permiso("finanzas.financiamiento", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _financiamientos.AnularAsync(id, UsuarioId));
}
