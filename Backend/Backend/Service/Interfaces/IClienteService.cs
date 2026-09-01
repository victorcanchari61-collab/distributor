using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IClienteService
{
    Task<IEnumerable<ClienteResponse>> GetAllAsync();
    Task<ClienteResponse> GetByIdAsync(int id);
    Task<ClienteResponse> CreateAsync(CreateClienteRequest request);
    Task<ClienteResponse> UpdateAsync(int id, UpdateClienteRequest request);
    /// <summary>Activa o desactiva sin borrar.</summary>
    Task<ClienteResponse> CambiarEstadoAsync(int id, bool activo);

    /// <summary>Elimina definitivamente. Solo para registros creados por error.</summary>
    Task DeleteAsync(int id);

    /// <summary>Alta masiva desde archivo. Devuelve el detalle fila por fila.</summary>
    Task<ImportarResponse> ImportarAsync(ImportarClientesRequest request);
}
