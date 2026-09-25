using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>El catálogo de bancos (BBVA, BCP, Interbank...): de aquí cuelgan las cuentas bancarias.</summary>
[ApiController]
[Route("api/banco")]
[Authorize]
public class BancoController : ControllerBase
{
    private readonly IBancoService _bancos;

    public BancoController(IBancoService bancos)
    {
        _bancos = bancos;
    }

    [HttpGet]
    [Permiso("finanzas.bancos", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _bancos.GetAllAsync());

    [HttpPost]
    [Permiso("finanzas.bancos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] BancoRequest request) =>
        Ok(await _bancos.CreateAsync(request));

    [HttpPut("{id:int}")]
    [Permiso("finanzas.bancos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] BancoRequest request) =>
        Ok(await _bancos.UpdateAsync(id, request));
}
