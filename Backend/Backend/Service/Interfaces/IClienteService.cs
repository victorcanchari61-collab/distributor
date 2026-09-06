using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IClienteService
{
    /// <summary>
    /// Todos, sin paginar. Lo usan los buscadores de cliente de otras
    /// pantallas (pedidos, ventas), que necesitan la lista completa en memoria
    /// para filtrar mientras se escribe.
    /// </summary>
    Task<IEnumerable<ClienteResponse>> GetAllAsync();

    /// <summary>Una página del listado, ya buscada, filtrada y ordenada en la base.</summary>
    Task<PaginaResponse<ClienteResponse>> ListarAsync(ConsultaTablaRequest consulta);

    /// <summary>Contadores y valores de filtro del listado completo.</summary>
    Task<ResumenClientesResponse> GetResumenAsync();

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
