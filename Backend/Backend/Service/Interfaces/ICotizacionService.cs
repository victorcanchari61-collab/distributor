using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Las cotizaciones que los clientes mandan desde el portal. El cliente las arma y las manda; el vendedor las ve en su
/// bandeja y las atiende jalándolas al crear un pedido (eso vive en VentasService), o las descarta.
/// </summary>
public interface ICotizacionService
{
    // --- El cliente, con la sesión del portal ---

    /// <summary>El catálogo con los precios de SU lista (la predeterminada si no tiene).</summary>
    Task<CatalogoClienteResponse> CatalogoAsync();

    Task<List<CotizacionResponse>> MisCotizacionesAsync();

    /// <summary>Los productos que marcó con el corazón (ids), del primero al último que marcó.</summary>
    Task<List<int>> FavoritosAsync();

    /// <summary>Marca o desmarca un producto del catálogo; devuelve cómo quedaron sus favoritos.</summary>
    Task<List<int>> MarcarFavoritoAsync(int productoId, bool favorito);

    /// <summary>Los precios los pone el servidor con la lista del cliente: lo que manda el navegador no se cree.</summary>
    Task<CotizacionResponse> CrearAsync(CrearCotizacionRequest request);

    /// <summary>El cliente la retira mientras siga en espera.</summary>
    Task<CotizacionResponse> CancelarAsync(int id);

    // --- El panel ---

    Task<List<CotizacionResponse>> GetAllAsync(string? estado, int? clienteId);

    Task<CotizacionResponse> GetAsync(int id);

    Task<CotizacionResponse> DescartarAsync(int id, DescartarCotizacionRequest request);
}
