namespace Backend.Dtos.Requests;

/// <summary>Lo que se carga en un camión para un día y una ruta.</summary>
public class DespachoRequest
{
    /// <summary>El día del reparto. Vacío es hoy.</summary>
    public DateTime? Fecha { get; set; }

    /// <summary>
    /// De qué días son los pedidos que se cargan: del viernes al sábado para el
    /// reparto del lunes. Filtra la lista al armar; no limita qué se guarda.
    /// </summary>
    public DateTime? PedidosDesde { get; set; }
    public DateTime? PedidosHasta { get; set; }

    public int RutaId { get; set; }
    public int VehiculoId { get; set; }

    /// <summary>
    /// Quién maneja ese día. La pantalla lo propone a partir del conductor
    /// habitual del vehículo, pero se manda siempre: el del día puede ser otro.
    /// </summary>
    public int ConductorId { get; set; }

    public string? Observacion { get; set; }

    /// <summary>Los pedidos que van en el camión.</summary>
    public List<int> PedidoIds { get; set; } = [];
}
