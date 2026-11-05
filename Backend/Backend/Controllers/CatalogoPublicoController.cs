using Backend.Dtos.Responses;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;

namespace Backend.Controllers;

/// <summary>
/// El catálogo que los clientes abren con un enlace, sin cuenta ni sesión. Solo lectura y solo lo que un cliente
/// debe ver: nombre, categoría, marca, foto, precios y presentaciones de venta. Nada de costos, stock, ni ids.
/// </summary>
[ApiController]
[AllowAnonymous]
[Route("api/publico/catalogo")]
public class CatalogoPublicoController : ControllerBase
{
    /// <summary>
    /// Cuánto se guarda armado. El enlace es público: lo abre cualquiera, cuantas veces quiera, y cada apertura
    /// sin esto sería una consulta completa del catálogo a la base.
    /// </summary>
    private static readonly TimeSpan Vigencia = TimeSpan.FromSeconds(60);

    private const string Clave = "catalogo-publico";

    private readonly ICatalogoClienteService _catalogo;
    private readonly IMemoryCache _cache;

    public CatalogoPublicoController(ICatalogoClienteService catalogo, IMemoryCache cache)
    {
        _catalogo = catalogo;
        _cache = cache;
    }

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        if (!_cache.TryGetValue(Clave, out CatalogoPublicoResponse? catalogo) || catalogo is null)
        {
            catalogo = await _catalogo.GetPublicoAsync();
            _cache.Set(Clave, catalogo, Vigencia);
        }

        return Ok(catalogo);
    }
}
