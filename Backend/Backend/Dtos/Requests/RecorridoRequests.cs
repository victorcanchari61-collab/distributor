namespace Backend.Dtos.Requests;

/// <summary>
/// El recorrido semanal completo de un vehículo: día → rutas. Reemplaza el que había.
/// Los días que no vienen (o vienen vacíos) quedan sin salida.
/// </summary>
public class RecorridoRequest
{
    public Dictionary<string, List<int>> Dias { get; set; } = [];
}
