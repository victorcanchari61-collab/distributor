using Backend.Exceptions;
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
    /// Sin nada, hoy: es lo que se mira el 99% de las veces.
    ///
    /// Con <c>dia</c> (LUNES... DOMINGO, o SEMANA) se piden los clientes de ESE día de visita, en la semana de
    /// <c>desde</c> (o la de hoy): así se ve "los del lunes" sin tener que armar un rango de fechas. Con solo
    /// <c>desde</c>, ese día suelto; con <c>desde</c> y <c>hasta</c>, el rango.
    /// </summary>
    [HttpGet]
    [Permiso("dms.visitas", Accion.Ver)]
    public async Task<IActionResult> DelRango(
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta,
        [FromQuery] int? rutaId,
        [FromQuery] int? vendedorId,
        [FromQuery] string? dia)
    {
        var (inicio, fin) = Rango(desde, hasta, dia);
        return Ok(await _visitas.DelRangoAsync(inicio, fin, rutaId, vendedorId));
    }

    [HttpGet("resumen")]
    [Permiso("dms.visitas", Accion.Ver)]
    public async Task<IActionResult> Resumen(
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta,
        [FromQuery] int? rutaId,
        [FromQuery] int? vendedorId,
        [FromQuery] string? dia)
    {
        var (inicio, fin) = Rango(desde, hasta, dia);
        return Ok(await _visitas.ResumenAsync(inicio, fin, rutaId, vendedorId));
    }

    /// <summary>Las rutas que quien pide puede elegir: todas para el administrador, las suyas para el resto.</summary>
    [HttpGet("rutas")]
    [Permiso("dms.visitas", Accion.Ver)]
    public async Task<IActionResult> Rutas() => Ok(await _visitas.RutasAsync());

    private static (DateTime Desde, DateTime Hasta) Rango(DateTime? desde, DateTime? hasta, string? dia)
    {
        if (DiaSemana.Normalizar(dia) is string d)
        {
            if (d != DiaSemana.Semana && !DiaSemana.EsValido(d))
                throw new BadRequestException("El día de visita no es válido.");

            return DiaSemana.DeLaSemana(desde ?? DateTime.Today, d);
        }

        var inicio = desde ?? DateTime.Today;
        return (inicio, hasta ?? inicio);
    }

    /// <summary>Los días válidos, para que la pantalla no tenga su propia copia.</summary>
    [HttpGet("dias")]
    public IActionResult Dias() => Ok(DiaSemana.Todos);
}
