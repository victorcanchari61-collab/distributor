using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// El kardex del dinero: todo lo que entra y sale de las cajas y los bancos,
/// venga de donde venga, clasificado en operativo, no operativo o interno.
/// </summary>
public interface IMovimientoDineroService
{
    Task<IEnumerable<MovimientoDineroResponse>> ListarAsync(DateTime desde, DateTime hasta, int? cuentaId);

    /// <summary>Las cuentas activas, para registrar un movimiento a mano.</summary>
    Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync();
}
