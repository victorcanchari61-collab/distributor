using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// La bandeja de cotizaciones que mandan los clientes desde el portal. Atenderlas es crear el pedido jalándolas
/// (POST /api/pedido con cotizacionId); aquí solo se ven y se descartan.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CotizacionController : ControllerBase
{
    private readonly ICotizacionService _service;

    public CotizacionController(ICotizacionService service)
    {
        _service = service;
    }

    /// <summary>
    /// Las cotizaciones, de la más nueva a la más vieja. Las usa también el "Jalar cotización" del formulario de
    /// pedido: quien crea pedidos las puede ver aunque no tenga la bandeja en su menú.
    /// </summary>
    [HttpGet]
    [PermisoAlguno("fact.cotizaciones:ver", "fact.pedidos:crear")]
    public async Task<IActionResult> GetAll([FromQuery] string? estado = null, [FromQuery] int? clienteId = null) =>
        Ok(await _service.GetAllAsync(estado, clienteId));

    [HttpGet("{id:int}")]
    [PermisoAlguno("fact.cotizaciones:ver", "fact.pedidos:crear")]
    public async Task<IActionResult> GetById(int id) => Ok(await _service.GetAsync(id));

    [HttpPatch("{id:int}/descartar")]
    [Permiso("fact.cotizaciones", Accion.Anular)]
    public async Task<IActionResult> Descartar(int id, [FromBody] DescartarCotizacionRequest request) =>
        Ok(await _service.DescartarAsync(id, request));
}
