using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IUsuarioService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<UsuarioResponse> RegisterAsync(CreateUsuarioRequest request);
}
