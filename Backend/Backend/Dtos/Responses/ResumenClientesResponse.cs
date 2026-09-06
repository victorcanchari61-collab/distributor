namespace Backend.Dtos.Responses;

/// <summary>
/// Lo que la pantalla de Clientes necesita saber del listado COMPLETO, no de
/// la página que está viendo: los contadores de arriba y los valores que de
/// verdad existen para llenar los filtros de columna.
///
/// Va aparte de la página porque se calcula con conteos en la base, sin traer
/// las filas — que es justamente lo que se quería dejar de hacer.
/// </summary>
public class ResumenClientesResponse
{
    public int Activos { get; set; }
    public int Desactivados { get; set; }
    public int ConRuta { get; set; }

    /// <summary>Cuántas rutas de reparto distintas tienen asignadas los activos.</summary>
    public int Rutas { get; set; }

    /// <summary>Valores existentes por columna, para los filtros de tipo lista.</summary>
    public List<string> Direcciones { get; set; } = [];
    public List<string> Distritos { get; set; } = [];
    public List<string> RutasNombres { get; set; } = [];
    public List<string> Mercados { get; set; } = [];
}
