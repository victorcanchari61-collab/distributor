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
public class UsuarioController : ControllerBase
{
    private readonly IUsuarioService _usuarioService;

    public UsuarioController(IUsuarioService usuarioService)
    {
        _usuarioService = usuarioService;
    }

    [HttpGet]
    [Permiso("config.usuarios", Accion.Ver)]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _usuarioService.GetAllAsync());
    }

    [HttpGet("{id:int}")]
    [Permiso("config.usuarios", Accion.Ver)]
    public async Task<IActionResult> GetById(int id)
    {
        return Ok(await _usuarioService.GetByIdAsync(id));
    }

    /// <summary>Alta de usuario desde el panel, ya con sesion iniciada.</summary>
    [HttpPost]
    [Permiso("config.usuarios", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateUsuarioRequest request)
    {
        var response = await _usuarioService.RegisterAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("config.usuarios", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateUsuarioRequest request)
    {
        return Ok(await _usuarioService.UpdateAsync(id, request));
    }
}
