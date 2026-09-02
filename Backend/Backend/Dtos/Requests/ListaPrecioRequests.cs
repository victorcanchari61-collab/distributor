namespace Backend.Dtos.Requests;

public abstract class ListaPrecioRequestBase
{
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
}

public class CreateListaPrecioRequest : ListaPrecioRequestBase
{
    public bool EsPredeterminada { get; set; }
}

public class UpdateListaPrecioRequest : ListaPrecioRequestBase
{
    public bool Activo { get; set; } = true;
}

/// <summary>Alta o cambio del precio de una presentacion en una lista.</summary>
public class GuardarPrecioRequest
{
    public int PresentacionId { get; set; }
    public decimal Precio { get; set; }

    /// <summary>Desde cuantas presentaciones aplica. 1 es el precio normal.</summary>
    public decimal CantidadMinima { get; set; } = 1m;
}

/// <summary>Varios precios de una vez, para cargar una lista completa.</summary>
public class GuardarPreciosRequest
{
    public List<GuardarPrecioRequest> Precios { get; set; } = [];
}
