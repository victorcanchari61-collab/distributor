using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Categoría de los clientes (Socio, Distribuidor, Mayorista...) según lo que compraron en el
/// ciclo anterior. Ver <see cref="Backend.Models.CicloCategorizacion"/> para las fechas.
/// </summary>
public interface ICategorizacionService
{
    /// <summary>El ciclo, los tramos, y el cálculo que rige hoy si lo hay.</summary>
    Task<CategorizacionResponse> ObtenerAsync();

    /// <summary>
    /// Cambia el ciclo y los tramos. No recalcula: las categorías de los clientes siguen siendo las
    /// del último cálculo hasta que se calcule de nuevo.
    /// </summary>
    Task<CategorizacionResponse> GuardarAsync(GuardarCategorizacionRequest request);

    /// <summary>
    /// Calcula ya la categoría de todos los clientes activos con el ciclo y los tramos guardados. Si
    /// ya había un cálculo para el mismo ciclo y desde la misma fecha, lo reemplaza.
    /// </summary>
    Task<CategorizacionResponse> CalcularAsync();

    /// <summary>Los clientes con la categoría que les tocó y cómo se movieron.</summary>
    Task<List<ClienteCategoriaResponse>> ClientesAsync();

    /// <summary>
    /// Para el proceso diario: si ya hubo un primer cálculo y empezó un ciclo nuevo, calcula. Antes
    /// del primer cálculo no hace nada: arrancarlo es decisión de una persona.
    /// </summary>
    /// <returns>Si calculó.</returns>
    Task<bool> CalcularSiCorrespondeAsync();
}
