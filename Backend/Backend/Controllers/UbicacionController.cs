using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Los lugares dentro de un almacén (pisos y cuartos) y qué producto está en cada uno.
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

    /// <summary>
    /// Los lugares del almacén. Los lee también quien recibe mercadería o transfiere y tiene que elegir dónde guardarla,
    /// sin necesitar la pantalla de Almacenes.
    /// </summary>
    [HttpGet("almacen/{almacenId:int}/ubicaciones")]
    [PermisoAlguno(
        "inv.almacenes:ver", "inv.ubicaciones:ver", "inv.stock:ver",
        "compras.recepciones:crear", "inv.transferencias:crear")]
    public async Task<IActionResult> Listar(int almacenId) => Ok(await _ubicaciones.ListarAsync(almacenId));

    [HttpPost("almacen/{almacenId:int}/ubicaciones")]
    [Permiso("inv.almacenes", Accion.Crear)]
    public async Task<IActionResult> Crear(int almacenId, [FromBody] CrearUbicacionRequest request) =>
        Ok(await _ubicaciones.CrearAsync(almacenId, request));

    /// <summary>Crea varios lugares seguidos: los cuartos C1 a C8 de un piso.</summary>
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

    // ------------------------------------------------------------- Ubicación de productos (pantalla propia)

    /// <summary>Los productos del almacén con el lugar donde está cada uno. La lista de trabajo de "Ubicación de productos".
    /// También la lee quien recibe o transfiere, para sugerir el lugar habitual de cada producto.
    /// </summary>
    [HttpGet("ubicacion-producto")]
    [PermisoAlguno("inv.ubicaciones:ver", "compras.recepciones:crear", "inv.transferencias:crear")]
    public async Task<IActionResult> ProductosDelAlmacen([FromQuery] int almacenId) =>
        Ok(await _ubicaciones.ProductosDelAlmacenAsync(almacenId));

    /// <summary>Pone varios productos en un lugar, o los mueve con <c>reemplazar</c>.</summary>
    [HttpPost("ubicacion-producto/asignar")]
    [Permiso("inv.ubicaciones", Accion.Editar)]
    public async Task<IActionResult> AsignarVarios([FromBody] AsignarProductosUbicacionRequest request) =>
        Ok(await _ubicaciones.AsignarVariosAsync(request));

    [HttpPost("ubicacion-producto/quitar")]
    [Permiso("inv.ubicaciones", Accion.Editar)]
    public async Task<IActionResult> QuitarVarios([FromBody] QuitarProductosUbicacionRequest request) =>
        Ok(await _ubicaciones.QuitarVariosAsync(request));

    [HttpDelete("ubicacion/{id:int}/productos/{productoId:int}")]
    [Permiso("inv.almacenes", Accion.Editar)]
    public async Task<IActionResult> Quitar(int id, int productoId) =>
        Ok(await _ubicaciones.QuitarProductoAsync(id, productoId));
}
