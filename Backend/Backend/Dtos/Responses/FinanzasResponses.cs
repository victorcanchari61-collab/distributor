namespace Backend.Dtos.Responses;

public class MetodoPagoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;

    /// <summary>EFECTIVO, BILLETERA_DIGITAL o TRANSFERENCIA.</summary>
    public string Tipo { get; set; } = string.Empty;

    public string? Banco { get; set; }
    public string? NumeroCuenta { get; set; }
    public string? Cci { get; set; }
    public string? Titular { get; set; }

    public bool Activo { get; set; }

    /// <summary>Cuántos documentos ya lo usan. Si hay alguno, no se elimina.</summary>
    public int Usos { get; set; }
}

/// <summary>
/// Lo que hace falta para arquear un día: lo cobrado y pagado en efectivo
/// según los documentos, y si ya se registró un cierre para ese día.
/// </summary>
public class ArqueoResumenResponse
{
    public DateTime Fecha { get; set; }

    /// <summary>Efectivo cobrado en notas de venta ese día (pagos válidos, no anulados).</summary>
    public decimal CobradoEfectivo { get; set; }

    /// <summary>Efectivo pagado en compras ese día (pagos válidos, no anulados).</summary>
    public decimal PagadoEfectivo { get; set; }

    /// <summary>CobradoEfectivo - PagadoEfectivo: lo que debería haber en caja.</summary>
    public decimal MontoEsperado { get; set; }

    /// <summary>El cierre ya registrado para este día, si existe.</summary>
    public ArqueoCajaResponse? Arqueo { get; set; }
}

public class ArqueoCajaResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public decimal MontoEsperado { get; set; }
    public decimal MontoContado { get; set; }

    /// <summary>MontoContado - MontoEsperado. Negativo es faltante, positivo es sobrante.</summary>
    public decimal Diferencia { get; set; }

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }
    public DateTime FechaCreacion { get; set; }
}
