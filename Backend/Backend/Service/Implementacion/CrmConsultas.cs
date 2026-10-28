using Backend.Data;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>Los datos del maestro de clientes que los reportes de CRM muestran, tal como los ve la base.</summary>
public sealed record FilaCliente(
    int Id, string Documento, string TipoDoc, string Nombre, string? Telefono, string? Direccion,
    bool Activo, int? RutaId, string? Ruta, int? MercadoId, string? Mercado, int? VendedorId, string? Vendedor);

/// <summary>Lo que el seguimiento sabe de un cliente: su última gestión y su contacto programado más próximo.</summary>
public sealed record InfoGestion(
    string? Resultado, DateTime? Fecha, DateTime? Proximo, string? Accion);

/// <summary>
/// Lo que varias pantallas de CRM (los reportes de caída, la ficha, Visitas) necesitan sin pasar por el servicio
/// completo: qué clientes puede ver quien pregunta, cuánto compró cada uno y qué se habló con ellos.
///
/// "Venta" es siempre lo mismo que cuenta el reporte de Ventas: el importe de las líneas vigentes (con IGV), menos lo
/// recogido. Una devolución aprobada ya bajó la línea, así que no se resta otra vez.
/// </summary>
public static class CrmConsultas
{
    /// <summary>Con este submódulo se pide el alcance de los clientes: es el de todo el CRM.</summary>
    public const string Submodulo = "crm.seguimiento";

    public static readonly System.Linq.Expressions.Expression<Func<Cliente, FilaCliente>> Fila = c =>
        new FilaCliente(
            c.Id, c.Documento, c.TipoDoc, c.Nombre, c.Telefono, c.Direccion,
            c.Activo,
            c.RutaId, c.Ruta != null ? c.Ruta.Nombre : null,
            c.MercadoId, c.Mercado != null ? c.Mercado.Nombre : null,
            c.VendedorId, c.Vendedor != null ? c.Vendedor.Nombre : null);

    /// <summary>
    /// Los clientes que quien pregunta puede ver. Sin restricción, todos; con ella, los que tiene asignados como
    /// vendedor y los de sus rutas.
    /// </summary>
    public static async Task<(IQueryable<Cliente> Clientes, bool SoloPropios)> VisiblesAsync(
        AppDbContext context, IPermisoService permisos, int? usuarioId)
    {
        var clientes = context.Clientes.AsNoTracking();
        if (usuarioId is not int uid) return (clientes, false);

        var alcance = await permisos.AlcanceFiltroAsync(uid, Submodulo);
        if (alcance.SinRestriccion) return (clientes, false);

        var rutas = alcance.RutaIds;
        var propio = alcance.UsuarioId;
        return (clientes.Where(c => c.VendedorId == propio
                                    || (c.RutaId != null && rutas.Contains(c.RutaId.Value))), true);
    }

    /// <summary>Lo vendido a cada cliente en los dos tramos: viaja una fila por cliente, con la suma hecha en la base.</summary>
    public static async Task<Dictionary<int, (decimal Actual, decimal Anterior)>> VentasPorClienteAsync(
        AppDbContext context, PeriodoComparado p, int? clienteId = null)
    {
        var actualIni = p.ActualIni;
        var actualFin = p.ActualFin;
        var anteriorIni = p.AnteriorIni;
        var anteriorFin = p.AnteriorFin;

        var lineas = context.NotaVentaDetalles
            .Where(d => !d.Anulado
                        && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && ((d.NotaVenta.Fecha >= actualIni && d.NotaVenta.Fecha < actualFin)
                            || (d.NotaVenta.Fecha >= anteriorIni && d.NotaVenta.Fecha < anteriorFin)));
        if (clienteId is int id) lineas = lineas.Where(d => d.NotaVenta!.ClienteId == id);

        // Lo que cae en el tramo actual se separa por fecha: los dos tramos pueden pisarse si el rango es largo,
        // así que se compara contra los límites de cada uno y no contra "desde el inicio del actual".
        var vendido = await lineas
            .GroupBy(d => d.NotaVenta!.ClienteId)
            .Select(g => new
            {
                ClienteId = g.Key,
                Actual = g.Sum(d => d.NotaVenta!.Fecha >= actualIni && d.NotaVenta.Fecha < actualFin
                    ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
                Anterior = g.Sum(d => d.NotaVenta!.Fecha >= anteriorIni && d.NotaVenta.Fecha < anteriorFin
                    ? d.CantidadPresentacion * d.PrecioPresentacion : 0m),
            })
            .ToListAsync();

        var recojos = context.RecojosVenta
            .Where(r => r.Estado != EstadoRecojo.Anulado
                        && r.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && ((r.NotaVenta.Fecha >= actualIni && r.NotaVenta.Fecha < actualFin)
                            || (r.NotaVenta.Fecha >= anteriorIni && r.NotaVenta.Fecha < anteriorFin)));
        if (clienteId is int idr) recojos = recojos.Where(r => r.NotaVenta!.ClienteId == idr);

        var recogido = await recojos
            .GroupBy(r => r.NotaVenta!.ClienteId)
            .Select(g => new
            {
                ClienteId = g.Key,
                Actual = g.Sum(r => r.NotaVenta!.Fecha >= actualIni && r.NotaVenta.Fecha < actualFin ? r.Importe : 0m),
                Anterior = g.Sum(r => r.NotaVenta!.Fecha >= anteriorIni && r.NotaVenta.Fecha < anteriorFin ? r.Importe : 0m),
            })
            .ToListAsync();

        var resultado = vendido.ToDictionary(x => x.ClienteId, x => (x.Actual, x.Anterior));
        foreach (var r in recogido)
        {
            resultado.TryGetValue(r.ClienteId, out var baseVenta);
            resultado[r.ClienteId] = (Math.Max(0m, baseVenta.Actual - r.Actual), Math.Max(0m, baseVenta.Anterior - r.Anterior));
        }

        return resultado;
    }

    /// <summary>El instante (UTC) de la última venta vigente de cada cliente.</summary>
    public static async Task<Dictionary<int, DateTime>> UltimasComprasAsync(AppDbContext context, int? clienteId = null)
    {
        var notas = context.NotasVenta.Where(n => n.Estado != EstadoNotaVenta.Anulada);
        if (clienteId is int id) notas = notas.Where(n => n.ClienteId == id);

        return await notas
            .GroupBy(n => n.ClienteId)
            .Select(g => new { ClienteId = g.Key, Ultima = g.Max(n => n.Fecha) })
            .ToDictionaryAsync(x => x.ClienteId, x => x.Ultima);
    }

    /// <summary>
    /// Lo que debe cada cliente hoy. Misma regla de Cuentas por cobrar: ventas a crédito confirmadas cuyo total
    /// supera lo pagado.
    /// </summary>
    public static async Task<Dictionary<int, decimal>> SaldosPorCobrarAsync(AppDbContext context, int? clienteId = null)
    {
        var notas = context.NotasVenta
            .Where(n => n.Estado == EstadoNotaVenta.Confirmada && n.FormaPago == FormaPagoVenta.Credito);
        if (clienteId is int id) notas = notas.Where(n => n.ClienteId == id);

        var abiertas = await notas
            .Select(n => new
            {
                n.ClienteId,
                Total = n.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.Cantidad * d.PrecioUnitario)) ?? 0m,
                Pagado = n.Pagos.Where(p => !p.Anulado).Sum(p => (decimal?)p.Monto) ?? 0m,
            })
            .Where(n => n.Total > n.Pagado)
            .AsNoTracking()
            .ToListAsync();

        return abiertas
            .GroupBy(n => n.ClienteId)
            .ToDictionary(g => g.Key, g => Math.Round(g.Sum(n => n.Total - n.Pagado), 2));
    }

    /// <summary>La última gestión de cada cliente y su contacto programado más próximo.</summary>
    public static async Task<Dictionary<int, InfoGestion>> GestionesPorClienteAsync(AppDbContext context, int? clienteId = null)
    {
        var gestiones = context.GestionesCliente.AsNoTracking();
        if (clienteId is int id) gestiones = gestiones.Where(g => g.ClienteId == id);

        var ultimas = (await gestiones
                .Select(g => new { g.ClienteId, g.Fecha, g.Resultado, g.Id })
                .ToListAsync())
            .GroupBy(g => g.ClienteId)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(x => x.Fecha).ThenByDescending(x => x.Id).First());

        var programados = (await gestiones
                .Where(g => g.SeguimientoEstado == EstadoSeguimiento.Programado && g.ProximoSeguimiento != null)
                .Select(g => new { g.ClienteId, g.ProximoSeguimiento, g.ProximaAccion })
                .ToListAsync())
            .GroupBy(g => g.ClienteId)
            .ToDictionary(g => g.Key, g => g.OrderBy(x => x.ProximoSeguimiento).First());

        return ultimas.ToDictionary(
            u => u.Key,
            u => programados.TryGetValue(u.Key, out var p)
                ? new InfoGestion(u.Value.Resultado, u.Value.Fecha, p.ProximoSeguimiento, p.ProximaAccion)
                : new InfoGestion(u.Value.Resultado, u.Value.Fecha, null, null));
    }

    /// <summary>"1 ene - 27 oct 2026": un tramo escrito como lo lee el negocio.</summary>
    public static string Etiqueta(DateTime desde, DateTime hasta)
    {
        string Dia(DateTime d) => $"{d.Day} {Mes(d.Month)}";
        return $"{Dia(desde)} - {Dia(hasta)} {hasta.Year}";
    }

    private static string Mes(int mes) => mes switch
    {
        1 => "ene", 2 => "feb", 3 => "mar", 4 => "abr", 5 => "may", 6 => "jun",
        7 => "jul", 8 => "ago", 9 => "set", 10 => "oct", 11 => "nov", _ => "dic",
    };
}
