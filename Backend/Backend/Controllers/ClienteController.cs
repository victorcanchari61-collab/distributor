using Backend.Dtos.Requests;
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

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _clienteService.GetAllAsync());
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        return Ok(await _clienteService.GetByIdAsync(id));
    }

    [HttpPost]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Create([FromBody] CreateClienteRequest request)
    {
        var response = await _clienteService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateClienteRequest request)
    {
        return Ok(await _clienteService.UpdateAsync(id, request));
    }

    /// <summary>Alta masiva desde archivo. Informa que paso con cada fila.</summary>
    [HttpPost("importar")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Importar([FromBody] ImportarClientesRequest request)
    {
        return Ok(await _clienteService.ImportarAsync(request));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Administrador")]
    public async Task<IActionResult> Delete(int id)
    {
        await _clienteService.DeleteAsync(id);
        return NoContent();
    }
}
