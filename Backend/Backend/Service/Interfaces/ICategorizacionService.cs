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
    /// Cambia el ciclo y los tramos. Si el ciclo cambió, recalcula en el acto con el ciclo nuevo; si solo
    /// cambiaron los tramos o los nombres, las categorías de los clientes siguen siendo las del último
    /// cálculo hasta que se calcule de nuevo ("Calcular ahora") o empiece el ciclo siguiente.
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

    /// <summary>
    /// Da categoría a los clientes activos que no entraron en el cálculo que rige (un cliente nuevo, o
    /// uno que estaba inactivo y se activó), con lo que compraron en el mismo ciclo que se evaluó. Sin
    /// esto esperaban al cálculo siguiente, que en un ciclo trimestral son meses. Los que ya tienen no se
    /// tocan: eso es del recálculo del ciclo.
    /// </summary>
    /// <param name="clienteIds">Solo estos clientes; nulo es "todos los que falten".</param>
    /// <returns>A cuántos se les dio categoría.</returns>
    Task<int> CompletarSinCategoriaAsync(IReadOnlyCollection<int>? clienteIds = null);

    /// <summary>La categoría que rige para cada cliente, para pintarla en el padrón de clientes.</summary>
    Task<Dictionary<int, CategoriaVigenteResponse>> CategoriasPorClienteAsync();
}
