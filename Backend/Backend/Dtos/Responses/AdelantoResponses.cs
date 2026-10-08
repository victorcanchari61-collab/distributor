namespace Backend.Dtos.Responses;

/// <summary>Una fila de la lista de adelantos: solo lo que muestra la tabla.</summary>
public class AdelantoFilaResponse
{
    public int Id { get; set; }
    public int EmpleadoId { get; set; }
    public string Empleado { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }
    public decimal Monto { get; set; }
    public decimal Descontado { get; set; }
    public decimal Saldo { get; set; }

    /// <summary>El lunes de la primera semana en que se descuenta.</summary>
    public DateTime DescontarDesde { get; set; }

    /// <summary>Cuánto por semana. Nulo: todo de una vez.</summary>
    public decimal? CuotaSemanal { get; set; }

    public string Estado { get; set; } = string.Empty;

    /// <summary>De qué cuenta salió.</summary>
    public string? CuentaFinanciera { get; set; }
}

/// <summary>Un adelanto con lo descontado semana por semana.</summary>
public class AdelantoResponse : AdelantoFilaResponse
{
    public string? Cargo { get; set; }
    public string? Observacion { get; set; }
    public string? Usuario { get; set; }
    public DateTime FechaCreacion { get; set; }
    public List<AdelantoDescuentoResponse> Descuentos { get; set; } = [];
}

/// <summary>Lo descontado de un adelanto en una planilla pagada.</summary>
public class AdelantoDescuentoResponse
{
    public int PlanillaId { get; set; }
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
    public decimal Monto { get; set; }
    public DateTime? FechaPago { get; set; }
}

/// <summary>Las tarjetas de arriba.</summary>
public class ResumenAdelantosResponse
{
    /// <summary>Lo que falta descontar de todos los adelantos vigentes.</summary>
    public decimal SaldoPendiente { get; set; }

    /// <summary>Cuántos adelantos tienen todavía saldo.</summary>
    public int Vigentes { get; set; }

    /// <summary>A cuántos trabajadores se les está descontando algo.</summary>
    public int Empleados { get; set; }

    /// <summary>Lo entregado este mes (sin los anulados).</summary>
    public decimal EntregadoMes { get; set; }
}

/// <summary>Un empleado para darle un adelanto: con su sueldo y lo que ya debe.</summary>
public class EmpleadoAdelantoResponse
{
    public int Id { get; set; }
    public string NombreCompleto { get; set; } = string.Empty;
    public string? Cargo { get; set; }
    public decimal? SueldoSemanal { get; set; }

    /// <summary>Lo que todavía se le tiene que descontar de adelantos anteriores.</summary>
    public decimal SaldoAdelantos { get; set; }
}
