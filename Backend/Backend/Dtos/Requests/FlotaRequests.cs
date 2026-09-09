namespace Backend.Dtos.Requests;

public class TipoVehiculoRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public decimal? CapacidadKgReferencia { get; set; }
    public bool Activo { get; set; } = true;
}

public class VehiculoRequest
{
    public string Placa { get; set; } = string.Empty;
    public int TipoVehiculoId { get; set; }

    public string? Marca { get; set; }
    public string? Modelo { get; set; }
    public int? Anio { get; set; }
    public string? Color { get; set; }
    public decimal? CapacidadKg { get; set; }

    public string? SoatNumero { get; set; }
    public DateTime? SoatVence { get; set; }
    public DateTime? RevisionTecnicaVence { get; set; }
    public DateTime? PermisoCirculacionVence { get; set; }

    /// <summary>
    /// Ruta que devolvió la subida de la imagen. El archivo NO viaja aquí: se
    /// sube aparte y esto solo guarda dónde quedó.
    /// </summary>
    public string? Foto { get; set; }

    public int? ConductorId { get; set; }
    public string? Observacion { get; set; }
    public bool Activo { get; set; } = true;
}

public class ConductorRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;
    public string? Telefono { get; set; }
    public string? Direccion { get; set; }

    public string? LicenciaNumero { get; set; }
    public string? LicenciaCategoria { get; set; }
    public DateTime? LicenciaVence { get; set; }

    public string? Foto { get; set; }
    public DateTime? FechaIngreso { get; set; }
    public string? Observacion { get; set; }
    public bool Activo { get; set; } = true;
}
