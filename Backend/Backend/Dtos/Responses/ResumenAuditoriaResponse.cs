namespace Backend.Dtos.Responses;

/// <summary>
/// Los contadores de la pantalla de Auditoría, calculados sobre toda la
/// bitácora. Van aparte de la página porque salen de conteos en la base: con
/// paginación real, contar sobre las filas visibles diría "20 registros".
/// </summary>
public class ResumenAuditoriaResponse
{
    public int Total { get; set; }
    public int Creados { get; set; }
    public int Actualizados { get; set; }
    public int Eliminados { get; set; }

    /// <summary>Las entidades que ya tienen algún cambio, para el filtro de columna.</summary>
    public List<string> Entidades { get; set; } = [];

    /// <summary>Los usuarios que aparecen en la bitácora, para el filtro de columna.</summary>
    public List<string> Usuarios { get; set; } = [];
}
