namespace Backend.Models;

public static class TipoMovimientoOperativo
{
    /// <summary>Plata que entra sin venir de una venta: aporte de capital, venta de un activo, otros.</summary>
    public const string Ingreso = "INGRESO";

    /// <summary>Planilla, alquiler, servicios: gasto del negocio, no de una compra de mercadería.</summary>
    public const string Egreso = "EGRESO";

    public static readonly string[] Todos = [Ingreso, Egreso];
}

/// <summary>
/// Si un movimiento viene del giro del negocio o no. Lo operativo dice si el
/// negocio gana; lo no operativo (aportes, retiros, activos, préstamos) mueve
/// la caja pero no es ganancia ni pérdida.
/// </summary>
public static class OrigenMovimiento
{
    public const string Operativo = "OPERATIVO";
    public const string NoOperativo = "NO_OPERATIVO";

    public static readonly string[] Todos = [Operativo, NoOperativo];
}

/// <summary>
/// La categoría de un ingreso o egreso registrado a mano (en pantalla,
/// "Categoría"): pasaje, planilla, aporte de capital... Conserva el nombre de
/// clase y tabla de cuando solo eran motivos de gasto de ruta.
///
/// Es catálogo y no una lista fija porque cada distribuidora gasta en cosas
/// distintas.
/// </summary>
public class MotivoGasto
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>INGRESO o EGRESO: con qué tipo de movimiento se puede usar.</summary>
    public string Tipo { get; set; } = TipoMovimientoOperativo.Egreso;

    /// <summary>OPERATIVO si es del giro del negocio; NO_OPERATIVO si no (aportes, retiros, activos).</summary>
    public string Origen { get; set; } = OrigenMovimiento.Operativo;

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Un gasto fijo que se repite cada mes (alquiler, luz, agua, internet). No es
/// una fila que se genera sola cada mes: es una plantilla, y "qué está
/// pendiente" se calcula al vuelo comparando su día de vencimiento contra si
/// ya existe un MovimientoOperativo de este mes que la referencie.
/// </summary>
public class GastoRecurrente
{
    public int Id { get; set; }

    public string Nombre { get; set; } = string.Empty;

    public int MotivoGastoId { get; set; }
    public MotivoGasto? MotivoGasto { get; set; }

    /// <summary>Referencial: el monto real al pagar puede variar (la luz no es siempre igual).</summary>
    public decimal MontoEstimado { get; set; }

    /// <summary>Día del mes en que vence, 1-31.</summary>
    public int DiaVencimiento { get; set; }

    /// <summary>De qué cuenta suele salir, para pre-llenar el pago. No obliga.</summary>
    public int? CuentaFinancieraSugeridaId { get; set; }
    public CuentaFinanciera? CuentaFinancieraSugerida { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Un ingreso no ligado a venta (préstamo, aporte de capital) o un egreso
/// operativo (planilla, alquiler, servicios) — no una compra de mercadería.
/// Postea un MovimientoCuenta contra la cuenta elegida.
/// </summary>
public class MovimientoOperativo
{
    public int Id { get; set; }

    public int CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    public string Tipo { get; set; } = TipoMovimientoOperativo.Egreso;

    public int MotivoGastoId { get; set; }
    public MotivoGasto? MotivoGasto { get; set; }

    public decimal Monto { get; set; }
    public DateTime Fecha { get; set; } = DateTime.UtcNow;
    public string? Descripcion { get; set; }

    /// <summary>Si nació de pagar una plantilla recurrente. Null en un ingreso o un gasto suelto.</summary>
    public int? GastoRecurrenteId { get; set; }
    public GastoRecurrente? GastoRecurrente { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public bool Anulado { get; set; }

    /// <summary>El movimiento del libro mayor que este generó (o su reversa, si se anuló).</summary>
    public int? MovimientoCuentaId { get; set; }
}
