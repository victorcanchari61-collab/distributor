using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Por qué no se entregó algo: los motivos que crea el dueño.</summary>
[ApiController]
[Route("api/motivonovedad")]
[Authorize]
public class MotivoNovedadController : ControllerBase
{
    private readonly INovedadService _novedades;

    public MotivoNovedadController(INovedadService novedades)
    {
        _novedades = novedades;
    }

    [HttpGet]
    [Permiso("tms.motivos", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _novedades.GetMotivosAsync());

    /// <summary>
    /// Los activos, para elegir uno al entregar un pedido.
    ///
    /// Los pide quien convierte pedidos en venta, que no tiene por qué ver el
    /// catálogo entero ni poder editarlo.
    /// </summary>
    [HttpGet("opciones")]
    [PermisoAlguno("fact.pedidos:confirmar", "tms.motivos:ver", "tms.novedades:ver")]
    public async Task<IActionResult> Opciones() => Ok(await _novedades.GetOpcionesAsync());

    [HttpPost]
    [Permiso("tms.motivos", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] MotivoNovedadRequest request) =>
        Ok(await _novedades.CrearMotivoAsync(request));

    [HttpPut("{id:int}")]
    [Permiso("tms.motivos", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] MotivoNovedadRequest request) =>
        Ok(await _novedades.ActualizarMotivoAsync(id, request));
}

/// <summary>Lo que no se entregó completo, y la revisión de lo que vuelve en el camión.</summary>
[ApiController]
[Route("api/novedad")]
[Authorize]
public class NovedadController : ControllerBase
{
    private readonly INovedadService _novedades;

    public NovedadController(INovedadService novedades)
    {
        _novedades = novedades;
    }

    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    /// <summary>Una página del listado, ya buscada, filtrada y ordenada en el servidor.</summary>
    [HttpPost("listar")]
    [Permiso("tms.novedades", Accion.Ver)]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _novedades.ListarAsync(consulta));

    /// <summary>Contadores del listado completo.</summary>
    [HttpGet("resumen")]
    [Permiso("tms.novedades", Accion.Ver)]
    public async Task<IActionResult> Resumen() => Ok(await _novedades.ResumenAsync());

    /// <summary>Lo que hay para elegir en los filtros del listado.</summary>
    [HttpGet("opciones")]
    [Permiso("tms.novedades", Accion.Ver)]
    public async Task<IActionResult> Opciones() => Ok(await _novedades.OpcionesAsync());

    /// <summary>El encargado cuenta lo que volvió en el camión: llegó completo o faltó.</summary>
    [HttpPatch("{id:int}/verificar")]
    [Permiso("tms.novedades", Accion.Confirmar)]
    public async Task<IActionResult> Verificar(int id, [FromBody] VerificarNovedadRequest request) =>
        Ok(await _novedades.VerificarAsync(id, request, UsuarioId));

    /// <summary>Deshace una revisión: se contó mal y vuelve a quedar pendiente.</summary>
    [HttpPatch("{id:int}/reabrir")]
    [Permiso("tms.novedades", Accion.Confirmar)]
    public async Task<IActionResult> Reabrir(int id) => Ok(await _novedades.ReabrirAsync(id));
}
