namespace Backend.Models;

public class Cliente
{
    public int Id { get; set; }

    /// <summary>DNI, RUC o codigo interno. Ver <see cref="TipoDocumento"/>.</summary>
    public string Documento { get; set; } = string.Empty;

    /// <summary>DNI / RUC / CODIGO, deducido del largo del documento.</summary>
    public string TipoDoc { get; set; } = TipoDocumento.Codigo;

    /// <summary>
    /// El otro documento del cliente cuando tiene DNI y RUC a la vez (una persona con negocio): si el principal es DNI, este
    /// es el RUC, y al revés. La factura usa el RUC y la boleta, el DNI.
    /// </summary>
    public string? DocumentoAlterno { get; set; }

    /// <summary>DNI o RUC, deducido del largo de <see cref="DocumentoAlterno"/>.</summary>
    public string? TipoDocAlterno { get; set; }

    /// <summary>
    /// El nombre que va con <see cref="DocumentoAlterno"/>, porque no siempre es el mismo que <see cref="Nombre"/>: si el
    /// segundo documento es un RUC 20 (una empresa: EIRL, SAC...), su razón social es la de la empresa, no la de la
    /// persona del DNI. Vacío usa <see cref="Nombre"/>, que es lo correcto con un RUC 10 (persona natural): su razón social
    /// es el mismo nombre del DNI.
    /// </summary>
    public string? NombreAlterno { get; set; }

    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }

    /// <summary>Distrito del ubigeo oficial (INEI/RENIEC).</summary>
    public int? DistritoId { get; set; }
    public Distrito? Distrito { get; set; }

    public string? Telefono { get; set; }
    public string? Email { get; set; }

    /// <summary>Dia en que el vendedor visita al cliente.</summary>
    public string? DiaVisita { get; set; }

    /// <summary>Ruta de reparto a la que pertenece.</summary>
    public int? RutaId { get; set; }
    public Ruta? Ruta { get; set; }

    /// <summary>El mercado, zona o punto de reparto donde está el puesto.</summary>
    public int? MercadoId { get; set; }
    public Mercado? Mercado { get; set; }

    /// <summary>
    /// Quién atiende a este cliente.
    ///
    /// Es un Usuario cualquiera y no se limita a los del rol Vendedor a
    /// propósito: en una distribuidora chica al cliente lo atiende quien toca
    /// — el dueño, el que reparte, la persona del mostrador — y amarrarlo a un
    /// rol obligaría a inventar roles para poder asignar a alguien.
    /// </summary>
    public int? VendedorId { get; set; }
    public Usuario? Vendedor { get; set; }

    /// <summary>
    /// Con qué lista se le cobra.
    ///
    /// Vacío usa la predeterminada. Existe porque elegir "Mayorista" a mano en
    /// cada pedido no se sostiene: basta que alguien se olvide una vez para
    /// que el mayorista pague precio de menudeo.
    /// </summary>
    public int? ListaPrecioId { get; set; }
    public ListaPrecio? ListaPrecio { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
