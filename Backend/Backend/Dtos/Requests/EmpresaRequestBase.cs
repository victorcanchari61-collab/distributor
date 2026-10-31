namespace Backend.Dtos.Requests;

public abstract class EmpresaRequestBase
{
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

    // --- Facturación electrónica ---

    /// <summary>Ubigeo de 6 dígitos del domicilio fiscal.</summary>
    public string? Ubigeo { get; set; }

    public string? UsuarioSol { get; set; }

    /// <summary>Al editar, vacío o nulo deja la clave que ya estaba: no se devuelve nunca, así que no se puede reenviar.</summary>
    public string? ClaveSol { get; set; }

    /// <summary>true: envía al entorno de pruebas de SUNAT. false: producción.</summary>
    public bool ModoPrueba { get; set; } = true;

    // --- WhatsApp ---

    /// <summary>true: cada comprobante aceptado por SUNAT se manda solo al teléfono del cliente.</summary>
    public bool WhatsAppAutomatico { get; set; }

    /// <summary>El mensaje con sus {variables}. Vacío: el mensaje de siempre.</summary>
    public string? WhatsAppPlantilla { get; set; }
}

/// <summary>El certificado digital (.pem) de la empresa, en texto: clave privada y certificado, sin contraseña.</summary>
public class SubirCertificadoRequest
{
    public string Certificado { get; set; } = string.Empty;
}
