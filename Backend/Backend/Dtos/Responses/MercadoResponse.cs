namespace Backend.Dtos.Responses;

public class MercadoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; }

    /// <summary>Cuántos clientes ya lo usan. Si hay alguno, no se elimina.</summary>
    public int Clientes { get; set; }
}
