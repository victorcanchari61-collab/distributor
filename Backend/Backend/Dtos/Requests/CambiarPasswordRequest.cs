namespace Backend.Dtos.Requests;

public class CambiarPasswordRequest
{
    /// <summary>La clave que tiene ahora. Se verifica antes de cambiarla.</summary>
    public string PasswordActual { get; set; } = string.Empty;

    public string PasswordNueva { get; set; } = string.Empty;
}
