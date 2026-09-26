using Backend.Models;
using Backend.Filters;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Si el negocio gana, en un rango de fechas.</summary>
[ApiController]
[Route("api/estadoresultados")]
[Authorize]
public class EstadoResultadosController : ControllerBase
{
    private readonly IEstadoResultadosService _estado;

    public EstadoResultadosController(IEstadoResultadosService estado)
    {
        _estado = estado;
    }

    [HttpGet]
    [Permiso("finanzas.resultados", Accion.Ver)]
    public async Task<IActionResult> Calcular([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _estado.CalcularAsync(desde, hasta));
}
