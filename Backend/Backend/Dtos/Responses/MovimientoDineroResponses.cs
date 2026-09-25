namespace Backend.Dtos.Responses;

/// <summary>
/// Una fila del kardex del dinero: un movimiento de cualquier caja o banco,
/// con lo que lo generó dicho en palabras y si es operativo o no.
/// </summary>
public class MovimientoDineroResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int CuentaFinancieraId { get; set; }
    public string Cuenta { get; set; } = string.Empty;
    public string Naturaleza { get; set; } = string.Empty;

    /// <summary>INGRESO o EGRESO para la cuenta.</summary>
    public string Tipo { get; set; } = string.Empty;
    public decimal Monto { get; set; }

    /// <summary>El saldo de esa cuenta justo después de este movimiento.</summary>
    public decimal SaldoResultante { get; set; }

    public string DocumentoOrigen { get; set; } = string.Empty;

    /// <summary>Qué fue, en palabras: "Cobro NV-0004 — cliente", "Préstamo de BCP".</summary>
    public string Concepto { get; set; } = string.Empty;

    /// <summary>La categoría que lo clasifica. Vacía en lo interno (transferencias, saldo inicial).</summary>
    public string? Categoria { get; set; }

    /// <summary>OPERATIVO, NO_OPERATIVO o INTERNO (plata que solo se mueve entre cuentas propias).</summary>
    public string Origen { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    /// <summary>Si después se anuló: tiene una reversa.</summary>
    public bool Anulado { get; set; }

    /// <summary>Si esta fila ES la reversa de otra. Resta de la categoría de aquella.</summary>
    public bool EsReversa { get; set; }

    /// <summary>El ingreso o egreso registrado a mano detrás de esta fila, si lo hay.</summary>
    public int? MovimientoOperativoId { get; set; }

    /// <summary>Si se puede anular desde aquí: registrado a mano, vigente y no del sistema.</summary>
    public bool Anulable { get; set; }
}
