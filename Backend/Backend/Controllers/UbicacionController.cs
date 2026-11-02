using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Los lugares dentro de un almacén (pisos, pasillos, estantes, posiciones) y qué producto está en cada uno.
/// Usa los permisos de Almacenes: quien puede crear almacenes arma su estructura.
/// </summary>
[ApiController]
[Route("api")]
[Authorize]
public class UbicacionController : ControllerBase
{
    private readonly IUbicacionService _ubicaciones;

    public UbicacionController(IUbicacionService ubicaciones)
    {
        _ubicaciones = ubicaciones;
    }

    [HttpGet("almacen/{almacenId:int}/ubicaciones")]
    [Permiso("inv.almacenes", Accion.Ver)]
    public async Task<IActionResult> Listar(int almacenId) => Ok(await _ubicaciones.ListarAsync(almacenId));

    [HttpPost("almacen/{almacenId:int}/ubicaciones")]
    [Permiso("inv.almacenes", Accion.Crear)]
    public async Task<IActionResult> Crear(int almacenId, [FromBody] CrearUbicacionRequest request) =>
        Ok(await _ubicaciones.CrearAsync(almacenId, request));

    /// <summary>Crea varios lugares seguidos: los estantes E01 a E20 de un pasillo.</summary>
    [HttpPost("almacen/{almacenId:int}/ubicaciones/lote")]
    [Permiso("inv.almacenes", Accion.Crear)]
    public async Task<IActionResult> Generar(int almacenId, [FromBody] GenerarUbicacionesRequest request) =>
        Ok(await _ubicaciones.GenerarAsync(almacenId, request));

    [HttpPut("ubicacion/{id:int}")]
    [Permiso("inv.almacenes", Accion.Editar)]
    public async Task<IActionResult> Actualizar(int id, [FromBody] ActualizarUbicacionRequest request) =>
        Ok(await _ubicaciones.ActualizarAsync(id, request));

    [HttpDelete("ubicacion/{id:int}")]
    [Permiso("inv.almacenes", Accion.Eliminar)]
    public async Task<IActionResult> Eliminar(int id)
    {
        await _ubicaciones.EliminarAsync(id);
        return NoContent();
    }

    [HttpGet("ubicacion/{id:int}/productos")]
    [Permiso("inv.almacenes", Accion.Ver)]
    public async Task<IActionResult> Productos(int id) => Ok(await _ubicaciones.ProductosAsync(id));

    [HttpPost("ubicacion/{id:int}/productos")]
    [Permiso("inv.almacenes", Accion.Editar)]
    public async Task<IActionResult> Asignar(int id, [FromBody] AsignarProductoUbicacionRequest request) =>
        Ok(await _ubicaciones.AsignarProductoAsync(id, request));

    [HttpDelete("ubicacion/{id:int}/productos/{productoId:int}")]
    [Permiso("inv.almacenes", Accion.Editar)]
    public async Task<IActionResult> Quitar(int id, int productoId) =>
        Ok(await _ubicaciones.QuitarProductoAsync(id, productoId));
}
