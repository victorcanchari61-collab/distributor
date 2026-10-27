using Backend.Data;
using Backend.Models;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>La categoría que tiene hoy un cliente, con cómo se pinta.</summary>
public sealed record CategoriaVigente(string Codigo, string Nombre, string Color);

/// <summary>
/// Lo que varias pantallas necesitan saber de la categorización sin pasar por el servicio completo:
/// cuál es el cálculo que rige y la categoría vigente de cada cliente.
/// </summary>
public static class CategorizacionConsultas
{
    /// <summary>
    /// El cálculo que rige en un día: el más reciente que ya empezó. Si hay dos para el mismo día
    /// (se recalculó), el último. Aunque ya haya pasado su último día de vigencia sigue valiendo hasta que
    /// alguien calcule de nuevo: es mejor una categoría vieja que ninguna.
    /// </summary>
    public static Task<CalculoCategorizacion?> VigenteAsync(AppDbContext context, DateTime hoy) =>
        context.CalculosCategorizacion.AsNoTracking()
            .Where(c => c.VigenteDesde <= hoy)
            .OrderByDescending(c => c.VigenteDesde)
            .ThenByDescending(c => c.CalculadoEn)
            .FirstOrDefaultAsync();

    /// <summary>La categoría vigente de cada cliente que entró en el cálculo que rige. Vacío si nunca se calculó.</summary>
    public static async Task<Dictionary<int, CategoriaVigente>> PorClienteAsync(AppDbContext context)
    {
        var vigente = await VigenteAsync(context, Zona.Hoy);
        if (vigente is null) return [];

        var categorias = await context.CategoriasCliente.AsNoTracking()
            .ToDictionaryAsync(c => c.Codigo, c => new CategoriaVigente(c.Codigo, c.Nombre, c.Color));

        var filas = await context.ClientesCategoria.AsNoTracking()
            .Where(c => c.CalculoId == vigente.Id)
            .Select(c => new { c.ClienteId, c.Codigo })
            .ToListAsync();

        return filas.ToDictionary(
            f => f.ClienteId,
            // Un código que ya no existe no pasa (las seis son fijas), pero no debe tumbar la pantalla.
            f => categorias.GetValueOrDefault(f.Codigo) ?? new CategoriaVigente(f.Codigo, f.Codigo, "slate"));
    }

    /// <summary>
    /// Lo comprado por cada cliente en [ini, fin) (UTC): las líneas vigentes menos lo recogido, con
    /// IGV. Es la misma "venta" de la Cartera en riesgo.
    /// </summary>
    public static async Task<Dictionary<int, decimal>> VentasNetasAsync(AppDbContext context, DateTime ini, DateTime fin)
    {
        var vendido = await context.NotaVentaDetalles
            .Where(d => !d.Anulado
                        && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && d.NotaVenta.Fecha >= ini && d.NotaVenta.Fecha < fin)
            .GroupBy(d => d.NotaVenta!.ClienteId)
            .Select(g => new { ClienteId = g.Key, Importe = g.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion) })
            .ToDictionaryAsync(x => x.ClienteId, x => x.Importe);

        var recogido = await context.RecojosVenta
            .Where(r => r.Estado != EstadoRecojo.Anulado
                        && r.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && r.NotaVenta.Fecha >= ini && r.NotaVenta.Fecha < fin)
            .GroupBy(r => r.NotaVenta!.ClienteId)
            .Select(g => new { ClienteId = g.Key, Importe = g.Sum(r => r.Importe) })
            .ToListAsync();

        foreach (var r in recogido)
            vendido[r.ClienteId] = vendido.GetValueOrDefault(r.ClienteId) - r.Importe;

        return vendido;
    }
}
