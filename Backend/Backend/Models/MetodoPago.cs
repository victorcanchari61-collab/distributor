namespace Backend.Models;

/// <summary>
/// Un medio de pago o cobro: efectivo, transferencia, tarjeta. Catálogo
/// compartido por compras, cuentas por cobrar, cuentas por pagar, mis cobros
/// y el arqueo diario — se declara una sola vez y todos lo reusan.
/// </summary>
public class MetodoPago
{
    public int Id { get; set; }

    public string Nombre { get; set; } = string.Empty;

    public bool Activo { get; set; } = true;
}
