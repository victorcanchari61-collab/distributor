namespace Backend.Models;

/// <summary>Cómo se organiza un método de pago, según qué datos hacen falta para usarlo.</summary>
public static class TipoMetodoPago
{
    /// <summary>Billetes y monedas. No necesita banco ni cuenta.</summary>
    public const string Efectivo = "EFECTIVO";

    /// <summary>Yape, Plin y similares: se identifican por un número de celular.</summary>
    public const string BilleteraDigital = "BILLETERA_DIGITAL";

    /// <summary>Va a una cuenta bancaria concreta: banco, número y, si se tiene, CCI.</summary>
    public const string Transferencia = "TRANSFERENCIA";

    public static readonly string[] Todos = [Efectivo, BilleteraDigital, Transferencia];
}

/// <summary>
/// Un medio de pago o cobro. Catálogo compartido por compras, cuentas por
/// cobrar, cuentas por pagar, mis cobros y el arqueo diario — se declara una
/// sola vez y todos lo reusan.
///
/// Es solo un CANAL, no una cuenta con saldo: la plata de verdad vive en la
/// <see cref="CuentaFinanciera"/> a la que este método apunta. Efectivo no
/// apunta a ninguna fija — se resuelve según quién cobra (su arqueo del día) —
/// y por eso es el único tipo que no lleva <see cref="CuentaFinancieraId"/>.
/// Ver docs/finanzas-tesoreria.md, sección 0.
/// </summary>
public class MetodoPago
{
    public int Id { get; set; }

    public string Nombre { get; set; } = string.Empty;

    public string Tipo { get; set; } = TipoMetodoPago.Efectivo;

    /// <summary>
    /// A qué cuenta financiera va la plata. Obligatorio salvo en Efectivo, que
    /// no tiene una cuenta fija.
    /// </summary>
    public int? CuentaFinancieraId { get; set; }
    public CuentaFinanciera? CuentaFinanciera { get; set; }

    public bool Activo { get; set; } = true;
}
