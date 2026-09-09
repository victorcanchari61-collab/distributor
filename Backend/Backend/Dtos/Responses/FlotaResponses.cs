namespace Backend.Dtos.Responses;

public class TipoVehiculoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public decimal? CapacidadKgReferencia { get; set; }
    public bool Activo { get; set; }

    /// <summary>Cuántos vehículos son de este tipo. Si hay alguno, no se elimina.</summary>
    public int Vehiculos { get; set; }
}

/// <summary>
/// Un documento del vehículo o del conductor y en qué situación está.
///
/// El estado lo calcula el servidor y no la pantalla: "vencido", "por vencer"
/// y "al día" son la misma regla para la lista, el detalle y las alertas, y
/// repetirla en cada sitio es como terminan diciendo cosas distintas.
/// </summary>
public class VencimientoResponse
{
    public string Nombre { get; set; } = string.Empty;
    public DateTime? Vence { get; set; }

    /// <summary>Días que faltan. Negativo si ya pasó. Nulo si no hay fecha.</summary>
    public int? DiasRestantes { get; set; }

    /// <summary>vencido · porVencer · alDia · sinFecha</summary>
    public string Estado { get; set; } = string.Empty;
}

public class VehiculoResponse
{
    public int Id { get; set; }
    public string Placa { get; set; } = string.Empty;

    public int TipoVehiculoId { get; set; }
    public string TipoVehiculo { get; set; } = string.Empty;

    public string? Marca { get; set; }
    public string? Modelo { get; set; }
    public int? Anio { get; set; }
    public string? Color { get; set; }
    public decimal? CapacidadKg { get; set; }

    public string? SoatNumero { get; set; }
    public DateTime? SoatVence { get; set; }
    public DateTime? RevisionTecnicaVence { get; set; }
    public DateTime? PermisoCirculacionVence { get; set; }

    public string? Foto { get; set; }

    public int? ConductorId { get; set; }
    public string? Conductor { get; set; }

    public string? Observacion { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }

    /// <summary>SOAT, revisión técnica y permiso, cada uno con su estado.</summary>
    public List<VencimientoResponse> Vencimientos { get; set; } = [];

    /// <summary>
    /// El peor estado de sus documentos, para pintar la fila de un vistazo sin
    /// que la tabla tenga que mirar los tres.
    /// </summary>
    public string EstadoDocumentos { get; set; } = string.Empty;
}

public class ConductorResponse
{
    public int Id { get; set; }
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
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }

    /// <summary>Placas que tiene asignadas como conductor habitual.</summary>
    public List<string> Vehiculos { get; set; } = [];

    public List<VencimientoResponse> Vencimientos { get; set; } = [];
    public string EstadoDocumentos { get; set; } = string.Empty;
}

/// <summary>Lo que dice la cabecera de la pantalla de flota.</summary>
public class ResumenFlotaResponse
{
    public int Vehiculos { get; set; }
    public int Activos { get; set; }

    /// <summary>Con algún documento ya vencido: no deberían salir a repartir.</summary>
    public int ConDocumentoVencido { get; set; }

    /// <summary>Con algo que vence dentro del plazo de aviso.</summary>
    public int PorVencer { get; set; }
}

public class ResumenConductoresResponse
{
    public int Conductores { get; set; }
    public int Activos { get; set; }
    public int ConLicenciaVencida { get; set; }
    public int PorVencer { get; set; }
}

/// <summary>Lo que devuelve la subida de una imagen.</summary>
public class ArchivoSubidoResponse
{
    /// <summary>Ruta relativa para guardar y para pedirla después.</summary>
    public string Ruta { get; set; } = string.Empty;
}
