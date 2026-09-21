using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IUsuarioRepository : IRepository<Usuario>
{
    Task<Usuario?> GetByEmailAsync(string email);

    /// <summary>Por correo o, si no coincide, por DNI: con lo que la persona escribe para entrar.</summary>
    Task<Usuario?> GetByIdentificadorAsync(string identificador);

    Task<Usuario?> GetByDniAsync(string dni);

    /// <summary>Todos los usuarios con su rol, activos primero.</summary>
    Task<IEnumerable<Usuario>> GetAllConRolAsync();

    /// <summary>Un usuario con su rol cargado.</summary>
    Task<Usuario?> GetByIdConRolAsync(int id);

    /// <summary>Rol activo por id, para validar al crear un usuario.</summary>
    Task<Rol?> GetRolAsync(int rolId);

    /// <summary>La ficha de empleado por id, para validarla al enlazarla a una cuenta.</summary>
    Task<Empleado?> GetEmpleadoAsync(int empleadoId);
    Task<Ruta?> GetRutaAsync(int rutaId);

    /// <summary>Quién tiene a cargo cada ruta (activos): id de ruta → nombres separados por coma.</summary>
    Task<Dictionary<int, string>> VendedoresPorRutaAsync();

    /// <summary>Quién tiene ya enlazada esa ficha, sin contar al usuario que se está editando.</summary>
    Task<Usuario?> GetUsuarioDeEmpleadoAsync(int empleadoId, int? excluirUsuarioId = null);
}
