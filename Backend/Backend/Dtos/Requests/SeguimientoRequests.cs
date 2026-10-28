namespace Backend.Dtos.Requests;

/// <summary>
/// Una gestión con un cliente: lo que se hizo, en qué quedó y, si se quiere, cuándo y cómo se vuelve a contactar.
/// Sirve para registrar una gestión nueva y para corregir una ya hecha.
/// </summary>
public class GuardarGestionRequest
{
    /// <summary>LLAMADA, WHATSAPP, VISITA o CORREO.</summary>
    public string TipoContacto { get; set; } = string.Empty;

    /// <summary>OPORTUNIDAD, SEGUIMIENTO, CON_OBJECIONES, SIN_RESPUESTA o NO_RECUPERABLE.</summary>
    public string Resultado { get; set; } = string.Empty;

    public string? Comentario { get; set; }

    /// <summary>El día y la hora del siguiente contacto, en hora de Perú. Sin esto no hay siguiente contacto.</summary>
    public DateTime? ProximoSeguimiento { get; set; }

    /// <summary>Cómo será ese contacto. Sin valor, el mismo tipo de esta gestión.</summary>
    public string? ProximoTipoContacto { get; set; }

    /// <summary>Qué se hará en ese contacto.</summary>
    public string? ProximaAccion { get; set; }
}

/// <summary>Cambiar el día y la hora de un contacto que sigue programado.</summary>
public class ReprogramarGestionRequest
{
    public DateTime ProximoSeguimiento { get; set; }
}
