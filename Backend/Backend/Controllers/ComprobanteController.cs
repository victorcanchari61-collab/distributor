using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Comprobantes electrónicos: factura, boleta y notas de crédito y débito. Se emiten desde una nota de venta (o
/// sobre otro comprobante), se firman, se mandan a SUNAT y se pueden descargar su XML y su CDR.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ComprobanteController : ControllerBase
{
    private readonly IComprobanteElectronicoService _comprobantes;

    public ComprobanteController(IComprobanteElectronicoService comprobantes)
    {
        _comprobantes = comprobantes;
    }

    [HttpGet]
    [Permiso("fact.comprobantes", Accion.Ver)]
    public async Task<IActionResult> Listar(
        [FromQuery] string? tipo,
        [FromQuery] string? estado,
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta,
        [FromQuery] int? notaVentaId,
        [FromQuery] int? afectadoId) =>
        Ok(await _comprobantes.ListarAsync(tipo, estado, desde, hasta, notaVentaId, afectadoId));

    [HttpGet("{id:int}")]
    [Permiso("fact.comprobantes", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _comprobantes.GetAsync(id));

    [HttpGet("series")]
    [Permiso("fact.comprobantes", Accion.Ver)]
    public async Task<IActionResult> Series() => Ok(await _comprobantes.SeriesAsync());

    /// <summary>Factura o boleta de una nota de venta.</summary>
    [HttpPost("emitir")]
    [Permiso("fact.comprobantes", Accion.Crear)]
    public async Task<IActionResult> Emitir([FromBody] EmitirComprobanteRequest request) =>
        Ok(await _comprobantes.EmitirAsync(request));

    /// <summary>Nota de crédito o débito sobre un comprobante aceptado.</summary>
    [HttpPost("{id:int}/nota")]
    [Permiso("fact.comprobantes", Accion.Crear)]
    public async Task<IActionResult> EmitirNota(int id, [FromBody] EmitirNotaRequest request) =>
        Ok(await _comprobantes.EmitirNotaAsync(id, request));

    /// <summary>Reenvía a SUNAT un comprobante que quedó sin respuesta.</summary>
    [HttpPost("{id:int}/reenviar")]
    [Permiso("fact.comprobantes", Accion.Crear)]
    public async Task<IActionResult> Reenviar(int id) => Ok(await _comprobantes.ReenviarAsync(id));

    /// <summary>El XML firmado.</summary>
    [HttpGet("{id:int}/xml")]
    [Permiso("fact.comprobantes", Accion.Exportar)]
    public async Task<IActionResult> Xml(int id)
    {
        var (contenido, nombre) = await _comprobantes.DescargarXmlAsync(id);
        return File(contenido, "application/xml", nombre);
    }

    /// <summary>La constancia de recepción (CDR) de SUNAT, en zip.</summary>
    [HttpGet("{id:int}/cdr")]
    [Permiso("fact.comprobantes", Accion.Exportar)]
    public async Task<IActionResult> Cdr(int id)
    {
        var (contenido, nombre) = await _comprobantes.DescargarCdrAsync(id);
        return File(contenido, "application/zip", nombre);
    }
}
