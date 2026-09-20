using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>El padrón de la gente que trabaja en el negocio. Ver <see cref="Models.Empleado"/>.</summary>
public interface IEmpleadoService
{
    Task<IEnumerable<EmpleadoResponse>> GetAllAsync();
    Task<EmpleadoResponse> GetByIdAsync(int id);

    /// <summary>Los que se pueden elegir al crear un usuario: activos, con quién los ocupa ya marcado.</summary>
    Task<IEnumerable<EmpleadoOpcionResponse>> OpcionesAsync();

    Task<EmpleadoResponse> CreateAsync(CreateEmpleadoRequest request);
    Task<EmpleadoResponse> UpdateAsync(int id, UpdateEmpleadoRequest request);

    /// <summary>Activa o desactiva sin borrar: el que se fue conserva su historial.</summary>
    Task<EmpleadoResponse> CambiarEstadoAsync(int id, bool activo);

    /// <summary>Elimina definitivamente. Solo para fichas creadas por error.</summary>
    Task DeleteAsync(int id);
}
