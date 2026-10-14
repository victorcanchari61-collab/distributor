namespace Backend.Dtos.Responses;

public class MetodoPagoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;

    /// <summary>
    /// Como se muestra al elegirlo para cobrar o pagar, con el dato completo de a dónde va la plata:
    /// "BCP · Cuenta corriente · 191-1234567-0-88 · Titular" en una transferencia,
    /// "Yape · Titular · 987654321" en una billetera. En efectivo es el nombre.
    /// </summary>
    public string Etiqueta { get; set; } = string.Empty;

    /// <summary>EFECTIVO, BILLETERA_DIGITAL o TRANSFERENCIA.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>El número de celular asociado, solo si Tipo es Billetera digital.</summary>
    public string? Numero { get; set; }

    /// <summary>A qué cuenta financiera va la plata. Null solo en Efectivo.</summary>
    public int? CuentaFinancieraId { get; set; }
    public string? CuentaFinanciera { get; set; }

    public bool Activo { get; set; }

    /// <summary>Cuántos documentos ya lo usan. Si hay alguno, no se elimina.</summary>
    public int Usos { get; set; }
}

/// <summary>
/// Lo que hace falta para arquear un día: lo cobrado y pagado en efectivo
/// según los documentos, y si ya se registró un cierre para ese día.
/// </summary>
