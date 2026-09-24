using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IAsistenciaRepository : IRepository<Asistencia>
{
    /// <summary>Con el empleado y el usuario ya cargados, para no pedirlos aparte.</summary>
    Task<Asistencia?> GetConDetalleAsync(int id);

    /// <summary>Todas las marcas del rango (incluidas las anuladas: el historial las muestra tachadas).</summary>
    Task<List<Asistencia>> ListarAsync(DateTime desde, DateTime hasta, int? empleadoId);

    /// <summary>Si ya hay una marca ACTIVA para ese empleado ese día. Uno por día: si está mal, se anula antes de volver a marcar.</summary>
    Task<bool> ExisteActivaAsync(int empleadoId, DateTime fecha);
}
