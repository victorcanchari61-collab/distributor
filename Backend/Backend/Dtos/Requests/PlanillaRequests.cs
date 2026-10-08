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

    /// <summary>
    /// Cuánto descontarle de sus adelantos esta semana: más, menos o 0 para nada. Nulo: lo que le
    /// toca según cómo se pactó cada uno. Lo que no se descuenta queda para la semana siguiente.
    /// </summary>
    public decimal? Adelantos { get; set; }
}

public class PagarPlanillaRequest
{
    /// <summary>De qué cuenta sale el pago.</summary>
    public int CuentaFinancieraId { get; set; }

    /// <summary>
    /// Pagar aunque haya días sin marcar en la asistencia: esos días se pagan como trabajados.
    /// Sin esto, el pago se rechaza mientras falte pasar lista.
    /// </summary>
    public bool ConDiasSinMarcar { get; set; }
}
