using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IUsuarioRepository : IRepository<Usuario>
{
    Task<Usuario?> GetByEmailAsync(string email);

    /// <summary>Todos los usuarios con su rol, activos primero.</summary>
    Task<IEnumerable<Usuario>> GetAllConRolAsync();

    /// <summary>Un usuario con su rol cargado.</summary>
    Task<Usuario?> GetByIdConRolAsync(int id);

    /// <summary>Rol activo por id, para validar al crear un usuario.</summary>
    Task<Rol?> GetRolAsync(int rolId);
}
