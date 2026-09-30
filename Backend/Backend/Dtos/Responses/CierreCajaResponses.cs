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

    /// <summary>
    /// Lo cobrado por Yape, Plin o transferencia desde el cierre anterior hasta
    /// este: no pasa por la caja, se verifica en el banco. Sin lo rechazado.
    /// </summary>
    public decimal Digital { get; set; }
    public int DigitalPorVerificar { get; set; }
    public int DigitalRechazados { get; set; }
}

/// <summary>
/// Todo lo de un cierre para revisar si cuadra: el efectivo que pasó por la
/// caja, lo cobrado digital que tiene que aparecer en el banco y los billetes
/// y monedas que se contaron.
/// </summary>
public class CierreDetalleResponse
{
    public CierreCajaResponse Cierre { get; set; } = new();

    /// <summary>Desde cuándo cuenta: el cierre anterior de esa caja. Nulo si es el primero.</summary>
    public DateTime? Desde { get; set; }

    /// <summary>Lo que la caja ya tenía al empezar el periodo (venía de antes).</summary>
    public decimal SaldoAnterior { get; set; }

    /// <summary>Vacío en los cierres de antes de guardar el desglose.</summary>
    public List<DenominacionResponse> Denominaciones { get; set; } = [];

    public List<MovimientoCierreResponse> Efectivo { get; set; } = [];
    public List<CobroDigitalResponse> Digitales { get; set; } = [];
}

public class DenominacionResponse
{
    public decimal Valor { get; set; }
    public int Cantidad { get; set; }
    public decimal Total { get; set; }
    public bool EsBillete { get; set; }
}

/// <summary>Un movimiento de la caja dentro del periodo de un cierre.</summary>
public class MovimientoCierreResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }
    public string Tipo { get; set; } = string.Empty;
    public decimal Monto { get; set; }
    public string DocumentoOrigen { get; set; } = string.Empty;

    /// <summary>La venta y el cliente, la categoría del gasto o lo escrito a mano.</summary>
    public string? Detalle { get; set; }

    public bool Anulado { get; set; }
    public bool EsReversa { get; set; }
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

    /// <summary>
    /// La Bóveda: el efectivo de la empresa. Se guarda como una cuenta de
    /// efectivo sin responsable, pero NO es una caja y no se muestra como tal.
    /// </summary>
    public bool EsBoveda { get; set; }
}
