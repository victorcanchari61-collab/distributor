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

    /// <summary>La ficha de empleado por id, para validarla al enlazarla a una cuenta.</summary>
    Task<Empleado?> GetEmpleadoAsync(int empleadoId);

    /// <summary>Quién tiene ya enlazada esa ficha, sin contar al usuario que se está editando.</summary>
    Task<Usuario?> GetUsuarioDeEmpleadoAsync(int empleadoId, int? excluirUsuarioId = null);
}
