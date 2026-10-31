namespace Backend.Dtos.Responses;

public class EmpresaResponse
{
    public int Id { get; set; }
    public string RazonSocial { get; set; } = string.Empty;
    public string NombreComercial { get; set; } = string.Empty;
    public string Ruc { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public string? Departamento { get; set; }
    public string? Provincia { get; set; }
    public string? Distrito { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? SitioWeb { get; set; }
    public string? RepresentanteLegal { get; set; }
    public bool Activa { get; set; }
    public bool Habilitada { get; set; }

    // --- Facturación electrónica ---
    public string? Ubigeo { get; set; }
    public string? UsuarioSol { get; set; }

    /// <summary>Hay una clave SOL guardada. La clave en sí nunca se devuelve.</summary>
    public bool TieneClaveSol { get; set; }

    /// <summary>true: emite al entorno de pruebas de SUNAT (sin validez tributaria).</summary>
    public bool ModoPrueba { get; set; }

    /// <summary>Del certificado digital subido: a nombre de quién y hasta cuándo vale. Nulos si no hay.</summary>
    public string? CertificadoTitular { get; set; }

    public DateTime? CertificadoVenceEl { get; set; }
    public bool CertificadoVencido { get; set; }
    public DateTime FechaCreacion { get; set; }
}
