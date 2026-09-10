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

    /// <summary>El perfil de quien tiene la sesion abierta.</summary>
    Task<UsuarioResponse> GetPerfilAsync(int usuarioId);

    /// <summary>Cambia los datos personales de uno mismo, nunca su rol.</summary>
    Task<UsuarioResponse> UpdatePerfilAsync(int usuarioId, ActualizarPerfilRequest request);

    /// <summary>Cambia la contrasena propia, verificando la actual.</summary>
    Task CambiarPasswordAsync(int usuarioId, CambiarPasswordRequest request);
}
