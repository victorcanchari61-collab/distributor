namespace Backend.Models;

public static class EstadoPlanilla
{
    /// <summary>Armada pero sin pagar: se puede recalcular y ajustar.</summary>
    public const string Borrador = "BORRADOR";

    public const string Pagada = "PAGADA";

    /// <summary>Se registró mal: si estaba pagada, sus movimientos se reversaron.</summary>
    public const string Anulada = "ANULADA";
}

/// <summary>
/// El pago de una semana (lunes a domingo) a los trabajadores con sueldo.
/// Solo hay una planilla vigente por semana.
/// </summary>
public class PlanillaSemanal
{
    public int Id { get; set; }

    /// <summary>El lunes de la semana.</summary>
    public DateTime Desde { get; set; }

    /// <summary>El domingo de la semana.</summary>
    public DateTime Hasta { get; set; }

    public string Estado { get; set; } = EstadoPlanilla.Borrador;

    /// <summary>De qué cuenta salió el pago. Nula mientras no se pague.</summary>
    public int? CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    public DateTime? FechaPago { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    public List<PlanillaDetalle> Detalle { get; set; } = [];
}

/// <summary>Lo que le toca a un empleado en una planilla semanal.</summary>
public class PlanillaDetalle
{
    public int Id { get; set; }

    public int PlanillaSemanalId { get; set; }
    public PlanillaSemanal? PlanillaSemanal { get; set; }

    public int EmpleadoId { get; set; }
    public Empleado? Empleado { get; set; }

    /// <summary>El sueldo semanal del empleado cuando se armó la planilla.</summary>
    public decimal SueldoSemanal { get; set; }

    /// <summary>Días de lunes a sábado que no se pagan: faltas, permisos o fuera de contrato.</summary>
    public int DiasNoPagados { get; set; }
    public decimal DescuentoInasistencias { get; set; }

    /// <summary>Lo que se suma por trabajar un feriado que paga doble o triple.</summary>
    public decimal ExtraFeriados { get; set; }

    public decimal Bonos { get; set; }
    public decimal OtrosDescuentos { get; set; }
    public string? NotaAjuste { get; set; }

    /// <summary>Lo que se le descuenta por faltantes de caja pendientes.</summary>
    public decimal DescuentoFaltantes { get; set; }

    /// <summary>Lo que le cuesta al negocio su trabajo de la semana: es el gasto de planilla.</summary>
    public decimal CostoLaboral => Math.Max(0, SueldoSemanal - DescuentoInasistencias + ExtraFeriados + Bonos - OtrosDescuentos);

    /// <summary>Lo que se le paga de verdad.</summary>
    public decimal Neto => CostoLaboral - DescuentoFaltantes;

    /// <summary>El egreso de planilla (movimiento operativo) al pagar.</summary>
    public int? MovimientoOperativoId { get; set; }

    /// <summary>El ingreso por el faltante descontado, en la misma cuenta del pago.</summary>
    public int? MovimientoRecuperoId { get; set; }

    public List<PlanillaDescuento> Descuentos { get; set; } = [];
}

/// <summary>Cuánto de un faltante se descontó en una línea de planilla pagada.</summary>
public class PlanillaDescuento
{
    public int Id { get; set; }

    public int PlanillaDetalleId { get; set; }
    public PlanillaDetalle? PlanillaDetalle { get; set; }

    public int DescuentoFaltanteId { get; set; }
    public DescuentoFaltante? DescuentoFaltante { get; set; }

    public decimal Monto { get; set; }
}
