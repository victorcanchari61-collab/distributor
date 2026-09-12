using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>A quién toca visitar cada día.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class VisitaController : ControllerBase
{
    private readonly IVisitaService _visitas;

    public VisitaController(IVisitaService visitas)
    {
        _visitas = visitas;
    }

    /// <summary>
    /// Sin rango, hoy: es lo que se mira el 99% de las veces.
    ///
    /// Y con solo <c>desde</c>, ese día suelto — así el filtro de fechas de la
    /// tabla sirve igual para un día que para una semana.
    /// </summary>
    [HttpGet]
    [Permiso("dms.visitas", Accion.Ver)]
    public async Task<IActionResult> DelRango(
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta,
        [FromQuery] int? rutaId,
        [FromQuery] int? vendedorId)
    {
        var inicio = desde ?? DateTime.Today;
        return Ok(await _visitas.DelRangoAsync(inicio, hasta ?? inicio, rutaId, vendedorId));
    }

    [HttpGet("resumen")]
    [Permiso("dms.visitas", Accion.Ver)]
    public async Task<IActionResult> Resumen(
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta,
        [FromQuery] int? rutaId,
        [FromQuery] int? vendedorId)
    {
        var inicio = desde ?? DateTime.Today;
        return Ok(await _visitas.ResumenAsync(inicio, hasta ?? inicio, rutaId, vendedorId));
    }

    /// <summary>Los días válidos, para que la pantalla no tenga su propia copia.</summary>
    [HttpGet("dias")]
    public IActionResult Dias() => Ok(DiaSemana.Todos);
}
