namespace Backend.Dtos.Requests;

public class MotivoNovedadRequest
{
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>La mercadería salió en el camión y tiene que volver al almacén.</summary>
    public bool RegresaAlAlmacen { get; set; } = true;

    public bool Activo { get; set; } = true;
}

/// <summary>El pedido entero no se entregó.</summary>
public class NoEntregadoRequest
{
    public int MotivoId { get; set; }
    public string? Observacion { get; set; }
}
