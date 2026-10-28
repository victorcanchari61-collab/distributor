namespace Backend.Models;

/// <summary>Cómo se hizo el contacto con el cliente.</summary>
public static class TipoContacto
{
    public const string Llamada = "LLAMADA";
    public const string WhatsApp = "WHATSAPP";
    public const string Visita = "VISITA";
    public const string Correo = "CORREO";

    public static readonly string[] Todos = [Llamada, WhatsApp, Visita, Correo];

    public static string Etiqueta(string tipo) => tipo switch
    {
        Llamada => "Llamada telefónica",
        WhatsApp => "WhatsApp",
        Visita => "Visita presencial",
        Correo => "Correo electrónico",
        _ => tipo,
    };
}

/// <summary>
/// En qué quedó el contacto. Son cinco estados resumidos, cada uno con su color (el tono) y una guía de cuándo
/// elegirlo, que es lo que ve quien registra la gestión.
/// </summary>
public static class ResultadoGestion
{
    public const string Oportunidad = "OPORTUNIDAD";
    public const string Seguimiento = "SEGUIMIENTO";
    public const string ConObjeciones = "CON_OBJECIONES";
    public const string SinRespuesta = "SIN_RESPUESTA";
    public const string NoRecuperable = "NO_RECUPERABLE";

    public static readonly (string Clave, string Etiqueta, string Tono, string Cuando)[] Catalogo =
    [
        (Oportunidad, "Oportunidad", "positivo", "Interesado en comprar, solicita cotización."),
        (Seguimiento, "Seguimiento", "espera", "Solicita contactar después, sin necesidad de stock."),
        (ConObjeciones, "Con objeciones", "objecion", "Precio no competitivo, compra a la competencia, problema de crédito, reclamo pendiente."),
        (SinRespuesta, "Sin respuesta", "neutro", "No contesta."),
        (NoRecuperable, "No recuperable", "perdido", "No está interesado, datos incorrectos, negocio cerrado."),
    ];

    public static readonly string[] Todos = [.. Catalogo.Select(r => r.Clave)];

    public static (string Etiqueta, string Tono) De(string resultado)
    {
        var r = Catalogo.FirstOrDefault(x => x.Clave == resultado);
        return r.Clave is null ? (resultado, "neutro") : (r.Etiqueta, r.Tono);
    }
}

/// <summary>Si el siguiente contacto que dejó una gestión sigue pendiente o ya se hizo.</summary>
public static class EstadoSeguimiento
{
    public const string Programado = "PROGRAMADO";
    public const string Cumplido = "CUMPLIDO";
}

/// <summary>
/// Una gestión con un cliente: el contacto (llamada, WhatsApp, visita o correo), qué resultado tuvo y, si se dejó,
/// cuándo y cómo se vuelve a contactar.
///
/// Es un historial: lo que se hizo no se borra. Un cliente tiene un solo contacto programado a la vez: al programar
/// uno nuevo, el anterior pasa a cumplido.
/// </summary>
public class GestionCliente
{
    public int Id { get; set; }

    public int ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    /// <summary>Cuándo se hizo el contacto (instante, UTC).</summary>
    public DateTime Fecha { get; set; } = DateTime.UtcNow;

    public string TipoContacto { get; set; } = Models.TipoContacto.Llamada;
    public string Resultado { get; set; } = ResultadoGestion.Seguimiento;

    public string? Comentario { get; set; }

    /// <summary>El día y la hora del siguiente contacto (instante, UTC).</summary>
    public DateTime? ProximoSeguimiento { get; set; }

    /// <summary>Cómo será ese contacto; puede ser distinto del de esta gestión.</summary>
    public string? ProximoTipoContacto { get; set; }

    /// <summary>Qué se hará en ese contacto ("Enviar cotización").</summary>
    public string? ProximaAccion { get; set; }

    /// <summary>Nulo si no se dejó un siguiente contacto.</summary>
    public string? SeguimientoEstado { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
