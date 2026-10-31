namespace Backend.Models;

/// <summary>
/// Empresa emisora. Pueden registrarse varias, pero solo una puede estar
/// activa: es la que opera el sistema en un momento dado.
/// </summary>
public class Empresa
{
    public int Id { get; set; }
    public string RazonSocial { get; set; } = string.Empty;
    public string NombreComercial { get; set; } = string.Empty;
    public string Ruc { get; set; } = string.Empty;
    public string? Direccion { get; set; }

    /// <summary>Ubicacion politica, para documentos y guias de remision.</summary>
    public string? Departamento { get; set; }
    public string? Provincia { get; set; }
    public string? Distrito { get; set; }

    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? SitioWeb { get; set; }
    public string? RepresentanteLegal { get; set; }
    /// <summary>La empresa con la que opera el sistema. Solo una a la vez.</summary>
    public bool Activa { get; set; }

    /// <summary>
    /// Empresa disponible para usarse. Una empresa deshabilitada conserva su
    /// historial pero no se puede activar; asi se retira sin eliminarla.
    /// </summary>
    public bool Habilitada { get; set; } = true;

    // --- Facturación electrónica ---

    /// <summary>Ubigeo (6 dígitos, INEI) del domicilio fiscal: el XML de SUNAT lo exige.</summary>
    public string? Ubigeo { get; set; }

    /// <summary>Usuario SOL con el que se envía a SUNAT. En el entorno de pruebas: MODDATOS.</summary>
    public string? UsuarioSol { get; set; }

    /// <summary>Clave SOL. Nunca sale en las respuestas ni en la bitácora: solo se guarda y se usa para enviar.</summary>
    public string? ClaveSol { get; set; }

    /// <summary>
    /// true: los comprobantes van al entorno de pruebas (beta) de SUNAT y no tienen validez tributaria. false: van a
    /// producción. Arranca en pruebas para que nadie emita de verdad sin haberlo decidido.
    /// </summary>
    public bool ModoPrueba { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
