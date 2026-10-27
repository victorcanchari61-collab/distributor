namespace Backend.Models;

/// <summary>Cómo se hizo el contacto con el cliente.</summary>
public static class TipoGestion
{
    public const string Llamada = "LLAMADA";
    public const string Visita = "VISITA";
    public const string WhatsApp = "WHATSAPP";
    public const string Otro = "OTRO";

    public static readonly string[] Todos = [Llamada, Visita, WhatsApp, Otro];
}

/// <summary>En qué quedó el contacto.</summary>
public static class ResultadoGestion
{
    /// <summary>Se habló con el cliente, sin un acuerdo concreto.</summary>
    public const string Contactado = "CONTACTADO";

    public const string SinRespuesta = "SIN_RESPUESTA";
    public const string PromesaCompra = "PROMESA_COMPRA";
    public const string PromesaPago = "PROMESA_PAGO";
    public const string Reclamo = "RECLAMO";

    /// <summary>Dijo que ya no va a comprar.</summary>
    public const string Perdido = "PERDIDO";

    public static readonly string[] Todos =
        [Contactado, SinRespuesta, PromesaCompra, PromesaPago, Reclamo, Perdido];
}

/// <summary>
/// Un contacto con un cliente que está comprando menos: la llamada, la visita o el mensaje, lo que
/// se habló y qué hay que hacer después.
///
/// Es un historial: una gestión no se reescribe, se agrega otra. Lo único que cambia es
/// <see cref="Cumplida"/>, para dar por hecha la próxima acción que dejó anotada.
/// </summary>
public class GestionCliente
{
    public int Id { get; set; }

    public int ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    /// <summary>Cuándo se hizo el contacto (instante, UTC).</summary>
    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    public string Tipo { get; set; } = TipoGestion.Llamada;
    public string Resultado { get; set; } = ResultadoGestion.Contactado;

    public string Nota { get; set; } = string.Empty;

    /// <summary>Qué hay que hacer después ("volver a llamar", "llevar la muestra"). Va con su fecha.</summary>
    public string? ProximaAccion { get; set; }

    /// <summary>El día en que toca hacerlo (fecha de Perú, a las 00:00 y sin zona).</summary>
    public DateTime? ProximaFecha { get; set; }

    /// <summary>La próxima acción ya se hizo, o ya no hace falta.</summary>
    public bool Cumplida { get; set; }
    public DateTime? CumplidaEn { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
