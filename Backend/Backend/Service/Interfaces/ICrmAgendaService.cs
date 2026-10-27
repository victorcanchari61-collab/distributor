using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// La agenda del seguimiento de clientes: las próximas acciones que alguien anotó y siguen abiertas.
/// </summary>
public interface ICrmAgendaService
{
    /// <summary>
    /// Las acciones abiertas, las vencidas primero.
    /// </summary>
    /// <param name="quien">
    /// "mias" (default): las que anotó quien pregunta, o son de un cliente suyo (asignado o de sus
    /// rutas). "todas": las de todos los clientes que su alcance le deja ver.
    /// </param>
    /// <param name="estado">Deja solo las "vencidas", "hoy" o "proximas". Sin valor, todas.</param>
    Task<CrmAgendaResponse> TareasAsync(string? quien, string? estado);

    /// <summary>Cuántas acciones abiertas tiene una persona (las "mias"). Para el recordatorio de alertas.</summary>
    Task<CrmAgendaResumenResponse> ResumenDeAsync(int usuarioId);
}
