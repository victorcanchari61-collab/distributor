namespace Backend.Dtos.Responses;

public class MetodoPagoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; }

    /// <summary>Cuántos documentos ya lo usan. Si hay alguno, no se elimina.</summary>
    public int Usos { get; set; }
}
