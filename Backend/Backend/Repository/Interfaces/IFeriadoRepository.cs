using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IFeriadoRepository : IRepository<Feriado>
{
    Task<bool> ExistsByFechaAsync(DateTime fecha, int? excludeId = null);
    Task DeleteAsync(Feriado entidad);
}
