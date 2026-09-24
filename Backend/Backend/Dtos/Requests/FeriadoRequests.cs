namespace Backend.Dtos.Requests;

public class FeriadoRequest
{
    public DateTime Fecha { get; set; }
    public string Nombre { get; set; } = string.Empty;

    /// <summary>NORMAL, DOBLE o TRIPLE: a qué tarifa se paga ese día.</summary>
    public string Pago { get; set; } = string.Empty;
}
