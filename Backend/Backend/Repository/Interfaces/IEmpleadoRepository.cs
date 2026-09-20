using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IEmpleadoRepository : IRepository<Empleado>
{
    Task<bool> ExistsByDocumentoAsync(string documento, int? excludeId = null);

    /// <summary>Qué usuario tiene enlazada cada ficha: { empleadoId → (usuarioId, nombre) }.</summary>
    Task<Dictionary<int, (int Id, string Nombre)>> UsuariosPorEmpleadoAsync();

    /// <summary>El usuario enlazado a esa ficha, si lo hay. Lo consulta el borrado antes de dejar huérfana una cuenta.</summary>
    Task<Usuario?> UsuarioDeAsync(int empleadoId);

    /// <summary>Borrado definitivo.</summary>
    Task DeleteAsync(Empleado entidad);
}
