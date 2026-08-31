using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IUsuarioRepository : IRepository<Usuario>
{
    Task<Usuario?> GetByEmailAsync(string email);

    /// <summary>Rol activo por id, para validar al crear un usuario.</summary>
    Task<Rol?> GetRolAsync(int rolId);
}
