namespace Backend.Models;

public static class EstadoFinanciamiento
{
    /// <summary>Todavía se debe algo.</summary>
    public const string Vigente = "VIGENTE";

    /// <summary>Se terminó de pagar.</summary>
    public const string Cancelado = "CANCELADO";

    /// <summary>Se registró por error: su ingreso se reversó.</summary>
    public const string Anulado = "ANULADO";
}

/// <summary>
/// Un préstamo que recibió el negocio (de un banco o de una persona). La plata
/// entra a una cuenta como movimiento no operativo y queda como deuda: el saldo
/// baja con cada pago hasta cancelarse.
///
/// Se llama así y no "Préstamo" porque ese nombre ya lo usa inventario para
/// prestar mercadería entre almacenes.
/// </summary>
public class Financiamiento
{
    public int Id { get; set; }

    /// <summary>Quién prestó: "BCP", "Juan Pérez".</summary>
    public string Acreedor { get; set; } = string.Empty;

    public string? Descripcion { get; set; }

    public DateTime Fecha { get; set; }

    public decimal MontoRecibido { get; set; }

    /// <summary>Lo que se pactó devolver en total, con intereses. Si no hay intereses, igual a lo recibido.</summary>
    public decimal TotalADevolver { get; set; }

    /// <summary>A qué cuenta entró la plata.</summary>
    public int CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    /// <summary>El ingreso en esa cuenta (o su reversa, si se anuló).</summary>
    public int? MovimientoCuentaId { get; set; }

    public string Estado { get; set; } = EstadoFinanciamiento.Vigente;

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<PagoFinanciamiento> Pagos { get; set; } = [];

    public decimal Pagado => Pagos.Where(p => !p.Anulado).Sum(p => p.Monto);

    public decimal Saldo => TotalADevolver - Pagado;
}

/// <summary>Un pago (cuota o abono) de un préstamo recibido. Es un solo monto: no se separa capital de interés.</summary>
public class PagoFinanciamiento
{
    public int Id { get; set; }

    public int FinanciamientoId { get; set; }
    public Financiamiento? Financiamiento { get; set; }

    public DateTime Fecha { get; set; }
    public decimal Monto { get; set; }

    /// <summary>De qué cuenta salió.</summary>
    public int CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    public int? MovimientoCuentaId { get; set; }

    public bool Anulado { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public string? Observacion { get; set; }
}
