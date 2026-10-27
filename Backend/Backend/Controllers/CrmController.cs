using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// CRM: qué clientes están dejando de comprar. Solo lectura. El alcance de quien pregunta (solo sus
/// clientes, por ejemplo) se aplica dentro del servicio.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CrmController : ControllerBase
{
    private readonly ICrmService _crm;
    private readonly ICrmProductosService _productos;
    private readonly ICrmAgendaService _agenda;

    public CrmController(ICrmService crm, ICrmProductosService productos, ICrmAgendaService agenda)
    {
        _crm = crm;
        _productos = productos;
        _agenda = agenda;
    }

    /// <summary>
    /// La agenda: las próximas acciones de seguimiento que siguen abiertas, las vencidas primero.
    /// Sin parámetros, las mías.
    /// </summary>
    [HttpGet("tareas")]
    [Permiso("crm.seguimiento", Accion.Ver)]
    public async Task<IActionResult> Tareas([FromQuery] string? quien, [FromQuery] string? estado) =>
        Ok(await _agenda.TareasAsync(quien, estado));

    /// <summary>Mercados o rutas (agrupar), con cómo les va a sus clientes frente al periodo anterior.</summary>
    [HttpGet("zonas")]
    [Permiso("crm.zonas", Accion.Ver)]
    public async Task<IActionResult> Zonas([FromQuery] string? periodo, [FromQuery] string? agrupar) =>
        Ok(await _crm.ZonasAsync(periodo, agrupar));

    /// <summary>Productos activos sin ventas en los últimos días, con su stock.</summary>
    [HttpGet("productos")]
    [Permiso("crm.productos", Accion.Ver)]
    public async Task<IActionResult> ProductosSinVentas(
        [FromQuery] int dias = 30,
        [FromQuery] int? mercadoId = null,
        [FromQuery] int? rutaId = null,
        [FromQuery] int? categoriaId = null,
        [FromQuery] string? stock = null) =>
        Ok(await _productos.SinVentasAsync(dias, mercadoId, rutaId, categoriaId, stock));

    /// <summary>La cartera con su caída frente al periodo anterior (semana, mes o anio).</summary>
    [HttpGet("cartera")]
    [Permiso("crm.cartera", Accion.Ver)]
    public async Task<IActionResult> Cartera(
        [FromQuery] string? periodo,
        [FromQuery] int? mercadoId,
        [FromQuery] int? rutaId,
        [FromQuery] int? vendedorId,
        [FromQuery] string? nivel,
        [FromQuery] string? buscar) =>
        Ok(await _crm.CarteraAsync(periodo, mercadoId, rutaId, vendedorId, nivel, buscar));

    [HttpGet("clientes/{id:int}")]
    [Permiso("crm.cartera", Accion.Ver)]
    public async Task<IActionResult> Ficha(int id, [FromQuery] string? periodo) =>
        Ok(await _crm.FichaAsync(id, periodo));

    [HttpGet("clientes/{id:int}/gestiones")]
    [Permiso("crm.seguimiento", Accion.Ver)]
    public async Task<IActionResult> Gestiones(int id) => Ok(await _crm.GestionesAsync(id));

    [HttpPost("clientes/{id:int}/gestiones")]
    [Permiso("crm.seguimiento", Accion.Crear)]
    public async Task<IActionResult> RegistrarGestion(int id, [FromBody] CrearGestionRequest request) =>
        Ok(await _crm.RegistrarGestionAsync(id, request));

    /// <summary>Dar por hecha la próxima acción de una gestión, o volver a abrirla.</summary>
    [HttpPatch("gestiones/{id:int}/cumplida")]
    [Permiso("crm.seguimiento", Accion.Editar)]
    public async Task<IActionResult> Cumplir(int id, [FromBody] CumplirGestionRequest request) =>
        Ok(await _crm.CumplirGestionAsync(id, request));

    [HttpDelete("gestiones/{id:int}")]
    [Permiso("crm.seguimiento", Accion.Eliminar)]
    public async Task<IActionResult> EliminarGestion(int id)
    {
        await _crm.EliminarGestionAsync(id);
        return NoContent();
    }
}
