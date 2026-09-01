namespace Backend.Dtos.Requests;

/// <summary>
/// Importacion masiva. Cada fila se procesa por separado: las validas se
/// guardan aunque otras fallen, y el resultado dice que paso con cada una.
/// </summary>
public class ImportarRequest<T>
{
    public List<T> Filas { get; set; } = [];

    /// <summary>
    /// Si el documento ya existe, actualiza el registro en vez de omitirlo.
    /// </summary>
    public bool ActualizarExistentes { get; set; }
}

public class ImportarClientesRequest : ImportarRequest<CreateClienteRequest>
{
}

public class ImportarProveedoresRequest : ImportarRequest<CreateProveedorRequest>
{
}
