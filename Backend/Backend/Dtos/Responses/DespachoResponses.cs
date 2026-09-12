namespace Backend.Dtos.Responses;

/// <summary>Un pedido dentro del camión, con lo que hace falta para repartirlo.</summary>
public class DespachoPedidoResponse
{
    public int PedidoId { get; set; }
    public string Numero { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;

    /// <summary>Dónde entregarlo: sin esto el papel del reparto no sirve.</summary>
    public string? Direccion { get; set; }
    public string? Mercado { get; set; }
    public string? Telefono { get; set; }

    public decimal Total { get; set; }
    public int Lineas { get; set; }

    /// <summary>La venta, si el repartidor ya lo convirtió.</summary>
    public int? NotaVentaId { get; set; }
    public string? NotaVentaNumero { get; set; }
}

public class DespachoResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }

    public int RutaId { get; set; }
    public string Ruta { get; set; } = string.Empty;

    public int VehiculoId { get; set; }
    /// <summary>La placa, que es como se nombra a un camión de verdad.</summary>
    public string Vehiculo { get; set; } = string.Empty;

    public int ConductorId { get; set; }
    public string Conductor { get; set; } = string.Empty;

    /// <summary>ARMADO o ANULADO.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Observacion { get; set; }
    public string? Usuario { get; set; }

    /// <summary>Cuántos pedidos lleva y cuánto suman.</summary>
    public int Pedidos { get; set; }
    public decimal Total { get; set; }

    /// <summary>Cuántos de esos pedidos ya se convirtieron en venta.</summary>
    public int Entregados { get; set; }

    public List<DespachoPedidoResponse> Detalle { get; set; } = [];
}

public class ResumenDespachosResponse
{
    public int Total { get; set; }
    public int Armados { get; set; }
    public int PedidosEnRuta { get; set; }
}
