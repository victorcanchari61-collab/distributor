using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/gastooperativo")]
[Authorize]
public class GastoOperativoController : ControllerBase
{
    private readonly IGastoOperativoService _gastos;
    private readonly IPermisoService _permisos;

    public GastoOperativoController(IGastoOperativoService gastos, IPermisoService permisos)
    {
        _gastos = gastos;
        _permisos = permisos;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    // --- Categorías ---

    [HttpGet("categorias")]
    [Permiso("finanzas.operativos", Accion.Ver)]
    public async Task<IActionResult> GetCategorias() => Ok(await _gastos.GetCategoriasAsync());

    /// <summary>
    /// Sin permiso de Finanzas: Mi Caja es de todos, y quien registra un gasto
    /// de su ruta necesita elegir la categoría aunque no vea el catálogo.
    /// </summary>
    [HttpGet("categorias/opciones")]
    public async Task<IActionResult> GetCategoriasOpciones([FromQuery] string? tipo) =>
        Ok(await _gastos.GetCategoriasOpcionesAsync(tipo));

    [HttpPost("categorias")]
    [Permiso("finanzas.operativos", Accion.Crear)]
    public async Task<IActionResult> CrearCategoria([FromBody] CategoriaMovimientoRequest request) =>
        Ok(await _gastos.CrearCategoriaAsync(request));

    [HttpPut("categorias/{id:int}")]
    [Permiso("finanzas.operativos", Accion.Editar)]
    public async Task<IActionResult> ActualizarCategoria(int id, [FromBody] CategoriaMovimientoRequest request) =>
        Ok(await _gastos.ActualizarCategoriaAsync(id, request));

    [HttpDelete("categorias/{id:int}")]
    [Permiso("finanzas.operativos", Accion.Eliminar)]
    public async Task<IActionResult> EliminarCategoria(int id)
    {
        await _gastos.EliminarCategoriaAsync(id);
        return NoContent();
    }

    // --- Plantillas recurrentes ---

    [HttpGet("recurrentes")]
    [Permiso("finanzas.operativos", Accion.Ver)]
    public async Task<IActionResult> GetRecurrentes() => Ok(await _gastos.GetRecurrentesAsync());

    [HttpPost("recurrentes")]
    [Permiso("finanzas.operativos", Accion.Crear)]
    public async Task<IActionResult> CrearRecurrente([FromBody] GastoRecurrenteRequest request) =>
        Ok(await _gastos.CrearRecurrenteAsync(request));

    [HttpPut("recurrentes/{id:int}")]
    [Permiso("finanzas.operativos", Accion.Editar)]
    public async Task<IActionResult> ActualizarRecurrente(int id, [FromBody] GastoRecurrenteRequest request) =>
        Ok(await _gastos.ActualizarRecurrenteAsync(id, request));

    [HttpDelete("recurrentes/{id:int}")]
    [Permiso("finanzas.operativos", Accion.Eliminar)]
    public async Task<IActionResult> EliminarRecurrente(int id)
    {
        await _gastos.EliminarRecurrenteAsync(id);
        return NoContent();
    }

    [HttpGet("pendientes")]
    [Permiso("finanzas.operativos", Accion.Ver)]
    public async Task<IActionResult> GetPendientes() => Ok(await _gastos.GetPendientesAsync());

    // --- Movimientos ---

    [HttpGet]
    [Permiso("finanzas.operativos", Accion.Ver)]
    public async Task<IActionResult> Listar([FromQuery] DateTime desde, [FromQuery] DateTime hasta) =>
        Ok(await _gastos.ListarAsync(desde, hasta));

    // Se registra desde Movimientos, que pide Ingreso o Egreso según el tipo, o desde Ingresos y
    // egresos al pagar una plantilla pendiente, que pide Crear de ese submódulo. Sin ninguno, el 403
    // dice qué pedir: el de Movimientos para ese tipo.
    [HttpPost]
    public async Task<IActionResult> Crear([FromBody] MovimientoOperativoRequest request)
    {
        if (UsuarioId is not int usuarioId) return Unauthorized();

        int? permisoUnico = null;
        if (!await _permisos.PuedeAsync(usuarioId, "finanzas.operativos", Accion.Crear))
        {
            var accion = request.Tipo == TipoMovimientoOperativo.Ingreso ? Accion.Ingreso : Accion.Egreso;
            var veredicto = await _permisos.ResolverAsync(usuarioId, "finanzas.movimientos", accion);
            if (!veredicto.Permitido)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    statusCode = StatusCodes.Status403Forbidden,
                    message = "No tienes permiso para esta acción.",
                    submodulo = "finanzas.movimientos",
                    accion,
                });
            }
            permisoUnico = veredicto.PermisoUnicoId;
        }

        var creado = await _gastos.CrearAsync(request, usuarioId);
        // Un permiso de un solo uso se gasta recién cuando el movimiento quedó registrado.
        if (permisoUnico is int id) await _permisos.ConsumirAsync(id);
        return Ok(creado);
    }

    [HttpPatch("{id:int}/anular")]
    [PermisoAlguno("finanzas.movimientos:anular", "finanzas.operativos:anular")]
    public async Task<IActionResult> Anular(int id) => Ok(await _gastos.AnularAsync(id, UsuarioId));
}
