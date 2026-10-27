namespace Backend.Dtos.Requests;

/// <summary>Lo que se habló con un cliente y qué toca hacer después.</summary>
public class CrearGestionRequest
{
    /// <summary>LLAMADA, VISITA, WHATSAPP u OTRO.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>CONTACTADO, SIN_RESPUESTA, PROMESA_COMPRA, PROMESA_PAGO, RECLAMO o PERDIDO.</summary>
    public string Resultado { get; set; } = string.Empty;

    public string Nota { get; set; } = string.Empty;

    /// <summary>Qué hay que hacer después. Va junto con <see cref="ProximaFecha"/>: las dos o ninguna.</summary>
    public string? ProximaAccion { get; set; }

    /// <summary>El día en que toca. No puede ser un día que ya pasó.</summary>
    public DateTime? ProximaFecha { get; set; }
}

/// <summary>Dar por hecha (o volver a abrir) la próxima acción de una gestión.</summary>
public class CumplirGestionRequest
{
    public bool Cumplida { get; set; }
}
