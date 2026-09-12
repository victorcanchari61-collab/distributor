using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Lo que un cliente devuelve de una venta.
///
/// Nace Solicitada y no mueve nada: solo al aprobarla entra la mercadería y
/// la venta baja de importe.
/// </summary>
public interface IDevolucionService
{
    Task<IEnumerable<DevolucionResponse>> GetAllAsync(string? estado = null);
    Task<DevolucionResponse> GetAsync(int id);
    Task<ResumenDevolucionesResponse> GetResumenAsync();

    /// <summary>Las líneas de una venta con cuánto queda por devolver de cada una.</summary>
    Task<IEnumerable<LineaDevolvibleResponse>> DevolvibleAsync(int notaVentaId);

    Task<DevolucionResponse> CrearAsync(DevolucionRequest request, int? usuarioId);
    Task<DevolucionResponse> AprobarAsync(int id, int? usuarioId);
    Task<DevolucionResponse> RechazarAsync(int id, string motivo, int? usuarioId);
}
