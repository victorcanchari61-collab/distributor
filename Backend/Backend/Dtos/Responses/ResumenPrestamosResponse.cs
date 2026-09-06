namespace Backend.Dtos.Responses;

/// <summary>Contadores del listado completo de préstamos, no de la página visible.</summary>
public class ResumenPrestamosResponse
{
    public int Total { get; set; }
    public int Pendientes { get; set; }
    public int Devueltos { get; set; }
}
