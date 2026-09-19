using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>Cuánto se ganó con cada producto vendido.</summary>
[ApiController]
[Route("api/ganancia")]
[Authorize]
public class GananciaController : ControllerBase
{
    private readonly IGananciaService _ganancias;

    public GananciaController(IGananciaService ganancias)
    {
        _ganancias = ganancias;
    }

    /// <summary>
    /// Una página de productos con su ganancia y los totales de todo lo
    /// filtrado. Sin fechas, lo que va del mes. Lo que se ve lo recorta el
    /// alcance de quien pregunta.
    /// </summary>
    [HttpPost("listar")]
    [Permiso("finanzas.ganancias", Accion.Ver)]
    public async Task<IActionResult> Listar([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _ganancias.ListarAsync(consulta));
}
