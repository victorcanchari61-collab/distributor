namespace Backend.Models;

/// <summary>
/// Hasta cuándo vale un permiso concedido a una persona suelta.
/// </summary>
public enum AlcancePermiso
{
    /// <summary>
    /// Se gasta al usarlo. Para el caso tipico: "necesito anular ESTA nota de
    /// venta que emiti mal", no "quiero poder anular".
    /// </summary>
    UnaVez = 0,

    /// <summary>Vale hasta una fecha y hora. Para cubrir un turno o un dia.</summary>
    Temporal = 1,

    /// <summary>
    /// No vence. Es la excepcion que en realidad deberia acabar en el rol; se
    /// deja porque a veces una sola persona hace algo que nadie mas hace.
    /// </summary>
    Permanente = 2,
}

/// <summary>
/// Un permiso que tiene una persona y su rol no le da.
///
/// El rol cubre el caso general — todos los vendedores hacen lo mismo — pero
/// no el particular: un vendedor concreto necesita corregir un pedido suyo hoy.
/// Sin esto la unica salida era subirlo de rol, que le daba de golpe todo lo
/// que ese rol puede hacer y ya no se lo quitaba nadie.
///
/// Solo suma: no existe la excepcion que QUITA algo. Restar por persona
/// convertiria cada "¿por que no puede?" en revisar dos sitios en vez de uno,
/// y lo que de verdad hace falta es lo contrario — soltar una accion puntual
/// sin tocar el rol.
/// </summary>
public class UsuarioPermiso
{
    public int Id { get; set; }

    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public string Submodulo { get; set; } = string.Empty;
    public string Accion { get; set; } = string.Empty;

    public AlcancePermiso Alcance { get; set; }

    /// <summary>Cuando deja de valer. Solo para <see cref="AlcancePermiso.Temporal"/>.</summary>
    public DateTime? ExpiraEn { get; set; }

    /// <summary>
    /// Veces que ya se uso. Solo cuenta para <see cref="AlcancePermiso.UnaVez"/>,
    /// que vale mientras esto siga en cero.
    ///
    /// Se guarda el consumo en vez de borrar la fila para que quede el rastro:
    /// quien pidio, quien aprobo y si llego a usarlo.
    /// </summary>
    public int Usos { get; set; }

    /// <summary>Quien lo concedio. Nulo si el usuario fue eliminado despues.</summary>
    public int? OtorgadoPorId { get; set; }

    /// <summary>Por que se pidio. Lo escribe quien solicita, no quien aprueba.</summary>
    public string? Motivo { get; set; }

    public DateTime FechaOtorgado { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Retirado a mano antes de que venciera o se gastara. No se borra la fila
    /// por lo mismo de siempre: el historial de quien tuvo que es lo que se
    /// consulta cuando algo sale mal.
    /// </summary>
    public bool Revocado { get; set; }

    /// <summary>Si ahora mismo sirve para algo.</summary>
    public bool Vigente(DateTime ahora) => !Revocado && Alcance switch
    {
        AlcancePermiso.UnaVez => Usos == 0,
        AlcancePermiso.Temporal => ExpiraEn is not null && ExpiraEn > ahora,
        _ => true,
    };
}
