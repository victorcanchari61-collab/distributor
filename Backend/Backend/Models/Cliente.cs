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

    /// <summary>Distrito del ubigeo oficial (INEI/RENIEC).</summary>
    public int? DistritoId { get; set; }
    public Distrito? Distrito { get; set; }

    public string? Telefono { get; set; }
    public string? Email { get; set; }

    /// <summary>Dia en que el vendedor visita al cliente.</summary>
    public string? DiaVisita { get; set; }

    /// <summary>Ruta de reparto a la que pertenece.</summary>
    public int? RutaId { get; set; }
    public Ruta? Ruta { get; set; }

    /// <summary>El mercado, zona o punto de reparto donde está el puesto.</summary>
    public int? MercadoId { get; set; }
    public Mercado? Mercado { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
