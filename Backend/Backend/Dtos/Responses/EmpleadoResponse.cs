namespace Backend.Dtos.Responses;

public class EmpleadoResponse
{
    public int Id { get; set; }
    public string Documento { get; set; } = string.Empty;
    public string TipoDoc { get; set; } = string.Empty;
    public string Nombres { get; set; } = string.Empty;
    public string Apellidos { get; set; } = string.Empty;

    /// <summary>Nombres y apellidos juntos, que es como se lee en una lista o en un selector.</summary>
    public string NombreCompleto { get; set; } = string.Empty;

    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? Direccion { get; set; }
    public string? Cargo { get; set; }
    public string? Area { get; set; }
    public DateTime? FechaIngreso { get; set; }
    public DateTime? FechaCese { get; set; }
    public string? Observacion { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }

    /// <summary>El usuario enlazado a esta ficha, si tiene. Null si no entra al sistema.</summary>
    public int? UsuarioId { get; set; }
    public string? Usuario { get; set; }
}

/// <summary>Lo justo para elegir un empleado en un selector, sin arrastrar toda la ficha.</summary>
public class EmpleadoOpcionResponse
{
    public int Id { get; set; }
    public string Documento { get; set; } = string.Empty;

    /// <summary>DNI o CODIGO: solo el DNI sirve para llenar el campo DNI de la cuenta.</summary>
    public string TipoDoc { get; set; } = string.Empty;

    public string NombreCompleto { get; set; } = string.Empty;
    public string? Cargo { get; set; }

    /// <summary>Para proponerlo como correo de la cuenta. Puede no tener.</summary>
    public string? Email { get; set; }

    /// <summary>Id del usuario que YA lo usa. El selector lo muestra ocupado en vez de esconderlo.</summary>
    public int? UsuarioId { get; set; }
}
