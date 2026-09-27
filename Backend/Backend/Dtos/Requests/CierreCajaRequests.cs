namespace Backend.Dtos.Requests;

/// <summary>Cierra la caja propia: cuánto se contó y a qué cuenta se entrega.</summary>
public class CerrarCajaRequest
{
    /// <summary>Total en billetes. Si viene el desglose, se calcula de él.</summary>
    public decimal Billetes { get; set; }

    /// <summary>Total en monedas. Si viene el desglose, se calcula de él.</summary>
    public decimal Monedas { get; set; }

    public int CuentaDestinoId { get; set; }
    public string? Observacion { get; set; }

    /// <summary>Cuántos de cada billete y moneda: queda guardado para revisar el cierre.</summary>
    public List<DenominacionRequest> Denominaciones { get; set; } = [];
}

public class DenominacionRequest
{
    public decimal Valor { get; set; }
    public int Cantidad { get; set; }
}

/// <summary>El cobro digital no apareció en el banco: por qué.</summary>
public class RechazarCobroRequest
{
    public string Observacion { get; set; } = string.Empty;
}
