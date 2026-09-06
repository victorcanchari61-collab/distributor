using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IClienteRepository : IRepository<Cliente>
{
    Task<Cliente?> GetByDocumentoAsync(string documento);
    Task<bool> ExistsByDocumentoAsync(string documento, int? excludeId = null);

    /// <summary>Borrado definitivo.</summary>
    Task DeleteAsync(Cliente entidad);

    /// <summary>
    /// Una página del listado, ya buscada, filtrada y ordenada en la base: se
    /// traen solo las filas que se van a pintar. Devuelve además el total tras
    /// los filtros, para saber cuántas páginas hay.
    /// </summary>
    Task<(List<Cliente> Items, int Total)> ListarAsync(ConsultaTablaRequest consulta);

    /// <summary>
    /// Contadores y valores de filtro del listado completo, resueltos con
    /// conteos en la base — sin traerse las filas.
    /// </summary>
    Task<ResumenClientesResponse> ResumenAsync();
}
