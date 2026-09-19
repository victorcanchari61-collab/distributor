using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Por qué no se entregó algo: los motivos que crea el dueño.</summary>
[ApiController]
[Route("api/motivonovedad")]
[Authorize]
public class MotivoNovedadController : ControllerBase
{
    private readonly INovedadService _novedades;

    public MotivoNovedadController(INovedadService novedades)
    {
        _novedades = novedades;
    }

    [HttpGet]
    [Permiso("tms.motivos", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _novedades.GetMotivosAsync());

    /// <summary>
    /// Los activos, para elegir uno al entregar un pedido.
    ///
    /// Los pide quien convierte pedidos en venta, que no tiene por qué ver el
    /// catálogo entero ni poder editarlo.
    /// </summary>
    [HttpGet("opciones")]
    [PermisoAlguno("fact.pedidos:confirmar", "tms.motivos:ver")]
    public async Task<IActionResult> Opciones() => Ok(await _novedades.GetOpcionesAsync());

    [HttpPost]
    [Permiso("tms.motivos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] MotivoNovedadRequest request) =>
        Ok(await _novedades.CrearMotivoAsync(request));

    [HttpPut("{id:int}")]
    [Permiso("tms.motivos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] MotivoNovedadRequest request) =>
        Ok(await _novedades.ActualizarMotivoAsync(id, request));
}
