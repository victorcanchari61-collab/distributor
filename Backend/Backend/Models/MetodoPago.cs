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
/// La forma cambia según el tipo: el efectivo no necesita nada más, pero una
/// billetera digital o una transferencia identifican una cuenta concreta, no
/// solo un medio genérico — "Transferencia" a secas no dice a qué banco va la
/// plata.
/// </summary>
public class MetodoPago
{
    public int Id { get; set; }

    public string Nombre { get; set; } = string.Empty;

    public string Tipo { get; set; } = TipoMetodoPago.Efectivo;

    /// <summary>Banco emisor. Solo aplica a transferencia (y a veces a billetera digital).</summary>
    public string? Banco { get; set; }

    /// <summary>Número de cuenta (transferencia) o de celular (billetera). No aplica a efectivo.</summary>
    public string? NumeroCuenta { get; set; }

    /// <summary>Código de cuenta interbancario, para transferencias entre bancos distintos.</summary>
    public string? Cci { get; set; }

    /// <summary>A nombre de quién está la cuenta o la billetera.</summary>
    public string? Titular { get; set; }

    public bool Activo { get; set; } = true;
}
