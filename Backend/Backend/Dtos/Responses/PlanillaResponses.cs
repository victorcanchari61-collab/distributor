namespace Backend.Dtos.Responses;

public class PlanillaResponse
{
    public int Id { get; set; }
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
    public string Estado { get; set; } = string.Empty;
    public int? CuentaFinancieraId { get; set; }
    public string? CuentaFinanciera { get; set; }
    public DateTime? FechaPago { get; set; }

    /// <summary>Suma del costo laboral: el gasto de planilla de la semana.</summary>
    public decimal TotalCostoLaboral { get; set; }
    public decimal TotalFaltantes { get; set; }
    public decimal TotalNeto { get; set; }

    public List<PlanillaDetalleResponse> Detalle { get; set; } = [];
}

public class PlanillaDetalleResponse
{
    public int Id { get; set; }
    public int EmpleadoId { get; set; }
    public string Empleado { get; set; } = string.Empty;
    public string? Cargo { get; set; }
    public decimal SueldoSemanal { get; set; }
    public int DiasNoPagados { get; set; }
    public decimal DescuentoInasistencias { get; set; }
    public decimal ExtraFeriados { get; set; }
    public decimal Bonos { get; set; }
    public decimal OtrosDescuentos { get; set; }
    public string? NotaAjuste { get; set; }
    public decimal DescuentoFaltantes { get; set; }
    public decimal CostoLaboral { get; set; }
    public decimal Neto { get; set; }
}

/// <summary>Una planilla en el historial de semanas.</summary>
public class PlanillaResumenResponse
{
    public int Id { get; set; }
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }
    public string Estado { get; set; } = string.Empty;
    public int Empleados { get; set; }
    public decimal TotalNeto { get; set; }
    public DateTime? FechaPago { get; set; }
}
