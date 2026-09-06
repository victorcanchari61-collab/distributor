using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/listaprecio")]
[Authorize]
public class ListaPrecioController : ControllerBase
{
    private readonly IListaPrecioService _listaService;

    public ListaPrecioController(IListaPrecioService listaService)
    {
        _listaService = listaService;
    }

    [HttpGet]
    [Permiso("fact.precios", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _listaService.GetAllAsync());

    [HttpGet("{id:int}")]
    [Permiso("fact.precios", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _listaService.GetByIdAsync(id));

    [HttpPost]
    [Permiso("fact.precios", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateListaPrecioRequest request)
    {
        var response = await _listaService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("fact.precios", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateListaPrecioRequest request) =>
        Ok(await _listaService.UpdateAsync(id, request));

    /// <summary>La lista que se aplica al cliente que no tiene una propia.</summary>
    [HttpPatch("{id:int}/predeterminada")]
    [Permiso("fact.precios", Accion.Editar)]
    public async Task<IActionResult> Predeterminada(int id) =>
        Ok(await _listaService.MarcarPredeterminadaAsync(id));

    [HttpDelete("{id:int}")]
    [Permiso("fact.precios", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _listaService.DeleteAsync(id);
        return NoContent();
    }

    // --- Precios ---

    [HttpGet("{id:int}/precios")]
    [Permiso("fact.precios", Accion.Ver)]
    public async Task<IActionResult> GetPrecios(int id) =>
        Ok(await _listaService.GetPreciosAsync(id));

    /// <summary>
    /// Carga o actualiza precios. Repetir presentacion y cantidad minima
    /// actualiza el precio existente en vez de duplicarlo.
    /// </summary>
    [HttpPut("{id:int}/precios")]
    [Permiso("fact.precios", Accion.Editar)]
    public async Task<IActionResult> GuardarPrecios(
        int id, [FromBody] GuardarPreciosRequest request) =>
        Ok(await _listaService.GuardarPreciosAsync(id, request));

    [HttpDelete("precios/{precioId:int}")]
    [Permiso("fact.precios", Accion.Eliminar)]
    public async Task<IActionResult> EliminarPrecio(int precioId)
    {
        await _listaService.EliminarPrecioAsync(precioId);
        return NoContent();
    }

    /// <summary>
    /// Precio que corresponde a una cantidad, aplicando el escalon por
    /// volumen: 12 sacos toman el precio "desde 10".
    /// </summary>
    [HttpGet("{id:int}/resolver")]
    [Permiso("fact.precios", Accion.Ver)]
    public async Task<IActionResult> Resolver(
        int id, [FromQuery] int presentacionId, [FromQuery] decimal cantidad = 1m)
    {
        var precio = await _listaService.ResolverPrecioAsync(id, presentacionId, cantidad);
        return precio is null ? NotFound() : Ok(precio);
    }
}
