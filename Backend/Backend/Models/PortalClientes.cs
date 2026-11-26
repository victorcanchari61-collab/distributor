namespace Backend.Models;

/// <summary>Para qué sirve el enlace de un solo uso que tiene una cuenta del portal.</summary>
public static class TipoTokenAcceso
{
    /// <summary>El vendedor lo invitó: con el enlace elige su usuario y su contraseña.</summary>
    public const string Invitacion = "INVITACION";

    /// <summary>Olvidó su contraseña: con el enlace elige otra.</summary>
    public const string Recuperacion = "RECUPERACION";
}

/// <summary>
/// La cuenta con la que un cliente entra al portal (/portal) para mandar cotizaciones.
///
/// Es aparte de <see cref="Usuario"/> a propósito: un cliente no es personal de la empresa, no tiene rol ni permisos y
/// no puede entrar al panel. Su sesión es un token con otra audiencia que el resto del API rechaza.
///
/// La crea el vendedor al invitarlo (sin usuario ni contraseña todavía); el cliente la completa con el enlace que le
/// llega por WhatsApp. Una por cliente.
/// </summary>
public class AccesoCliente
{
    public int Id { get; set; }

    public int ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    /// <summary>El usuario que eligió, en minúsculas. Vacío mientras no active la invitación.</summary>
    public string? Usuario { get; set; }

    /// <summary>Vacío mientras no active la invitación.</summary>
    public string? PasswordHash { get; set; }

    /// <summary>Desactivado no entra, y las sesiones que tenía abiertas dejan de valer.</summary>
    public bool Activo { get; set; } = true;

    /// <summary>
    /// El enlace de un solo uso vigente (invitación o recuperación), guardado como SHA-256: quien lea la base no
    /// puede usarlo. Uno a la vez: pedir otro reemplaza al anterior.
    /// </summary>
    public string? TokenHash { get; set; }

    /// <summary>Ver <see cref="TipoTokenAcceso"/>.</summary>
    public string? TokenTipo { get; set; }

    public DateTime? TokenExpira { get; set; }

    /// <summary>
    /// Va dentro del token de sesión: cambiar la contraseña o desactivar la cuenta lo sube, y las sesiones abiertas
    /// con el valor anterior dejan de valer (en todos los celulares donde había entrado).
    /// </summary>
    public int VersionSesion { get; set; } = 1;

    public DateTime? FechaInvitacion { get; set; }
    public int? InvitadoPorId { get; set; }
    public Usuario? InvitadoPor { get; set; }

    public DateTime? FechaActivacion { get; set; }
    public DateTime? UltimoIngreso { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Un producto que el cliente marcó en el portal con el corazón: lo que pide siempre. El catálogo del portal tiene el
/// filtro "Mis favoritos" para armar la cotización de la semana sin buscar producto por producto. Se guarda en el
/// servidor (no en el celular): lo ve igual desde cualquier teléfono.
/// </summary>
public class ClienteFavorito
{
    public int Id { get; set; }

    public int ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;
}

public static class EstadoCotizacion
{
    /// <summary>La mandó el cliente y espera a que el vendedor la jale a un pedido.</summary>
    public const string EnEspera = "EN_ESPERA";

    /// <summary>El vendedor la jaló: ya hay un pedido que salió de ella.</summary>
    public const string Atendida = "ATENDIDA";

    /// <summary>El vendedor no la va a atender (con su motivo).</summary>
    public const string Descartada = "DESCARTADA";

    /// <summary>El mismo cliente la retiró antes de que la atendieran.</summary>
    public const string Cancelada = "CANCELADA";
}

/// <summary>
/// Lo que un cliente arma en el portal con el catálogo y le manda a su vendedor. No es un pedido: el pedido lo crea el
/// vendedor, "jalando" la cotización desde el formulario de pedido (que la deja <see cref="EstadoCotizacion.Atendida"/>
/// y guarda en el pedido de cuál salió).
///
/// Los precios son los de la lista del cliente al momento de mandarla: referenciales. El precio que vale es el que
/// quede en el pedido.
/// </summary>
public class Cotizacion
{
    public int Id { get; set; }

    /// <summary>"CT-0001".</summary>
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public Cliente? Cliente { get; set; }

    /// <summary>A quién le llegó: el vendedor del cliente cuando la mandó.</summary>
    public int? VendedorId { get; set; }
    public Usuario? Vendedor { get; set; }

    /// <summary>La lista con la que se calcularon los precios.</summary>
    public int? ListaPrecioId { get; set; }
    public ListaPrecio? ListaPrecio { get; set; }

    public DateTime Fecha { get; set; } = DateTime.UtcNow;
    public string Estado { get; set; } = EstadoCotizacion.EnEspera;

    /// <summary>Lo que el cliente quiso agregar: "para el jueves", "si no hay Primor, Cocinero".</summary>
    public string? Nota { get; set; }

    public decimal Total { get; set; }

    /// <summary>Cuándo se atendió, descartó o canceló.</summary>
    public DateTime? FechaCierre { get; set; }

    /// <summary>Quién la atendió o la descartó. Vacío si la canceló el cliente.</summary>
    public int? CerradaPorId { get; set; }
    public Usuario? CerradaPor { get; set; }

    /// <summary>Por qué se descartó: se le muestra al cliente.</summary>
    public string? MotivoDescarte { get; set; }

    public List<CotizacionDetalle> Detalle { get; set; } = [];
}

public class CotizacionDetalle
{
    public int Id { get; set; }

    public int CotizacionId { get; set; }
    public Cotizacion? Cotizacion { get; set; }

    public int ProductoId { get; set; }
    public Producto? Producto { get; set; }

    public int PresentacionId { get; set; }
    public ProductoPresentacion? Presentacion { get; set; }

    /// <summary>Cuántas presentaciones (sacos, cajas...).</summary>
    public decimal Cantidad { get; set; }

    /// <summary>Precio de UNA presentación, con el escalón que le tocaba por la cantidad.</summary>
    public decimal PrecioPresentacion { get; set; }

    public decimal Subtotal { get; set; }
}
