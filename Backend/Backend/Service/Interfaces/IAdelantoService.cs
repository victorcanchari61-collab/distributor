using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Adelantos y préstamos al trabajador: la plata sale de una cuenta al dársela y se le descuenta en
/// la planilla, todo de una vez o en cuotas, desde la semana que se elija.
/// </summary>
public interface IAdelantoService
{
    Task<IEnumerable<AdelantoFilaResponse>> ListarAsync();
    Task<ResumenAdelantosResponse> ResumenAsync();
    Task<AdelantoResponse> GetAsync(int id);

    /// <summary>Los empleados activos, con su sueldo y lo que todavía deben.</summary>
    Task<IEnumerable<EmpleadoAdelantoResponse>> EmpleadosAsync();

    /// <summary>De qué cuentas puede salir la plata.</summary>
    Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync();

    Task<AdelantoResponse> CrearAsync(CrearAdelantoRequest request, int? usuarioId);

    /// <summary>Cambia desde qué semana y de a cuánto se descuenta lo que falta.</summary>
    Task<AdelantoResponse> CambiarPlanAsync(int id, PlanAdelantoRequest request);

    /// <summary>Solo si todavía no se descontó nada: la plata vuelve a la cuenta de donde salió.</summary>
    Task<AdelantoResponse> AnularAsync(int id, int? usuarioId);
}
