namespace Backend.Dtos.Requests;

public class LoginRequest
{
    /// <summary>El correo o, para quien no tiene, el DNI. Se llama Email por compatibilidad con los clientes.</summary>
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}
