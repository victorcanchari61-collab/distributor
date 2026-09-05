using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AlertasController : ControllerBase
{
    private readonly IAlertasService _alertas;

    public AlertasController(IAlertasService alertas)
    {
        _alertas = alertas;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _alertas.GetAsync());
}
