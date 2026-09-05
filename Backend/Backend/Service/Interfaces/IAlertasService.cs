using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IAlertasService
{
    /// <summary>
    /// Todo lo que conviene revisar ahora: stock bajo, lotes por vencer,
    /// compras sin recibir hace mucho, ventas a crédito sin cobrar y pedidos
    /// con reserva de stock vieja. Se calcula al momento, no hay tabla detrás.
    /// </summary>
    Task<IEnumerable<AlertaResponse>> GetAsync();
}
