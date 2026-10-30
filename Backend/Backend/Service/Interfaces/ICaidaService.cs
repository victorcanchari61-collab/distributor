using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>Lo que se le pide a un reporte de clientes: el tramo a medir y cómo acotar la lista.</summary>
public sealed record ConsultaCaida(
    DateTime? Desde = null,
    DateTime? Hasta = null,
    int? MercadoId = null,
    int? RutaId = null,
    int? VendedorId = null,
    string? Estado = null,
    string? Buscar = null);

/// <summary>
/// Los reportes de CRM: qué clientes (y qué vendedores y zonas) compran menos que antes, y cuáles dejaron de comprar.
///
/// Mide del 1 de enero a hoy contra el mismo tramo del año anterior, o el rango que se pida. Solo lee: no crea ni
/// cambia nada.
/// </summary>
public interface ICaidaService
{
    /// <summary>Los clientes con su caída, con una tarjeta por estado. Los que más dejaron de comprar, primero.</summary>
    Task<CaidaClientesResponse> ClientesAsync(ConsultaCaida consulta);

    /// <summary>De un cliente, qué productos dejó de comprar, cuáles compra menos o más, y cuáles son nuevos.</summary>
    Task<QueDejoDeComprarResponse> QueDejoDeComprarAsync(int clienteId, DateTime? desde, DateTime? hasta);

    /// <summary>Los vendedores cuyas ventas cayeron frente al mismo tramo del año anterior.</summary>
    Task<VendedoresCaidaResponse> VendedoresAsync(DateTime? desde, DateTime? hasta);

    /// <summary>La caída de ventas por mercado o por ruta (agrupar = mercado | ruta). Va en el dashboard.</summary>
    Task<ZonasCaidaResponse> ZonasAsync(DateTime? desde, DateTime? hasta, string? agrupar);
}
