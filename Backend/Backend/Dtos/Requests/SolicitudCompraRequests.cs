namespace Backend.Dtos.Requests;

/// <summary>Una línea de la solicitud: qué se pide y cuánto. Sin costo: ese lo pone Compras en la orden.</summary>
public class LineaSolicitudCompraRequest
{
    public int ProductoId { get; set; }

    /// <summary>En qué presentación se pide. Vacío significa unidad base.</summary>
    public int? PresentacionId { get; set; }

    /// <summary>Cuántas presentaciones.</summary>
    public decimal Cantidad { get; set; }

    public string? Nota { get; set; }
}

/// <summary>Lo que el almacén pide que se compre.</summary>
public class CrearSolicitudCompraRequest
{
    /// <summary>Para qué almacén se pide: a dónde va a llegar.</summary>
    public int AlmacenId { get; set; }

    /// <summary>NORMAL o URGENTE. Vacío es NORMAL.</summary>
    public string? Urgencia { get; set; }

    public string? Observacion { get; set; }
    public List<LineaSolicitudCompraRequest> Detalle { get; set; } = [];
}

/// <summary>Por qué Compras no la atiende.</summary>
public class RechazarSolicitudCompraRequest
{
    public string Motivo { get; set; } = string.Empty;
}
