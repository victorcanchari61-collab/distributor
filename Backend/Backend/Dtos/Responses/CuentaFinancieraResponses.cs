namespace Backend.Dtos.Responses;

public class CuentaFinancieraResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Naturaleza { get; set; } = string.Empty;

    /// <summary>De quién es esta caja, si es la de un vendedor/repartidor.</summary>
    public int? UsuarioResponsableId { get; set; }
    public string? UsuarioResponsable { get; set; }

    public int? BancoId { get; set; }
    public string? Banco { get; set; }
    public string? NumeroCuenta { get; set; }
    public string? Cci { get; set; }
    public string? Titular { get; set; }

    public decimal SaldoActual { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }

    /// <summary>La caja de la empresa, sin responsable: solo efectivo.</summary>
    public bool EsBoveda { get; set; }
}

public class MovimientoCuentaResponse
{
    public int Id { get; set; }
    public int CuentaFinancieraId { get; set; }
    public string Tipo { get; set; } = string.Empty;
    public decimal Monto { get; set; }
    public decimal SaldoResultante { get; set; }
    public DateTime Fecha { get; set; }
    public string DocumentoOrigen { get; set; } = string.Empty;
    public int? OrigenId { get; set; }
    public int? MovimientoOrigenId { get; set; }
    public string? Usuario { get; set; }
    public string? Observacion { get; set; }

    /// <summary>Tiene una reversa: ya no cuenta, pero queda en el historial.</summary>
    public bool Anulado { get; set; }

    /// <summary>Es la reversa de otro movimiento.</summary>
    public bool EsReversa { get; set; }
}

/// <summary>
/// Un cobro o pago que alguien hizo por Yape, Plin o transferencia. No pasa
/// por su caja —la plata va directo al banco—, pero es suyo: lo cobró o lo
/// pagó él, y tiene que poder verlo.
/// </summary>
public class MovimientoDigitalResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    /// <summary>COBRO (de una venta) o PAGO (a un proveedor).</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>La nota de venta o la compra: NV-0001, CP-0003.</summary>
    public string Documento { get; set; } = string.Empty;

    /// <summary>El cliente o el proveedor.</summary>
    public string? Contraparte { get; set; }

    public string MetodoPago { get; set; } = string.Empty;

    /// <summary>BILLETERA_DIGITAL o TRANSFERENCIA.</summary>
    public string MetodoTipo { get; set; } = string.Empty;

    public decimal Monto { get; set; }

    /// <summary>A qué cuenta entró (o de cuál salió) la plata.</summary>
    public string? Cuenta { get; set; }

    public bool Anulado { get; set; }

    /// <summary>Solo en cobros: el número de operación y si ya se verificó en el banco.</summary>
    public string? NumeroOperacion { get; set; }
    public string? EstadoVerificacion { get; set; }
}
