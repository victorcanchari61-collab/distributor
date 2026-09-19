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

/// <summary>Lo que el encargado encontró al contar lo que volvió en el camión.</summary>
public class VerificarNovedadRequest
{
    /// <summary>RECIBIDA (volvió completa) o FALTANTE (no volvió toda).</summary>
    public string Estado { get; set; } = string.Empty;

    /// <summary>
    /// Cuánto volvió, en unidad base. Solo cuenta en FALTANTE: en RECIBIDA se
    /// da por vuelto todo lo que no se entregó.
    /// </summary>
    public decimal? CantidadRegresada { get; set; }

    public string? Observacion { get; set; }
}
