using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CategoriaController : ControllerBase
{
    private readonly ICatalogoService _catalogo;

    public CategoriaController(ICatalogoService catalogo)
    {
        _catalogo = catalogo;
    }

    [HttpGet]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _catalogo.GetCategoriasAsync());

    [HttpGet("{id:int}")]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _catalogo.GetCategoriaAsync(id));

    [HttpPost]
    [Permiso("maestros.productos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateCategoriaRequest request)
    {
        var response = await _catalogo.CreateCategoriaAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("maestros.productos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateCategoriaRequest request) =>
        Ok(await _catalogo.UpdateCategoriaAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("maestros.productos", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _catalogo.DeleteCategoriaAsync(id);
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MarcaController : ControllerBase
{
    private readonly ICatalogoService _catalogo;

    public MarcaController(ICatalogoService catalogo)
    {
        _catalogo = catalogo;
    }

    [HttpGet]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _catalogo.GetMarcasAsync());

    [HttpGet("{id:int}")]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _catalogo.GetMarcaAsync(id));

    [HttpPost]
    [Permiso("maestros.productos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateMarcaRequest request)
    {
        var response = await _catalogo.CreateMarcaAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("maestros.productos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateMarcaRequest request) =>
        Ok(await _catalogo.UpdateMarcaAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("maestros.productos", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _catalogo.DeleteMarcaAsync(id);
        return NoContent();
    }
}

[ApiController]
[Route("api/unidad")]
[Authorize]
public class UnidadMedidaController : ControllerBase
{
    private readonly ICatalogoService _catalogo;

    public UnidadMedidaController(ICatalogoService catalogo)
    {
        _catalogo = catalogo;
    }

    [HttpGet]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _catalogo.GetUnidadesAsync());

    [HttpGet("{id:int}")]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _catalogo.GetUnidadAsync(id));

    [HttpPost]
    [Permiso("maestros.productos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateUnidadMedidaRequest request)
    {
        var response = await _catalogo.CreateUnidadAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("maestros.productos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateUnidadMedidaRequest request) =>
        Ok(await _catalogo.UpdateUnidadAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("maestros.productos", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _catalogo.DeleteUnidadAsync(id);
        return NoContent();
    }
}
