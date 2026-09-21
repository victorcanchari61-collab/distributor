namespace Backend.Dtos.Responses;

public class RutaResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; }

    /// <summary>Cuántos clientes ya la usan. Si hay alguno, no se elimina.</summary>
    public int Clientes { get; set; }

    /// <summary>Quiénes la tienen a cargo. Puede ser más de uno (el titular y su reemplazo).</summary>
    public List<string> Vendedores { get; set; } = [];
}
