namespace Backend.Dtos.Requests;

public class MotivoGastoRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; } = true;
}

/// <summary>Un gasto de la ruta que se declara al cuadrar.</summary>
public class ArqueoGastoRequest
{
    public int MotivoGastoId { get; set; }
    public decimal Monto { get; set; }
    public string? Descripcion { get; set; }
}

/// <summary>
/// Un cobro digital que la persona confirma haber recibido.
///
/// Se manda uno por cada cobro marcado en la pantalla, no pagos inventados: el
/// importe y el cliente salen del cobro que ya tiene el sistema.
/// </summary>
public class ArqueoPagoDigitalRequest
{
    /// <summary>El cobro del sistema que se está confirmando.</summary>
    public int? PagoVentaId { get; set; }

    public int? ClienteId { get; set; }
    public int MetodoPagoId { get; set; }
    public string? NumeroOperacion { get; set; }
    public decimal Monto { get; set; }
}

/// <summary>
/// El cuadre de una persona en un día.
///
/// Los totales del sistema NO viajan aquí: los calcula el servidor al cerrar,
/// leyendo los cobros. Si los mandara el cliente, bastaría con editarlos en el
/// navegador para que cualquier cuadre saliera perfecto.
/// </summary>
public class RegistrarArqueoRequest
{
    public DateTime Fecha { get; set; }

    /// <summary>De quién es el cuadre.</summary>
    public int UsuarioId { get; set; }

    public decimal Billetes { get; set; }
    public decimal Monedas { get; set; }

    public string? Observacion { get; set; }

    public List<ArqueoGastoRequest> Gastos { get; set; } = [];
    public List<ArqueoPagoDigitalRequest> PagosDigitales { get; set; } = [];
}
