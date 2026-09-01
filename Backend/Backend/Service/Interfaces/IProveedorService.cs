using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IProveedorService
{
    Task<IEnumerable<ProveedorResponse>> GetAllAsync();
    Task<ProveedorResponse> GetByIdAsync(int id);
    Task<ProveedorResponse> CreateAsync(CreateProveedorRequest request);
    Task<ProveedorResponse> UpdateAsync(int id, UpdateProveedorRequest request);
    /// <summary>Activa o desactiva sin borrar.</summary>
    Task<ProveedorResponse> CambiarEstadoAsync(int id, bool activo);

    /// <summary>Elimina definitivamente. Solo para registros creados por error.</summary>
    Task DeleteAsync(int id);

    /// <summary>Alta masiva desde archivo. Devuelve el detalle fila por fila.</summary>
    Task<ImportarResponse> ImportarAsync(ImportarProveedoresRequest request);
}
