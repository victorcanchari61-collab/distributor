namespace Backend.Dtos.Requests;

public abstract class ClienteRequestBase
{
    public string Documento { get; set; } = string.Empty;

    /// <summary>
    /// DNI, RUC o CODIGO. Si viene vacio (por ejemplo en una importacion) se
    /// deduce del largo del numero.
    /// </summary>
    public string? TipoDoc { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Distrito { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? DiaVisita { get; set; }
    public string? Ruta { get; set; }
    public string? Mercado { get; set; }
}
