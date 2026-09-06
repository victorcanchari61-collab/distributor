namespace Backend.Dtos.Responses;

/// <summary>
/// Contadores del kardex completo del almacén, no de la página visible.
/// </summary>
public class ResumenKardexResponse
{
    public int Entradas { get; set; }
    public int Salidas { get; set; }
}
