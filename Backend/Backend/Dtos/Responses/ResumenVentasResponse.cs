namespace Backend.Dtos.Responses;

/// <summary>Contadores del listado completo de pedidos, no de la página visible.</summary>
public class ResumenPedidosResponse
{
    public int Total { get; set; }
    public int Pendientes { get; set; }
    public int Confirmados { get; set; }
}

/// <summary>Contadores del listado completo de notas de venta.</summary>
public class ResumenNotasVentaResponse
{
    public int Total { get; set; }
    public int Confirmadas { get; set; }

    /// <summary>Suma de las confirmadas, sin contar líneas anuladas.</summary>
    public decimal TotalVendido { get; set; }
}
