namespace Backend.Dtos.Responses;

/// <summary>Datos de una empresa segun SUNAT, ya normalizados para el formulario.</summary>
public class ConsultaRucResponse
{
    public string Ruc { get; set; } = string.Empty;
    public string RazonSocial { get; set; } = string.Empty;
    public string? NombreComercial { get; set; }
    public string? Direccion { get; set; }
    public string? Departamento { get; set; }
    public string? Provincia { get; set; }
    public string? Distrito { get; set; }

    /// <summary>ACTIVO / BAJA DE OFICIO / etc.</summary>
    public string? Estado { get; set; }

    /// <summary>HABIDO / NO HABIDO.</summary>
    public string? Condicion { get; set; }
}

/// <summary>Datos de una persona segun RENIEC.</summary>
public class ConsultaDniResponse
{
    public string Dni { get; set; } = string.Empty;
    public string Nombres { get; set; } = string.Empty;
    public string ApellidoPaterno { get; set; } = string.Empty;
    public string ApellidoMaterno { get; set; } = string.Empty;

    /// <summary>Nombre completo listo para usar: apellidos + nombres.</summary>
    public string NombreCompleto { get; set; } = string.Empty;
}
