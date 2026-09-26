using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IEstadoResultadosService
{
    /// <summary>
    /// El estado de resultados entre dos días locales (inclusive). Sin
    /// fechas, lo que va del mes. Nunca más de un año de una vez.
    /// </summary>
    Task<EstadoResultadosResponse> CalcularAsync(DateTime? desde, DateTime? hasta);
}
