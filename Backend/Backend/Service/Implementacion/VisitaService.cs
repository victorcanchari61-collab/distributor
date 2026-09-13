using Backend.Data;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class VisitaService : IVisitaService
{
    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;

    /// <summary>
    /// Tope de días que se pueden pedir de una vez.
    ///
    /// Un rango abierto por error — el año entero — traería cientos de miles
    /// de filas y tumbaría la pantalla. Con dos semanas se cubre cualquier uso
    /// real: el día de hoy, la semana, o la semana que viene.
    /// </summary>
    private const int MaximoDias = 14;

    public VisitaService(AppDbContext context, IPermisoService permisos, IUsuarioActual usuarioActual)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
    }

    public async Task<IEnumerable<VisitaResponse>> DelRangoAsync(
        DateTime desde, DateTime hasta, int? rutaId, int? vendedorId)
    {
        var dias = Dias(desde, hasta);
        var clientes = await ClientesAsync(dias.Select(DiaSemana.De).Distinct().ToList(), rutaId, vendedorId);
        var pedidos = await PedidosAsync(clientes.Select(c => c.Id).ToList(), dias);

        var visitas = new List<VisitaResponse>();

        foreach (var fecha in dias)
        {
            var dia = DiaSemana.De(fecha);

            foreach (var c in clientes.Where(c => c.DiaVisita == dia))
            {
                var pedido = pedidos.GetValueOrDefault((c.Id, fecha));

                visitas.Add(new VisitaResponse
                {
                    Fecha = fecha,
                    Dia = dia,
                    ClienteId = c.Id,
                    Cliente = c.Nombre,
                    Documento = c.Documento,
                    Direccion = c.Direccion,
                    Mercado = c.Mercado?.Nombre,
                    Telefono = c.Telefono,
                    RutaId = c.RutaId,
                    Ruta = c.Ruta?.Nombre,
                    VendedorId = c.VendedorId,
                    Vendedor = c.Vendedor?.Nombre,
                    Atendido = pedido is not null,
                    PedidoId = pedido?.Id,
                    PedidoNumero = pedido?.Numero,
                    // Una linea quitada al editar el pedido queda anulada, no
                    // se borra: sumarla diria que el cliente pidio mas.
                    Total = pedido?.Detalle
                        .Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario) ?? 0m,
                });
            }
        }

        return visitas
            // Primero los que faltan: la lista se usa para saber a quién ir, no
            // para repasar lo hecho.
            .OrderBy(v => v.Fecha)
            .ThenBy(v => v.Atendido)
            .ThenBy(v => v.Mercado)
            .ThenBy(v => v.Cliente)
            .ToList();
    }

    public async Task<ResumenVisitasResponse> ResumenAsync(
        DateTime desde, DateTime hasta, int? rutaId, int? vendedorId)
    {
        var visitas = (await DelRangoAsync(desde, hasta, rutaId, vendedorId)).ToList();

        return new ResumenVisitasResponse
        {
            Programadas = visitas.Count,
            Atendidas = visitas.Count(v => v.Atendido),
            Pendientes = visitas.Count(v => !v.Atendido),
            Total = visitas.Sum(v => v.Total),
        };
    }

    /// <summary>Los días del rango, acotados y en orden.</summary>
    private static List<DateTime> Dias(DateTime desde, DateTime hasta)
    {
        var inicio = desde.Date;
        var fin = hasta.Date;
        if (fin < inicio) fin = inicio;

        var total = Math.Min((fin - inicio).Days + 1, MaximoDias);
        return Enumerable.Range(0, total).Select(i => inicio.AddDays(i)).ToList();
    }

    private async Task<List<Cliente>> ClientesAsync(List<string> dias, int? rutaId, int? vendedorId)
    {
        var clientes = _context.Clientes
            .AsNoTracking()
            .Include(c => c.Mercado)
            .Include(c => c.Ruta)
            .Include(c => c.Vendedor)
            .Where(c => c.Activo && c.DiaVisita != null && dias.Contains(c.DiaVisita));

        if (rutaId is int ruta) clientes = clientes.Where(c => c.RutaId == ruta);
        if (vendedorId is int vendedor) clientes = clientes.Where(c => c.VendedorId == vendedor);

        /*
         * El alcance de datos manda igual que en Pedidos.
         *
         * Un vendedor acotado a "sus clientes" ve aqui su lista del dia, no la
         * de toda la empresa: si no, esta pantalla seria la puerta de atras
         * para ver el padron entero de otro.
         */
        if (_usuarioActual.Id is int usuarioId)
        {
            var alcance = await _permisos.AlcanceAsync(usuarioId, "fact.pedidos");
            if (alcance != AlcanceDatos.Todos)
            {
                clientes = clientes.Where(c => c.VendedorId == usuarioId);
            }
        }

        return await clientes.ToListAsync();
    }

    /// <summary>El pedido de cada cliente en cada día del rango.</summary>
    private async Task<Dictionary<(int Cliente, DateTime Fecha), Pedido>> PedidosAsync(
        List<int> clienteIds, List<DateTime> dias)
    {
        if (clienteIds.Count == 0 || dias.Count == 0) return [];

        // El rango se pide en dias locales, pero la fecha del pedido esta en
        // UTC: se corre la ventana cinco horas para traer los de la noche, que
        // en UTC ya figuran al dia siguiente.
        var desde = dias.First().AddHours(5);
        var hasta = dias.Last().AddDays(1).AddHours(5);

        // Un pedido anulado no cuenta como visita atendida: si se anulo, ese
        // cliente sigue sin pedido y hay que volver.
        var pedidos = await _context.Pedidos
            .AsNoTracking()
            .Include(p => p.Detalle)
            .Where(p => clienteIds.Contains(p.ClienteId)
                        && p.Estado != EstadoPedido.Anulado
                        && p.Fecha >= desde && p.Fecha < hasta)
            .ToListAsync();

        // Si a un cliente se le tomo mas de un pedido ese dia, vale el ultimo:
        // la lista solo necesita saber que ya se le atendio.
        return pedidos
            .GroupBy(p => (p.ClienteId, Zona.DiaDe(p.Fecha)))
            .ToDictionary(g => g.Key, g => g.OrderByDescending(p => p.Id).First());
    }
}
