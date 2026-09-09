using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Tipos de vehículo: el catálogo del que salen los vehículos.</summary>
[ApiController]
[Route("api/tipovehiculo")]
[Authorize]
public class TipoVehiculoController : ControllerBase
{
    private readonly IFlotaService _flota;

    public TipoVehiculoController(IFlotaService flota)
    {
        _flota = flota;
    }

    [HttpGet]
    [Permiso("tms.flota", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _flota.GetTiposAsync());

    [HttpGet("{id:int}")]
    [Permiso("tms.flota", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _flota.GetTipoAsync(id));

    [HttpPost]
    [Permiso("tms.flota", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] TipoVehiculoRequest request)
    {
        var response = await _flota.CrearTipoAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("tms.flota", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] TipoVehiculoRequest request) =>
        Ok(await _flota.ActualizarTipoAsync(id, request));

}

/// <summary>Los vehículos de reparto.</summary>
[ApiController]
[Route("api/vehiculo")]
[Authorize]
public class VehiculoController : ControllerBase
{
    private readonly IFlotaService _flota;

    public VehiculoController(IFlotaService flota)
    {
        _flota = flota;
    }

    [HttpGet]
    [Permiso("tms.flota", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _flota.GetVehiculosAsync());

    [HttpGet("resumen")]
    [Permiso("tms.flota", Accion.Ver)]
    public async Task<IActionResult> Resumen() => Ok(await _flota.ResumenFlotaAsync());

    [HttpGet("{id:int}")]
    [Permiso("tms.flota", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _flota.GetVehiculoAsync(id));

    [HttpPost]
    [Permiso("tms.flota", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] VehiculoRequest request)
    {
        var response = await _flota.CrearVehiculoAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("tms.flota", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] VehiculoRequest request) =>
        Ok(await _flota.ActualizarVehiculoAsync(id, request));

}

/// <summary>Quienes conducen.</summary>
[ApiController]
[Route("api/conductor")]
[Authorize]
public class ConductorController : ControllerBase
{
    private readonly IFlotaService _flota;

    public ConductorController(IFlotaService flota)
    {
        _flota = flota;
    }

    [HttpGet]
    [Permiso("tms.conductores", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _flota.GetConductoresAsync());

    [HttpGet("resumen")]
    [Permiso("tms.conductores", Accion.Ver)]
    public async Task<IActionResult> Resumen() => Ok(await _flota.ResumenConductoresAsync());

    [HttpGet("{id:int}")]
    [Permiso("tms.conductores", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _flota.GetConductorAsync(id));

    [HttpPost]
    [Permiso("tms.conductores", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] ConductorRequest request)
    {
        var response = await _flota.CrearConductorAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("tms.conductores", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] ConductorRequest request) =>
        Ok(await _flota.ActualizarConductorAsync(id, request));

}
