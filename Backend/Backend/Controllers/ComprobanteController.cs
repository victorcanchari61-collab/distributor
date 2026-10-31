using Backend.Dtos.Requests;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Comprobantes electrónicos: factura, boleta y notas de crédito y débito. Se emiten desde una nota de venta (o
/// sobre otro comprobante), se firman, se mandan a SUNAT y se pueden descargar su XML y su CDR.
///
/// Cada tipo tiene su propio submódulo de permisos (fact.facturas, fact.boletas, fact.notascredito,
/// fact.notasdebito): el permiso que se pide depende del tipo del comprobante, así que se revisa aquí y no con un
/// atributo fijo.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ComprobanteController : ControllerBase
{
    private readonly IComprobanteElectronicoService _comprobantes;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;

    public ComprobanteController(
        IComprobanteElectronicoService comprobantes, IPermisoService permisos, IUsuarioActual usuarioActual)
    {
        _comprobantes = comprobantes;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
    }

    /// <summary>
    /// Los comprobantes que el usuario puede ver. Con <c>tipo</c> se pide ese permiso; sin él, se devuelven los
    /// tipos que sí puede ver (así una venta muestra su factura a quien no ve notas de crédito).
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Listar(
        [FromQuery] string? tipo,
        [FromQuery] string? estado,
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta,
        [FromQuery] int? notaVentaId,
        [FromQuery] int? afectadoId)
    {
        List<string> tipos;
        if (!string.IsNullOrWhiteSpace(tipo))
        {
            if (!TipoCpe.Todos.Contains(tipo)) return TipoInvalido();
            if (await Denegado(tipo, Accion.Ver) is { } denegado) return denegado;
            tipos = [tipo];
        }
        else
        {
            tipos = [];
            foreach (var t in TipoCpe.Todos)
                if (await Puede(t, Accion.Ver)) tipos.Add(t);
            if (tipos.Count == 0) return Prohibido(TipoCpe.Factura, Accion.Ver);
        }

        return Ok(await _comprobantes.ListarAsync(tipos, estado, desde, hasta, notaVentaId, afectadoId));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        if (await Denegado(await _comprobantes.TipoAsync(id), Accion.Ver) is { } denegado) return denegado;
        return Ok(await _comprobantes.GetAsync(id));
    }

    /// <summary>Factura o boleta de una nota de venta.</summary>
    [HttpPost("emitir")]
    public async Task<IActionResult> Emitir([FromBody] EmitirComprobanteRequest request)
    {
        if (!TipoCpe.Todos.Contains(request.Tipo)) return TipoInvalido();
        if (await Denegado(request.Tipo, Accion.Crear) is { } denegado) return denegado;
        return Ok(await _comprobantes.EmitirAsync(request));
    }

    /// <summary>Nota de crédito o débito sobre un comprobante aceptado.</summary>
    [HttpPost("{id:int}/nota")]
    public async Task<IActionResult> EmitirNota(int id, [FromBody] EmitirNotaRequest request)
    {
        if (!TipoCpe.Todos.Contains(request.Tipo)) return TipoInvalido();
        if (await Denegado(request.Tipo, Accion.Crear) is { } denegado) return denegado;
        return Ok(await _comprobantes.EmitirNotaAsync(id, request));
    }

    /// <summary>Reenvía a SUNAT un comprobante que quedó sin respuesta.</summary>
    [HttpPost("{id:int}/reenviar")]
    public async Task<IActionResult> Reenviar(int id)
    {
        if (await Denegado(await _comprobantes.TipoAsync(id), Accion.Crear) is { } denegado) return denegado;
        return Ok(await _comprobantes.ReenviarAsync(id));
    }

    /// <summary>El XML firmado.</summary>
    [HttpGet("{id:int}/xml")]
    public async Task<IActionResult> Xml(int id)
    {
        if (await Denegado(await _comprobantes.TipoAsync(id), Accion.Exportar) is { } denegado) return denegado;
        var (contenido, nombre) = await _comprobantes.DescargarXmlAsync(id);
        return File(contenido, "application/xml", nombre);
    }

    /// <summary>La constancia de recepción (CDR) de SUNAT, en zip.</summary>
    [HttpGet("{id:int}/cdr")]
    public async Task<IActionResult> Cdr(int id)
    {
        if (await Denegado(await _comprobantes.TipoAsync(id), Accion.Exportar) is { } denegado) return denegado;
        var (contenido, nombre) = await _comprobantes.DescargarCdrAsync(id);
        return File(contenido, "application/zip", nombre);
    }

    // ------------------------------------------------------------------ Permisos

    private async Task<bool> Puede(string tipo, string accion) =>
        _usuarioActual.Id is int usuarioId && await _permisos.PuedeAsync(usuarioId, TipoCpe.Submodulo(tipo), accion);

    /// <summary>Nulo si puede; si no, el 403 con el permiso exacto, para que el front ofrezca solicitarlo.</summary>
    private async Task<IActionResult?> Denegado(string tipo, string accion) =>
        await Puede(tipo, accion) ? null : Prohibido(tipo, accion);

    private ObjectResult Prohibido(string tipo, string accion) =>
        StatusCode(StatusCodes.Status403Forbidden, new
        {
            statusCode = StatusCodes.Status403Forbidden,
            message = "No tienes permiso para esta acción.",
            submodulo = TipoCpe.Submodulo(tipo),
            accion,
        });

    private ObjectResult TipoInvalido() =>
        StatusCode(StatusCodes.Status400BadRequest, new { statusCode = 400, message = "Tipo de comprobante no válido" });
}
