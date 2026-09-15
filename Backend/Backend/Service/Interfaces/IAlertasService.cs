using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IAlertasService
{
    /// <summary>
    /// Todo lo que conviene revisar ahora: stock bajo, lotes por vencer,
    /// compras sin recibir hace mucho, ventas a crédito sin cobrar y pedidos
    /// con reserva de stock vieja. Se calcula al momento, no hay tabla detrás.
    /// </summary>
    /// <param name="usuarioId">
    /// Quién mira. Casi todas las alertas son del negocio y las ve cualquiera,
    /// pero las solicitudes de acceso solo tienen sentido para quien puede
    /// resolverlas.
    /// </param>
    Task<IEnumerable<AlertaResponse>> GetAsync(int? usuarioId = null);
}
