using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface ICatalogoClienteService
{
    /// <summary>
    /// El catálogo de venta con los precios de una lista; sin lista, los de la predeterminada.
    /// </summary>
    Task<CatalogoClienteResponse> GetAsync(int? listaId);

    /// <summary>
    /// La versión para el enlace público: precios de la lista predeterminada y solo los datos que un cliente
    /// debe ver (sin ids, códigos ni listas).
    /// </summary>
    Task<CatalogoPublicoResponse> GetPublicoAsync();
}
