using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// CRM: Gestión y seguimiento de clientes y los reportes de quién compra menos (clientes con caída, clientes
/// inactivos, vendedores con caída). El alcance de quien pregunta (solo sus clientes, por ejemplo) se aplica dentro
/// de los servicios.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CrmController : ControllerBase
{
    private readonly ISeguimientoClienteService _seguimiento;
    private readonly ICaidaService _caida;

    public CrmController(ISeguimientoClienteService seguimiento, ICaidaService caida)
    {
        _seguimiento = seguimiento;
        _caida = caida;
    }

    // ------------------------------------------------------------- Gestión y seguimiento

    [HttpGet("seguimiento/catalogo")]
    [Permiso("crm.seguimiento", Accion.Ver)]
    public IActionResult Catalogo() => Ok(_seguimiento.Catalogo());

    /// <summary>Clientes que coinciden con lo escrito (nombre, documento o código).</summary>
    [HttpGet("seguimiento/clientes")]
    [Permiso("crm.seguimiento", Accion.Ver)]
    public async Task<IActionResult> Buscar([FromQuery] string? buscar) => Ok(await _seguimiento.BuscarAsync(buscar));

    [HttpGet("seguimiento/{id:int}/ficha")]
    [Permiso("crm.seguimiento", Accion.Ver)]
    public async Task<IActionResult> Ficha(int id, [FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _seguimiento.FichaAsync(id, desde, hasta));

    [HttpGet("seguimiento/{id:int}/gestiones")]
    [Permiso("crm.seguimiento", Accion.Ver)]
    public async Task<IActionResult> Gestiones(int id) => Ok(await _seguimiento.GestionesAsync(id));

    [HttpPost("seguimiento/{id:int}/gestiones")]
    [Permiso("crm.seguimiento", Accion.Crear)]
    public async Task<IActionResult> Registrar(int id, [FromBody] GuardarGestionRequest request) =>
        Ok(await _seguimiento.RegistrarAsync(id, request));

    [HttpPut("seguimiento/gestiones/{id:int}")]
    [Permiso("crm.seguimiento", Accion.Editar)]
    public async Task<IActionResult> Actualizar(int id, [FromBody] GuardarGestionRequest request) =>
        Ok(await _seguimiento.ActualizarAsync(id, request));

    /// <summary>Cambia el día y la hora de un contacto que sigue programado.</summary>
    [HttpPut("seguimiento/gestiones/{id:int}/reprogramar")]
    [Permiso("crm.seguimiento", Accion.Editar)]
    public async Task<IActionResult> Reprogramar(int id, [FromBody] ReprogramarGestionRequest request) =>
        Ok(await _seguimiento.ReprogramarAsync(id, request));

    [HttpGet("seguimiento/{id:int}/compras")]
    [Permiso("crm.seguimiento", Accion.Ver)]
    public async Task<IActionResult> Compras(int id, [FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _seguimiento.ComprasAsync(id, desde, hasta));

    [HttpGet("seguimiento/{id:int}/documentos")]
    [Permiso("crm.seguimiento", Accion.Ver)]
    public async Task<IActionResult> Documentos(int id) => Ok(await _seguimiento.DocumentosAsync(id));

    // ------------------------------------------------------------- Reportes

    /// <summary>
    /// Clientes con caída: lo comprado del 1 de enero a hoy (o el rango que se pida) contra el mismo tramo del año
    /// anterior, con una tarjeta por estado.
    /// </summary>
    [HttpGet("caida")]
    [Permiso("crm.caida", Accion.Ver)]
    public async Task<IActionResult> ClientesConCaida(
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta,
        [FromQuery] int? mercadoId,
        [FromQuery] int? rutaId,
        [FromQuery] int? vendedorId,
        [FromQuery] string? estado,
        [FromQuery] string? buscar) =>
        Ok(await _caida.ClientesAsync(new ConsultaCaida(desde, hasta, mercadoId, rutaId, vendedorId, estado, buscar)));

    /// <summary>De un cliente, qué productos dejó de comprar frente al mismo tramo del año anterior.</summary>
    [HttpGet("caida/{clienteId:int}/productos")]
    [Permiso("crm.caida", Accion.Ver)]
    public async Task<IActionResult> QueDejoDeComprar(int clienteId, [FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _caida.QueDejoDeComprarAsync(clienteId, desde, hasta));

    [HttpGet("inactivos")]
    [Permiso("crm.inactivos", Accion.Ver)]
    public async Task<IActionResult> ClientesInactivos(
        [FromQuery] int? mercadoId,
        [FromQuery] int? rutaId,
        [FromQuery] int? vendedorId,
        [FromQuery] string? estado,
        [FromQuery] string? buscar) =>
        Ok(await _caida.InactivosAsync(mercadoId, rutaId, vendedorId, estado, buscar));

    [HttpGet("vendedores")]
    [Permiso("crm.vendedores", Accion.Ver)]
    public async Task<IActionResult> VendedoresConCaida([FromQuery] DateTime? desde, [FromQuery] DateTime? hasta) =>
        Ok(await _caida.VendedoresAsync(desde, hasta));
}
