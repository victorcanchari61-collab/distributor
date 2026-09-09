using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Motivos de gasto de la ruta: pasaje, combustible, menú.</summary>
[ApiController]
[Route("api/motivogasto")]
[Authorize]
public class MotivoGastoController : ControllerBase
{
    private readonly IArqueoService _arqueo;

    public MotivoGastoController(IArqueoService arqueo)
    {
        _arqueo = arqueo;
    }

    [HttpGet]
    [Permiso("finanzas.arqueo", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _arqueo.GetMotivosAsync());

    [HttpPost]
    [Permiso("finanzas.arqueo", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] MotivoGastoRequest request) =>
        Ok(await _arqueo.CrearMotivoAsync(request));

    [HttpPut("{id:int}")]
    [Permiso("finanzas.arqueo", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] MotivoGastoRequest request) =>
        Ok(await _arqueo.ActualizarMotivoAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("finanzas.arqueo", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _arqueo.EliminarMotivoAsync(id);
        return NoContent();
    }
}

/// <summary>El cuadre de caja del reparto, por día y persona.</summary>
[ApiController]
[Route("api/arqueo")]
[Authorize]
public class ArqueoController : ControllerBase
{
    private readonly IArqueoService _arqueo;

    public ArqueoController(IArqueoService arqueo)
    {
        _arqueo = arqueo;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    /// <summary>
    /// Quién cobró qué entre dos fechas, una fila por día y persona.
    ///
    /// Es la lista desde la que se cuadra: aparece también quien todavía no ha
    /// cuadrado, que es a quien hay que buscar.
    /// </summary>
    [HttpGet("cuadres")]
    [Permiso("finanzas.arqueo", Accion.Ver)]
    public async Task<IActionResult> Cuadres([FromQuery] DateTime desde, [FromQuery] DateTime hasta) =>
        Ok(await _arqueo.GetCuadresAsync(desde, hasta));

    /// <summary>Todo lo necesario para cuadrar a una persona en un día.</summary>
    [HttpGet("detalle")]
    [Permiso("finanzas.arqueo", Accion.Ver)]
    public async Task<IActionResult> Detalle([FromQuery] DateTime fecha, [FromQuery] int usuarioId) =>
        Ok(await _arqueo.GetDetalleAsync(fecha, usuarioId));

    /// <summary>Lo que cada persona debe por faltantes.</summary>
    [HttpGet("deudas")]
    [Permiso("finanzas.arqueo", Accion.Ver)]
    public async Task<IActionResult> Deudas() => Ok(await _arqueo.GetDeudasAsync());

    [HttpGet("{id:int}")]
    [Permiso("finanzas.arqueo", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _arqueo.GetAsync(id));

    /// <summary>Una página del historial de cuadres, con búsqueda y filtros.</summary>
    [HttpPost("listar")]
    [Permiso("finanzas.arqueo", Accion.Ver)]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _arqueo.ListarAsync(consulta));

    /// <summary>
    /// Registra el cuadre. Vuelto a llamar sobre el mismo día y persona,
    /// corrige el anterior en vez de crear otro.
    /// </summary>
    [HttpPost]
    [Permiso("finanzas.arqueo", Accion.Crear)]
    public async Task<IActionResult> Registrar([FromBody] RegistrarArqueoRequest request) =>
        Ok(await _arqueo.RegistrarAsync(request, UsuarioId));

    [HttpPatch("{id:int}/anular")]
    [Permiso("finanzas.arqueo", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) => Ok(await _arqueo.AnularAsync(id));

    /// <summary>Marca que el faltante ya se le descontó o lo repuso.</summary>
    [HttpPatch("{id:int}/saldar")]
    [Permiso("finanzas.arqueo", Accion.Cobrar)]
    public async Task<IActionResult> Saldar(int id) => Ok(await _arqueo.SaldarFaltanteAsync(id));
}
