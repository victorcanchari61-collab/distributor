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
public class ClienteController : ControllerBase
{
    private readonly IClienteService _clienteService;

    public ClienteController(IClienteService clienteService)
    {
        _clienteService = clienteService;
    }

    /// <summary>
    /// Todos, sin paginar. Lo usan los buscadores de cliente de otras
    /// pantallas; el listado de Clientes usa <see cref="Listar"/>.
    /// </summary>
    [HttpGet]
    [Permiso("maestros.clientes", Accion.Ver)]
    public async Task<IActionResult> GetAll([FromQuery] string? para = null)
    {
        return Ok(await _clienteService.GetAllAsync(para));
    }

    /// <summary>
    /// Una página del listado. Va por POST y no por GET porque los filtros son
    /// una lista de objetos: armarlos en la query string obligaría a inventar
    /// una codificación propia y a mantenerla en los dos lados.
    /// </summary>
    /// <summary>
    /// El selector de cliente de Pedidos y Notas de venta: una página de
    /// coincidencias, no el padrón entero. Lo puede usar quien vende aunque
    /// no tenga la pantalla de Clientes.
    /// </summary>
    [HttpPost("buscar")]
    [PermisoAlguno("maestros.clientes:ver", "fact.pedidos:ver", "fact.notaventa:ver")]
    public async Task<IActionResult> Buscar([FromBody] ConsultaTablaRequest consulta, [FromQuery] string? para = null) =>
        Ok(await _clienteService.BuscarAsync(consulta, para));

    /// <summary>
    /// El selector de cliente del APK: todos los que se pueden elegir, pero
    /// solo con lo que el selector muestra y filtra, no la ficha completa.
    /// </summary>
    [HttpGet("selector")]
    [PermisoAlguno("maestros.clientes:ver", "fact.pedidos:ver", "fact.notaventa:ver")]
    public async Task<IActionResult> Selector([FromQuery] string? para = null) =>
        Ok(await _clienteService.SelectorAsync(para));

    [HttpPost("listar")]
    [Permiso("maestros.clientes", Accion.Ver)]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta)
    {
        return Ok(await _clienteService.ListarAsync(consulta));
    }

    /// <summary>Contadores y valores de filtro del listado completo.</summary>
    [HttpGet("resumen")]
    [Permiso("maestros.clientes", Accion.Ver)]
    public async Task<IActionResult> Resumen()
    {
        return Ok(await _clienteService.GetResumenAsync());
    }

    [HttpGet("{id:int}")]
    [Permiso("maestros.clientes", Accion.Ver)]
    public async Task<IActionResult> GetById(int id)
    {
        return Ok(await _clienteService.GetByIdAsync(id));
    }

    [HttpPost]
    [Permiso("maestros.clientes", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateClienteRequest request)
    {
        var response = await _clienteService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("maestros.clientes", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateClienteRequest request)
    {
        return Ok(await _clienteService.UpdateAsync(id, request));
    }

    /// <summary>Alta masiva desde archivo. Informa que paso con cada fila.</summary>
    [HttpPost("importar")]
    [Permiso("maestros.clientes", Accion.Importar)]
    public async Task<IActionResult> Importar([FromBody] ImportarClientesRequest request)
    {
        return Ok(await _clienteService.ImportarAsync(request));
    }

    /// <summary>Activa el registro.</summary>
    [HttpPatch("{id:int}/activar")]
    [Permiso("maestros.clientes", Accion.Editar)]
    public async Task<IActionResult> Activar(int id)
    {
        return Ok(await _clienteService.CambiarEstadoAsync(id, true));
    }

    /// <summary>Desactiva sin borrar: deja de usarse pero conserva su historial.</summary>
    [HttpPatch("{id:int}/desactivar")]
    [Permiso("maestros.clientes", Accion.Editar)]
    public async Task<IActionResult> Desactivar(int id)
    {
        return Ok(await _clienteService.CambiarEstadoAsync(id, false));
    }

    [HttpDelete("{id:int}")]
    [Permiso("maestros.clientes", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _clienteService.DeleteAsync(id);
        return NoContent();
    }
}
