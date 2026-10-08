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

    /// <summary>Lo que se descuenta de adelantos esta semana, de todos.</summary>
    public decimal TotalAdelantos { get; set; }
    public decimal TotalNeto { get; set; }

    /// <summary>
    /// Los días de lunes a sábado en que a alguien de la planilla le falta su marca. Solo en borrador:
    /// se pagarían como trabajados, así que hay que pasar lista antes de pagar.
    /// </summary>
    public List<DateTime> FechasSinMarcar { get; set; } = [];

    public List<PlanillaDetalleResponse> Detalle { get; set; } = [];
}

public class PlanillaDetalleResponse
{
    public int Id { get; set; }
    public int EmpleadoId { get; set; }
    public string Empleado { get; set; } = string.Empty;

    /// <summary>Su DNI o código: va en la boleta, junto a su firma.</summary>
    public string? Documento { get; set; }
    public string? Cargo { get; set; }
    public decimal SueldoSemanal { get; set; }
    public int DiasNoPagados { get; set; }

    /// <summary>Días que se le pagan sin tener marca de asistencia.</summary>
    public int DiasSinMarcar { get; set; }
    public decimal DescuentoInasistencias { get; set; }
    public decimal ExtraFeriados { get; set; }
    public decimal Bonos { get; set; }
    public decimal OtrosDescuentos { get; set; }
    public string? NotaAjuste { get; set; }
    public decimal DescuentoFaltantes { get; set; }

    /// <summary>Lo que se le descuenta esta semana de sus adelantos.</summary>
    public decimal DescuentoAdelantos { get; set; }

    /// <summary>Lo que le toca según cómo se pactaron sus adelantos.</summary>
    public decimal AdelantosSugerido { get; set; }

    /// <summary>Lo que se decidió a mano para esta semana; nulo si va lo sugerido.</summary>
    public decimal? AdelantosManual { get; set; }

    /// <summary>Todo lo que debe de adelantos.</summary>
    public decimal AdelantosSaldo { get; set; }
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
