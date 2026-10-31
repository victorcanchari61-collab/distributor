using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class EmpresaController : ControllerBase
{
    private readonly IEmpresaService _empresaService;
    private readonly ISerieCpeService _series;

    public EmpresaController(IEmpresaService empresaService, ISerieCpeService series)
    {
        _empresaService = empresaService;
        _series = series;
    }

    [HttpGet]
    [Permiso("config.empresa", Accion.Ver)]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _empresaService.GetAllAsync());
    }

    /// <summary>Empresa con la que opera el sistema.</summary>
    [HttpGet("activa")]
    [Permiso("config.empresa", Accion.Ver)]
    public async Task<IActionResult> GetActiva()
    {
        return Ok(await _empresaService.GetActivaAsync());
    }

    [HttpGet("{id:int}")]
    [Permiso("config.empresa", Accion.Ver)]
    public async Task<IActionResult> GetById(int id)
    {
        return Ok(await _empresaService.GetByIdAsync(id));
    }

    [HttpPost]
    [Permiso("config.empresa", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateEmpresaRequest request)
    {
        var response = await _empresaService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateEmpresaRequest request)
    {
        return Ok(await _empresaService.UpdateAsync(id, request));
    }

    /// <summary>Activa una empresa y desactiva la que lo estuviera.</summary>
    [HttpPatch("{id:int}/activar")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> Activar(int id)
    {
        return Ok(await _empresaService.ActivarAsync(id));
    }

    /// <summary>Sube el certificado digital (.pem) de la empresa a la API de facturación.</summary>
    [HttpPost("{id:int}/certificado")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> SubirCertificado(int id, [FromBody] SubirCertificadoRequest request)
    {
        return Ok(await _empresaService.SubirCertificadoAsync(id, request.Certificado));
    }

    // ---------------------------------------------------------- Series de comprobantes

    /// <summary>Las series de factura, boleta y notas de la empresa, con su último número.</summary>
    [HttpGet("{id:int}/series")]
    [Permiso("config.empresa", Accion.Ver)]
    public async Task<IActionResult> Series(int id) => Ok(await _series.ListarAsync(id));

    [HttpPost("{id:int}/series")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> CrearSerie(int id, [FromBody] GuardarSerieRequest request) =>
        Ok(await _series.CrearAsync(id, request));

    [HttpPut("{id:int}/series/{serieId:int}")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> ActualizarSerie(int id, int serieId, [FromBody] GuardarSerieRequest request) =>
        Ok(await _series.ActualizarAsync(id, serieId, request));

    [HttpDelete("{id:int}/series/{serieId:int}")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> EliminarSerie(int id, int serieId)
    {
        await _series.EliminarAsync(id, serieId);
        return NoContent();
    }

    /// <summary>Crea F001, B001 y las series de notas que le falten a la empresa.</summary>
    [HttpPost("{id:int}/series/estandar")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> CrearSeriesEstandar(int id) => Ok(await _series.CrearEstandarAsync(id));

    /// <summary>Retira una empresa sin eliminarla.</summary>
    [HttpPatch("{id:int}/deshabilitar")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> Deshabilitar(int id)
    {
        return Ok(await _empresaService.CambiarHabilitacionAsync(id, false));
    }

    /// <summary>Vuelve a poner disponible una empresa retirada.</summary>
    [HttpPatch("{id:int}/habilitar")]
    [Permiso("config.empresa", Accion.Editar)]
    public async Task<IActionResult> Habilitar(int id)
    {
        return Ok(await _empresaService.CambiarHabilitacionAsync(id, true));
    }

    [HttpDelete("{id:int}")]
    [Permiso("config.empresa", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _empresaService.DeleteAsync(id);
        return NoContent();
    }
}
