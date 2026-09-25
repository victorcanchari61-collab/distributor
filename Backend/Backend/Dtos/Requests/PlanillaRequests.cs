namespace Backend.Dtos.Requests;

/// <summary>Arma (o recalcula) la planilla de la semana que contiene esta fecha.</summary>
public class GenerarPlanillaRequest
{
    public DateTime Semana { get; set; }
}

/// <summary>Bonos y descuentos a mano de una línea, mientras la planilla está en borrador.</summary>
public class AjustePlanillaRequest
{
    public decimal Bonos { get; set; }
    public decimal OtrosDescuentos { get; set; }
    public string? Nota { get; set; }
}

public class PagarPlanillaRequest
{
    /// <summary>De qué cuenta sale el pago.</summary>
    public int CuentaFinancieraId { get; set; }
}
