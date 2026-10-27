using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Qué clientes están dejando de comprar.
///
/// Compara lo vendido en el periodo en curso contra el anterior de la misma longitud: semana, mes o
/// año. Solo lee: no crea ni cambia nada.
/// </summary>
public interface ICrmService
{
    /// <summary>
    /// Los clientes con su caída de ventas, los que más perdieron primero.
    /// </summary>
    /// <param name="periodo">semana, mes o anio. Sin valor, mes.</param>
    /// <param name="nivel">Deja solo los de ese nivel (CRITICO, ALTO...).</param>
    /// <param name="buscar">Texto contenido en el nombre o el documento.</param>
    Task<CrmCarteraResponse> CarteraAsync(
        string? periodo, int? mercadoId, int? rutaId, int? vendedorId, string? nivel, string? buscar);

    /// <summary>
    /// La caída de ventas por mercado o por ruta (agrupar = mercado | ruta), la que más perdió primero.
    /// </summary>
    Task<CrmZonasResponse> ZonasAsync(string? periodo, string? agrupar);

    /// <summary>La ficha de un cliente: su caída en las tres escalas, lo que compra y lo que dejó de comprar.</summary>
    Task<CrmFichaResponse> FichaAsync(int clienteId, string? periodo);

    /// <summary>El historial de gestiones de un cliente, la más reciente primero.</summary>
    Task<List<GestionResponse>> GestionesAsync(int clienteId);

    /// <summary>Anota un contacto con el cliente y, si se indica, qué hacer después y cuándo.</summary>
    Task<GestionResponse> RegistrarGestionAsync(int clienteId, CrearGestionRequest request);

    /// <summary>Da por hecha (o vuelve a abrir) la próxima acción de una gestión.</summary>
    Task<GestionResponse> CumplirGestionAsync(int gestionId, CumplirGestionRequest request);

    /// <summary>Borra una gestión anotada por error.</summary>
    Task EliminarGestionAsync(int gestionId);
}
