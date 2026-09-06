namespace Backend.Dtos.Responses;

/// <summary>
/// Contadores de todos los cobros del usuario en el rango pedido, no de la
/// página visible: sumar sobre las filas cargadas daría el total de 20 cobros.
/// </summary>
public class ResumenCobrosResponse
{
    public int Validos { get; set; }
    public int Anulados { get; set; }
    public decimal TotalCobrado { get; set; }
}
