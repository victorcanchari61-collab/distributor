using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// El plano de cada piso de un almacén: dónde está dibujado cada lugar, y sus pasillos y escaleras.
/// Los lugares y los productos se leen y se mueven con los endpoints de <see cref="UbicacionController"/>.
/// </summary>
[ApiController]
[Route("api")]
[Authorize]
public class PlanoController : ControllerBase
{
    private readonly IPlanoService _plano;

    public PlanoController(IPlanoService plano)
    {
        _plano = plano;
    }

    /// <summary>
    /// El tamaño de la cuadrícula y los pasillos y escaleras. Lo lee también quien recibe mercadería: elige en el
    /// plano dónde guardarla.
    /// </summary>
    [HttpGet("almacen/{almacenId:int}/plano")]
    [PermisoAlguno("inv.plano:ver", "inv.almacenes:ver", "inv.ubicaciones:ver", "compras.recepciones:crear")]
    public async Task<IActionResult> Obtener(int almacenId) => Ok(await _plano.ObtenerAsync(almacenId));

    [HttpPut("ubicacion/{id:int}/plano")]
    [Permiso("inv.plano", Accion.Editar)]
    public async Task<IActionResult> Posicionar(int id, [FromBody] PosicionPlanoRequest request) =>
        Ok(await _plano.PosicionarLugarAsync(id, request));

    [HttpPost("almacen/{almacenId:int}/plano/elementos")]
    [Permiso("inv.plano", Accion.Editar)]
    public async Task<IActionResult> CrearElemento(int almacenId, [FromBody] ElementoPlanoRequest request) =>
        Ok(await _plano.CrearElementoAsync(almacenId, request));

    [HttpPut("plano/elementos/{id:int}")]
    [Permiso("inv.plano", Accion.Editar)]
    public async Task<IActionResult> ActualizarElemento(int id, [FromBody] ElementoPlanoRequest request) =>
        Ok(await _plano.ActualizarElementoAsync(id, request));

    [HttpDelete("plano/elementos/{id:int}")]
    [Permiso("inv.plano", Accion.Editar)]
    public async Task<IActionResult> EliminarElemento(int id)
    {
        await _plano.EliminarElementoAsync(id);
        return NoContent();
    }
}
