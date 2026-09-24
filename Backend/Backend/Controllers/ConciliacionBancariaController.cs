using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/conciliacionbancaria")]
[Authorize]
public class ConciliacionBancariaController : ControllerBase
{
    private readonly IConciliacionBancariaService _conciliaciones;

    public ConciliacionBancariaController(IConciliacionBancariaService conciliaciones)
    {
        _conciliaciones = conciliaciones;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    [HttpGet("cuenta/{cuentaFinancieraId:int}")]
    [Permiso("finanzas.bancos", Accion.Ver)]
    public async Task<IActionResult> Listar(int cuentaFinancieraId) =>
        Ok(await _conciliaciones.ListarAsync(cuentaFinancieraId));

    [HttpPost]
    [Permiso("finanzas.bancos", Accion.Crear)]
    public async Task<IActionResult> Crear([FromBody] ConciliacionBancariaRequest request) =>
        Ok(await _conciliaciones.CrearAsync(request, UsuarioId));

    [HttpPatch("{id:int}/conciliar")]
    [Permiso("finanzas.bancos", Accion.Editar)]
    public async Task<IActionResult> MarcarConciliada(int id) =>
        Ok(await _conciliaciones.MarcarConciliadaAsync(id));
}
