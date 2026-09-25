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

/// <summary>Una cuenta a la que se puede entregar lo contado: solo lo justo para elegirla, sin su saldo.</summary>
public class CuentaDestinoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Naturaleza { get; set; } = string.Empty;
}
