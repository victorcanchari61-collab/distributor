namespace Backend.Models;

public class Cliente
{
    public int Id { get; set; }

    /// <summary>DNI, RUC o codigo interno. Ver <see cref="TipoDocumento"/>.</summary>
    public string Documento { get; set; } = string.Empty;

    /// <summary>DNI / RUC / CODIGO, deducido del largo del documento.</summary>
    public string TipoDoc { get; set; } = TipoDocumento.Codigo;

    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Distrito { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }

    /// <summary>Dia en que el vendedor visita al cliente.</summary>
    public string? DiaVisita { get; set; }

    /// <summary>Ruta de reparto a la que pertenece.</summary>
    public string? Ruta { get; set; }

    /// <summary>Mercado o zona donde esta el puesto.</summary>
    public string? Mercado { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
