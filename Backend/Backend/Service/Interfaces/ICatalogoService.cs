using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface ICatalogoService
{
    // --- Categorias ---
    Task<IEnumerable<CategoriaResponse>> GetCategoriasAsync();
    Task<CategoriaResponse> GetCategoriaAsync(int id);
    Task<CategoriaResponse> CreateCategoriaAsync(CreateCategoriaRequest request);
    Task<CategoriaResponse> UpdateCategoriaAsync(int id, UpdateCategoriaRequest request);
    Task DeleteCategoriaAsync(int id);

    // --- Marcas ---
    Task<IEnumerable<MarcaResponse>> GetMarcasAsync();
    Task<MarcaResponse> GetMarcaAsync(int id);
    Task<MarcaResponse> CreateMarcaAsync(CreateMarcaRequest request);
    Task<MarcaResponse> UpdateMarcaAsync(int id, UpdateMarcaRequest request);
    Task DeleteMarcaAsync(int id);

    // --- Unidades ---
    Task<IEnumerable<UnidadMedidaResponse>> GetUnidadesAsync();
    Task<UnidadMedidaResponse> GetUnidadAsync(int id);
    Task<UnidadMedidaResponse> CreateUnidadAsync(CreateUnidadMedidaRequest request);
    Task<UnidadMedidaResponse> UpdateUnidadAsync(int id, UpdateUnidadMedidaRequest request);
    Task DeleteUnidadAsync(int id);
}
