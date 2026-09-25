namespace Backend.Dtos.Requests;

public abstract class MetodoPagoRequestBase
{
    public string Nombre { get; set; } = string.Empty;

    /// <summary>EFECTIVO, BILLETERA_DIGITAL o TRANSFERENCIA.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>El número de celular asociado. Obligatorio solo en Billetera digital.</summary>
    public string? Numero { get; set; }

    /// <summary>A qué cuenta financiera va la plata. Obligatorio salvo en Efectivo.</summary>
    public int? CuentaFinancieraId { get; set; }
}

public class CreateMetodoPagoRequest : MetodoPagoRequestBase;

public class UpdateMetodoPagoRequest : MetodoPagoRequestBase
{
    public bool Activo { get; set; } = true;
}

/// <summary>Cierra la caja de un día: cuánto se contó de verdad.</summary>
