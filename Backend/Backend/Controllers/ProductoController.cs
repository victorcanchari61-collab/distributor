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
public class ProductoController : ControllerBase
{
    private readonly IProductoService _productoService;

    public ProductoController(IProductoService productoService)
    {
        _productoService = productoService;
    }

    [HttpGet]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _productoService.GetAllAsync());

    /// <summary>Una página del catálogo, con búsqueda, filtros y orden en la base.</summary>
    [HttpPost("listar")]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _productoService.ListarAsync(consulta));

    /// <summary>Contadores y valores de filtro del catálogo completo.</summary>
    [HttpGet("resumen")]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> Resumen() => Ok(await _productoService.GetResumenAsync());

    [HttpGet("{id:int}")]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) =>
        Ok(await _productoService.GetByIdAsync(id));

    [HttpPost]
    [Permiso("maestros.productos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateProductoRequest request)
    {
        var response = await _productoService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("maestros.productos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateProductoRequest request) =>
        Ok(await _productoService.UpdateAsync(id, request));

    /// <summary>Alta masiva desde un catálogo de un sistema externo.</summary>
    [HttpPost("importar")]
    [Permiso("maestros.productos", Accion.Importar)]
    public async Task<IActionResult> Importar([FromBody] ImportarProductosRequest request) =>
        Ok(await _productoService.ImportarAsync(request));

    [HttpPatch("{id:int}/activar")]
    [Permiso("maestros.productos", Accion.Editar)]
    public async Task<IActionResult> Activar(int id) =>
        Ok(await _productoService.CambiarEstadoAsync(id, true));

    [HttpPatch("{id:int}/desactivar")]
    [Permiso("maestros.productos", Accion.Editar)]
    public async Task<IActionResult> Desactivar(int id) =>
        Ok(await _productoService.CambiarEstadoAsync(id, false));

    [HttpDelete("{id:int}")]
    [Permiso("maestros.productos", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _productoService.DeleteAsync(id);
        return NoContent();
    }

    // --- Presentaciones ---

    /// <summary>Agrega una forma de comprar o vender: saco de 50, caja x12.</summary>
    [HttpPost("{id:int}/presentaciones")]
    [Permiso("maestros.productos", Accion.Crear)]
    public async Task<IActionResult> AgregarPresentacion(
        int id, [FromBody] PresentacionRequest request) =>
        Ok(await _productoService.AgregarPresentacionAsync(id, request));

    [HttpPut("presentaciones/{presentacionId:int}")]
    [Permiso("maestros.productos", Accion.Editar)]
    public async Task<IActionResult> ActualizarPresentacion(
        int presentacionId, [FromBody] PresentacionRequest request) =>
        Ok(await _productoService.ActualizarPresentacionAsync(presentacionId, request));

    [HttpDelete("presentaciones/{presentacionId:int}")]
    [Permiso("maestros.productos", Accion.Eliminar)]
    public async Task<IActionResult> EliminarPresentacion(int presentacionId)
    {
        await _productoService.EliminarPresentacionAsync(presentacionId);
        return NoContent();
    }

    /// <summary>
    /// Cuanta unidad base mueve una cantidad en cierta presentacion. Deja
    /// comprobar la conversion sin registrar nada: 2 sacos de 50 -> 100 kg.
    /// </summary>
    [HttpGet("presentaciones/{presentacionId:int}/convertir")]
    [Permiso("maestros.productos", Accion.Ver)]
    public async Task<IActionResult> Convertir(
        int presentacionId, [FromQuery] decimal cantidad = 1m)
    {
        var enBase = await _productoService.AUnidadBaseAsync(presentacionId, cantidad);
        return Ok(new { presentacionId, cantidad, unidadBase = enBase });
    }
}
