namespace Backend.Dtos.Responses;

/// <summary>Contadores del listado completo de órdenes de compra.</summary>
public class ResumenOrdenesCompraResponse
{
    public int Total { get; set; }
    public int Pendientes { get; set; }
    public int Confirmadas { get; set; }
}

/// <summary>Contadores del listado completo de compras.</summary>
public class ResumenComprasResponse
{
    public int Total { get; set; }

    /// <summary>Pendientes o recibidas a medias: las que todavía esperan mercadería.</summary>
    public int PorRecibir { get; set; }

    public int Recibidas { get; set; }
}
