namespace Backend.Dtos.Responses;

public class BancoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }

    /// <summary>Cuántas cuentas bancarias tiene, para no dejar borrar ni desactivar uno en uso a ciegas.</summary>
    public int CantidadCuentas { get; set; }
}
