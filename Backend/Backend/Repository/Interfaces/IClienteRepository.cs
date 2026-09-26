using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;

namespace Backend.Repository.Interfaces;

public interface IClienteRepository : IRepository<Cliente>
{
    /// <summary>
    /// Una página de clientes activos para un selector, ya buscada en la base.
    /// Con <paramref name="acotarARuta"/>, solo los de esa ruta (ninguno si es null).
    /// </summary>
    Task<(List<Dtos.Responses.ClienteOpcionResponse> Items, int Total)> BuscarAsync(
        Dtos.Requests.ConsultaTablaRequest consulta, bool acotarARuta, int? rutaId);

    /// <summary>
    /// El padrón para los selectores, sin seguimiento de cambios. Con
    /// <paramref name="acotarARuta"/>, solo los de esa ruta (ninguno si es null).
    /// </summary>
    Task<List<Cliente>> GetCatalogoAsync(bool acotarARuta, int? rutaId);

    /// <summary>
    /// Todos los clientes activos que se pueden elegir, con solo lo que usa el
    /// selector del APK (que filtra en el teléfono, aun con poca señal).
    /// </summary>
    Task<List<Dtos.Responses.ClienteOpcionResponse>> GetSelectorAsync(bool acotarARuta, int? rutaId);

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
