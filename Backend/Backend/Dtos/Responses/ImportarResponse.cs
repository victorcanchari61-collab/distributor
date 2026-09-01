namespace Backend.Dtos.Responses;

/// <summary>Resultado de una importacion, fila por fila.</summary>
public class ImportarResponse
{
    public int Creados { get; set; }
    public int Actualizados { get; set; }
    public int Omitidos { get; set; }

    /// <summary>Detalle de lo que no se pudo guardar, con el numero de fila.</summary>
    public List<ImportarFilaError> Errores { get; set; } = [];
}

public class ImportarFilaError
{
    /// <summary>Numero de fila tal como venia en el archivo, empezando en 1.</summary>
    public int Fila { get; set; }
    public string Documento { get; set; } = string.Empty;
    public string Motivo { get; set; } = string.Empty;
}
