namespace Backend.Dtos.Requests;

/// <summary>Plata que se le da a un trabajador a cuenta de su sueldo.</summary>
public class CrearAdelantoRequest
{
    public int EmpleadoId { get; set; }
    public decimal Monto { get; set; }

    /// <summary>El día en que se le dio. Sin fecha, hoy.</summary>
    public DateTime? Fecha { get; set; }

    /// <summary>De qué cuenta sale la plata: una caja, un banco o la Bóveda.</summary>
    public int CuentaFinancieraId { get; set; }

    /// <summary>Cualquier día de la primera semana en que se descuenta. Sin fecha, la semana en que se le dio.</summary>
    public DateTime? DescontarDesde { get; set; }

    /// <summary>Cuánto por semana. Nulo: todo de una vez.</summary>
    public decimal? CuotaSemanal { get; set; }

    public string? Observacion { get; set; }
}

/// <summary>Cambiar cómo se descuenta lo que falta: desde qué semana y de a cuánto.</summary>
public class PlanAdelantoRequest
{
    public DateTime DescontarDesde { get; set; }

    /// <summary>Cuánto por semana. Nulo: todo de una vez.</summary>
    public decimal? CuotaSemanal { get; set; }
}
