namespace Backend.Dtos.Requests;

/// <summary>Cierra la caja propia: cuánto se contó y a qué cuenta se entrega.</summary>
public class CerrarCajaRequest
{
    public decimal Billetes { get; set; }
    public decimal Monedas { get; set; }
    public int CuentaDestinoId { get; set; }
    public string? Observacion { get; set; }
}
