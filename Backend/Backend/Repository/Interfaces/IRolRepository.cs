using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IRolRepository : IRepository<Rol>
{
    /// <summary>Roles con sus permisos y el conteo de usuarios asignados.</summary>
    Task<IEnumerable<Rol>> GetAllConDetalleAsync();

    Task<Rol?> GetConPermisosAsync(int id);
    Task<bool> ExistsByNombreAsync(string nombre, int? excludeId = null);
    Task<int> ContarUsuariosAsync(int rolId);

    /// <summary>Reemplaza la matriz de permisos del rol por la que se envia.</summary>
    Task ReemplazarPermisosAsync(int rolId, IEnumerable<RolPermiso> permisos);

    Task DeleteAsync(Rol rol);
}
