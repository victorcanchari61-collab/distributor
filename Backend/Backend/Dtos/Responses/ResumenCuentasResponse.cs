namespace Backend.Dtos.Responses;

/// <summary>
/// Totales de las cuentas pendientes, calculados sobre TODAS y no sobre la
/// página visible: sumar las 20 filas cargadas daría una deuda equivocada.
/// </summary>
public class ResumenCuentasResponse
{
    /// <summary>Cuántos documentos siguen con saldo.</summary>
    public int Cuentas { get; set; }

    /// <summary>Lo que falta cobrar o pagar.</summary>
    public decimal TotalPendiente { get; set; }

    /// <summary>Lo facturado de esos documentos.</summary>
    public decimal TotalFacturado { get; set; }

    /// <summary>Lo ya cobrado o pagado de esos mismos documentos.</summary>
    public decimal TotalCubierto { get; set; }
}
