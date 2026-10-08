namespace Backend.Models;

public static class EstadoAdelanto
{
    /// <summary>Todavía tiene saldo por descontar en planilla.</summary>
    public const string Pendiente = "PENDIENTE";

    /// <summary>Ya se descontó todo.</summary>
    public const string Descontado = "DESCONTADO";

    /// <summary>Se registró mal: la plata volvió a la cuenta de donde salió.</summary>
    public const string Anulado = "ANULADO";
}

/// <summary>
/// Plata que se le da a un trabajador a cuenta de su sueldo, y que se le descuenta en la planilla.
///
/// Es una sola cosa para el adelanto y el préstamo: lo que cambia es cómo se descuenta. Sin cuota,
/// todo de una vez; con cuota, de a esa cantidad por semana. Y desde qué semana: la misma en que se
/// le dio, la siguiente o la que se elija. En cada planilla se puede ajustar cuánto se le descuenta
/// esa semana (más, menos o nada); lo que no se descuenta queda para la siguiente.
/// </summary>
public class AdelantoEmpleado
{
    public int Id { get; set; }

    public int EmpleadoId { get; set; }
    public Empleado? Empleado { get; set; }

    /// <summary>El día en que se le dio, en hora de Perú.</summary>
    public DateTime Fecha { get; set; }

    public decimal Monto { get; set; }

    /// <summary>El lunes de la primera semana en que se descuenta.</summary>
    public DateTime DescontarDesde { get; set; }

    /// <summary>Cuánto por semana. Nulo: todo de una vez.</summary>
    public decimal? CuotaSemanal { get; set; }

    /// <summary>Lo ya descontado en planillas pagadas.</summary>
    public decimal MontoDescontado { get; set; }

    /// <summary>Lo que falta descontar.</summary>
    public decimal Saldo => Monto - MontoDescontado;

    public string Estado { get; set; } = EstadoAdelanto.Pendiente;

    /// <summary>De qué cuenta salió la plata.</summary>
    public int CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    /// <summary>El egreso de esa cuenta. Se reversa si el adelanto se anula.</summary>
    public int? MovimientoCuentaId { get; set; }

    public string? Observacion { get; set; }

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}

/// <summary>Cuánto de un adelanto se descontó en una línea de planilla pagada.</summary>
public class PlanillaAdelanto
{
    public int Id { get; set; }

    public int PlanillaDetalleId { get; set; }
    public PlanillaDetalle? PlanillaDetalle { get; set; }

    public int AdelantoEmpleadoId { get; set; }
    public AdelantoEmpleado? AdelantoEmpleado { get; set; }

    public decimal Monto { get; set; }
}
