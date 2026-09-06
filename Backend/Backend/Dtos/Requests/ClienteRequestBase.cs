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

    /// <summary>El mercado, zona o punto de reparto donde está el puesto.</summary>
    public int? MercadoId { get; set; }

    /// <summary>
    /// Solo para importación: el nombre del mercado tal cual viene en el
    /// archivo. Si no existe uno con ese nombre, se crea. Si se manda
    /// <see cref="MercadoId"/> este campo se ignora.
    /// </summary>
    public string? MercadoNombre { get; set; }
}
