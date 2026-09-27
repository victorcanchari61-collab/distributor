namespace Backend.Dtos.Responses;

public class CierreCajaResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int UsuarioId { get; set; }
    public string Usuario { get; set; } = string.Empty;
    public string Caja { get; set; } = string.Empty;

    public decimal SaldoSistema { get; set; }
    public decimal Billetes { get; set; }
    public decimal Monedas { get; set; }
    public decimal Contado { get; set; }

    /// <summary>Negativa: faltó plata. Positiva: sobró.</summary>
    public decimal Diferencia { get; set; }

    public int CuentaDestinoId { get; set; }
    public string CuentaDestino { get; set; } = string.Empty;
    public string? Observacion { get; set; }
    public bool Anulado { get; set; }

    /// <summary>Solo si hubo faltante: cómo va su descuento en planilla.</summary>
    public DescuentoFaltanteResponse? Descuento { get; set; }

    /// <summary>
    /// El usuario no tiene un empleado vinculado: su faltante no puede entrar en
    /// ninguna planilla hasta que se lo vincule en Usuarios.
    /// </summary>
    public bool SinEmpleado { get; set; }
}

public class DescuentoFaltanteResponse
{
    public int Id { get; set; }
    public decimal Monto { get; set; }
    public decimal MontoAplicado { get; set; }
    public decimal Saldo { get; set; }
    public string Estado { get; set; } = string.Empty;
}

/// <summary>
/// Un cobro por Yape, Plin o transferencia, para buscarlo en el banco por su
/// número de operación y marcarlo verificado o rechazado.
/// </summary>
public class CobroDigitalResponse
{
    /// <summary>El id del pago de la venta.</summary>
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int NotaVentaId { get; set; }
    public string Documento { get; set; } = string.Empty;
    public string? Cliente { get; set; }

    /// <summary>Quién lo cobró: a quien se le descuenta si no aparece.</summary>
    public int? UsuarioId { get; set; }
    public string? Usuario { get; set; }

    public string MetodoPago { get; set; } = string.Empty;

    /// <summary>BILLETERA_DIGITAL o TRANSFERENCIA.</summary>
    public string MetodoTipo { get; set; } = string.Empty;

    /// <summary>La cuenta donde tiene que aparecer.</summary>
    public string? Cuenta { get; set; }

    public string? NumeroOperacion { get; set; }
    public decimal Monto { get; set; }

    /// <summary>PENDIENTE, VERIFICADO o RECHAZADO.</summary>
    public string Estado { get; set; } = string.Empty;
    public string? VerificadoPor { get; set; }
    public DateTime? VerificadoEn { get; set; }
    public string? Observacion { get; set; }

    /// <summary>Solo si se rechazó: cómo va su descuento en planilla.</summary>
    public DescuentoFaltanteResponse? Descuento { get; set; }

    /// <summary>Se rechazó pero quien cobró no tiene empleado: su descuento no entra en planilla.</summary>
    public bool SinEmpleado { get; set; }
}

/// <summary>Una cuenta a la que se puede entregar lo contado: solo lo justo para elegirla, sin su saldo.</summary>
public class CuentaDestinoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Naturaleza { get; set; } = string.Empty;
}
