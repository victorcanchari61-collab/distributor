namespace Backend.Models;

/// <summary>
/// Qué clase de vehículo es: camión, furgoneta, moto, triciclo.
///
/// Es catálogo aparte y no un enum porque cada distribuidora reparte con lo
/// que tiene, y con un enum añadir "moto de tres ruedas" obligaría a
/// recompilar. La capacidad de referencia vive aquí para proponerla al dar de
/// alta un vehículo, no para mandar sobre la del vehículo.
/// </summary>
public class TipoVehiculo
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>Carga típica en kilos. Solo una sugerencia al crear.</summary>
    public decimal? CapacidadKgReferencia { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<Vehiculo> Vehiculos { get; set; } = [];
}

/// <summary>
/// Un vehículo de reparto.
///
/// Guarda los vencimientos que dejan una unidad fuera de circulación —SOAT,
/// revisión técnica— porque en un reparto eso no es un dato administrativo:
/// salir con el SOAT vencido es una multa y el camión inmovilizado con la
/// mercadería dentro. Por eso alimentan las alertas.
/// </summary>
public class Vehiculo
{
    public int Id { get; set; }

    /// <summary>Placa. Identifica al vehículo y no se repite.</summary>
    public string Placa { get; set; } = string.Empty;

    public int TipoVehiculoId { get; set; }
    public TipoVehiculo? TipoVehiculo { get; set; }

    public string? Marca { get; set; }
    public string? Modelo { get; set; }

    /// <summary>Año de fabricación.</summary>
    public int? Anio { get; set; }

    public string? Color { get; set; }

    /// <summary>Cuánto carga, en kilos. Lo que decide qué pedidos entran.</summary>
    public decimal? CapacidadKg { get; set; }

    // --- Lo que vence ---

    /// <summary>Número de póliza del SOAT.</summary>
    public string? SoatNumero { get; set; }
    public DateTime? SoatVence { get; set; }

    public DateTime? RevisionTecnicaVence { get; set; }

    /// <summary>Vencimiento del permiso municipal o de circulación, si aplica.</summary>
    public DateTime? PermisoCirculacionVence { get; set; }

    /// <summary>
    /// Foto del vehículo. Se guarda la ruta relativa que sirve el backend, no
    /// el archivo: una imagen dentro de la fila hincharía cada consulta de la
    /// lista aunque nadie mire la foto.
    /// </summary>
    public string? Foto { get; set; }

    /// <summary>Conductor habitual. La asignación del día es otra cosa.</summary>
    public int? ConductorId { get; set; }
    public Conductor? Conductor { get; set; }

    public string? Observacion { get; set; }

    /// <summary>Un vehículo dado de baja no se borra: tiene historial detrás.</summary>
    public bool Activo { get; set; } = true;

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Quien conduce.
///
/// Lleva el vencimiento de la licencia por lo mismo que el vehículo lleva el
/// del SOAT: con la licencia vencida no puede salir, y enterarse el día del
/// reparto es enterarse tarde.
/// </summary>
public class Conductor
{
    public int Id { get; set; }

    public string Nombre { get; set; } = string.Empty;

    /// <summary>DNI. Identifica a la persona y no se repite.</summary>
    public string Documento { get; set; } = string.Empty;

    public string? Telefono { get; set; }
    public string? Direccion { get; set; }

    // --- La licencia ---

    public string? LicenciaNumero { get; set; }

    /// <summary>Categoría: A-I, A-IIa, A-IIIb... Texto, porque las categorías cambian.</summary>
    public string? LicenciaCategoria { get; set; }

    public DateTime? LicenciaVence { get; set; }

    /// <summary>Ruta relativa de la foto, igual que en el vehículo.</summary>
    public string? Foto { get; set; }

    public DateTime? FechaIngreso { get; set; }

    public string? Observacion { get; set; }

    public bool Activo { get; set; } = true;

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    /// <summary>Los vehículos que tiene asignados como conductor habitual.</summary>
    public List<Vehiculo> Vehiculos { get; set; } = [];
}
