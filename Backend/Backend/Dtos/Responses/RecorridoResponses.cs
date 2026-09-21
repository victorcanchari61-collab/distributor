namespace Backend.Dtos.Responses;

/// <summary>El recorrido semanal de un vehículo: cada día con los ids de sus rutas.</summary>
public class RecorridoResponse
{
    public int VehiculoId { get; set; }

    /// <summary>LUNES … DOMINGO → ids de las rutas de ese día. Solo los días con salida.</summary>
    public Dictionary<string, List<int>> Dias { get; set; } = [];
}
