namespace Backend.Dtos.Responses;

public class MotivoGastoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; }

    /// <summary>En cuántos cuadres se usó. Si hay alguno, no se elimina.</summary>
    public int Usos { get; set; }
}

/// <summary>
/// Una fila de la lista de cuadres: un día y una persona.
///
/// Sale del cruce de los cobros con los cuadres ya registrados, así que
/// aparece una fila aunque nadie haya cuadrado todavía — que es justo lo que
/// hay que ver: quién falta por cuadrar.
/// </summary>
public class CuadrePendienteResponse
{
    public DateTime Fecha { get; set; }
    public int UsuarioId { get; set; }
    public string Usuario { get; set; } = string.Empty;

    /// <summary>Lo que el sistema dice que cobró en efectivo ese día.</summary>
    public decimal Efectivo { get; set; }

    /// <summary>Lo que le entró por Yape, Plin o transferencia.</summary>
    public decimal Bancos { get; set; }

    public decimal Total => Efectivo + Bancos;

    /// <summary>Solo si ya cuadró. Negativa: falta dinero.</summary>
    public decimal? DiferenciaEfectivo { get; set; }

    /// <summary>pendiente · cuadrado · conDiferencia · anulado</summary>
    public string Estado { get; set; } = string.Empty;

    /// <summary>El cuadre registrado, si lo hay: para editarlo o anularlo.</summary>
    public int? ArqueoId { get; set; }

    /// <summary>Lo que quedó debiendo ese día, si faltó.</summary>
    public decimal Faltante { get; set; }

    public bool FaltanteSaldado { get; set; }
}

/// <summary>
/// Lo que una persona debe por faltantes, para descontárselo.
/// </summary>
public class DeudaUsuarioResponse
{
    public int UsuarioId { get; set; }
    public string Usuario { get; set; } = string.Empty;

    /// <summary>Faltantes todavía sin saldar.</summary>
    public decimal Pendiente { get; set; }

    /// <summary>Cuántos días le faltó dinero y siguen sin saldar.</summary>
    public int Dias { get; set; }

    /// <summary>Lo ya descontado o repuesto, para ver el historial.</summary>
    public decimal Saldado { get; set; }

    /// <summary>Los cuadres con faltante pendiente, del más viejo al más nuevo.</summary>
    public List<ArqueoCajaResponse> Detalle { get; set; } = [];
}

/// <summary>Un cobro concreto: de quién vino y cuánto.</summary>
public class CobroDelDiaResponse
{
    public int PagoId { get; set; }
    public DateTime Fecha { get; set; }

    public string Cliente { get; set; } = string.Empty;

    /// <summary>El documento al que se aplicó: NV-000012.</summary>
    public string Documento { get; set; } = string.Empty;

    public string MetodoPago { get; set; } = string.Empty;

    /// <summary>EFECTIVO, BILLETERA, TRANSFERENCIA...</summary>
    public string TipoMetodo { get; set; } = string.Empty;

    public decimal Monto { get; set; }

    /// <summary>
    /// Si el cobro salda una venta de otro día: la deuda vieja que se cobró
    /// en la ruta, que es la mitad de lo que trae el repartidor.
    /// </summary>
    public bool EsDeudaAnterior { get; set; }
}

/// <summary>
/// Todo lo que hace falta para cuadrar a una persona en un día: lo que el
/// sistema dice, cobro a cobro, y lo que ya se declaró si se cuadró antes.
/// </summary>
public class DetalleCuadreResponse
{
    public DateTime Fecha { get; set; }
    public int UsuarioId { get; set; }
    public string Usuario { get; set; } = string.Empty;

    public decimal EfectivoSistema { get; set; }
    public decimal BancosSistema { get; set; }

    /// <summary>Los cobros en efectivo, uno a uno: de quién y cuánto.</summary>
    public List<CobroDelDiaResponse> Efectivo { get; set; } = [];

    /// <summary>Los cobros digitales que el sistema ya tiene registrados.</summary>
    public List<CobroDelDiaResponse> Digital { get; set; } = [];

    /// <summary>Lo declarado, si ya se cuadró.</summary>
    public ArqueoCajaResponse? Arqueo { get; set; }
}

public class ArqueoGastoResponse
{
    public int Id { get; set; }
    public int MotivoGastoId { get; set; }
    public string MotivoGasto { get; set; } = string.Empty;
    public decimal Monto { get; set; }
    public string? Descripcion { get; set; }
}

public class ArqueoPagoDigitalResponse
{
    public int Id { get; set; }
    public int? ClienteId { get; set; }
    public string? Cliente { get; set; }
    public int MetodoPagoId { get; set; }
    public string MetodoPago { get; set; } = string.Empty;
    public string? NumeroOperacion { get; set; }
    public decimal Monto { get; set; }
}

public class ArqueoCajaResponse
{
    public int Id { get; set; }
    public DateTime Fecha { get; set; }

    public int UsuarioId { get; set; }
    public string Usuario { get; set; } = string.Empty;

    public decimal Billetes { get; set; }
    public decimal Monedas { get; set; }

    public decimal EfectivoSistema { get; set; }
    public decimal BancosSistema { get; set; }

    public decimal TotalEfectivoReal { get; set; }
    public decimal TotalDigitalReal { get; set; }
    public decimal DiferenciaEfectivo { get; set; }
    public decimal DiferenciaBancos { get; set; }

    /// <summary>Lo que la persona debe reponer, si faltó dinero.</summary>
    public decimal Faltante { get; set; }

    /// <summary>Lo que trajo de más. Solo se informa.</summary>
    public decimal Sobrante { get; set; }

    public bool FaltanteSaldado { get; set; }
    public DateTime? FechaSaldado { get; set; }

    public string? Observacion { get; set; }
    public string Estado { get; set; } = string.Empty;

    public string? RegistradoPor { get; set; }
    public DateTime FechaCreacion { get; set; }

    public List<ArqueoGastoResponse> Gastos { get; set; } = [];
    public List<ArqueoPagoDigitalResponse> PagosDigitales { get; set; } = [];
}
