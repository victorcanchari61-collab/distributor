using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Categoría de los clientes: Socio, Distribuidor, Mayorista... según lo que compraron en el ciclo
/// anterior. Ver la configuración y el resultado pide Ver; cambiar los tramos o calcular, Editar.
/// </summary>
[ApiController]
[Route("api/crm/categorizacion")]
[Authorize]
public class CategorizacionController : ControllerBase
{
    private readonly ICategorizacionService _categorizacion;

    public CategorizacionController(ICategorizacionService categorizacion)
    {
        _categorizacion = categorizacion;
    }

    /// <summary>
    /// Las categorías y sus tramos. Las ve también quien ve los clientes (el vendedor, por ejemplo): la columna
    /// "Categoría" del padrón no sirve si nadie puede saber qué significa cada letra. Ajustarlas o calcular es
    /// solo de quien tiene Editar.
    /// </summary>
    [HttpGet]
    [PermisoAlguno("crm.categorizacion:ver", "maestros.clientes:ver")]
    public async Task<IActionResult> Obtener() => Ok(await _categorizacion.ObtenerAsync());

    [HttpPut]
    [Permiso("crm.categorizacion", Accion.Editar)]
    public async Task<IActionResult> Guardar([FromBody] GuardarCategorizacionRequest request) =>
        Ok(await _categorizacion.GuardarAsync(request));

    /// <summary>Calcula ya la categoría de todos los clientes con lo guardado.</summary>
    [HttpPost("calcular")]
    [Permiso("crm.categorizacion", Accion.Editar)]
    public async Task<IActionResult> Calcular() => Ok(await _categorizacion.CalcularAsync());

    [HttpGet("clientes")]
    [Permiso("crm.categorizacion", Accion.Ver)]
    public async Task<IActionResult> Clientes() => Ok(await _categorizacion.ClientesAsync());
}
