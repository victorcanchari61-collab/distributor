namespace Backend.Dtos.Responses;

/// <summary>
/// Una página de un listado. `Total` es cuántas filas hay en TODO el listado
/// una vez aplicados búsqueda y filtros — no cuántas trae esta página: es lo
/// que la tabla necesita para saber cuántas páginas dibujar.
/// </summary>
public class PaginaResponse<T>
{
    public List<T> Items { get; set; } = [];
    public int Total { get; set; }
    public int Pagina { get; set; }
    public int PorPagina { get; set; }
}
