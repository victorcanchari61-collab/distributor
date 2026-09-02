using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IUsuarioService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<UsuarioResponse> RegisterAsync(CreateUsuarioRequest request);
    Task<IEnumerable<UsuarioResponse>> GetAllAsync();
    Task<UsuarioResponse> GetByIdAsync(int id);
    Task<UsuarioResponse> UpdateAsync(int id, UpdateUsuarioRequest request);
}
