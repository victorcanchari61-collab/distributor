using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Las solicitudes de compra: lo que el almacén pide que se compre, antes de que exista una orden.
///
/// Es un documento interno. De una solicitud Compras arma la orden de compra (con proveedor y costos) y esa orden
/// es la que se le envía al proveedor.
/// </summary>
public interface ISolicitudCompraService
{
    /// <summary>Las solicitudes que quien pide puede ver: todas, o solo las suyas según su alcance.</summary>
    Task<IEnumerable<SolicitudCompraFilaResponse>> GetAllAsync(string? estado);

    Task<SolicitudCompraResponse> GetAsync(int id);

    Task<SolicitudCompraResponse> CrearAsync(CrearSolicitudCompraRequest request, int? usuarioId);

    /// <summary>Corrige una solicitud todavía Pendiente.</summary>
    Task<SolicitudCompraResponse> ActualizarAsync(int id, CrearSolicitudCompraRequest request);

    /// <summary>Quien la pidió la retira. Solo mientras está Pendiente.</summary>
    Task AnularAsync(int id);

    /// <summary>Compras no la atiende, y dice por qué.</summary>
    Task<SolicitudCompraResponse> RechazarAsync(int id, RechazarSolicitudCompraRequest request);

    /// <summary>
    /// Los productos del almacén que están bajo su mínimo, con una cantidad sugerida: para llenar la solicitud sin
    /// tener que recorrer el stock.
    /// </summary>
    Task<IEnumerable<SugerenciaSolicitudResponse>> SugerenciasAsync(int almacenId);

    /// <summary>Antes de hacer una orden desde la solicitud: que exista y todavía se pueda atender.</summary>
    Task ExigirAtendibleAsync(int id);

    /// <summary>La orden ya se hizo: la solicitud pasa a Atendida.</summary>
    Task MarcarAtendidaAsync(int id);
}
