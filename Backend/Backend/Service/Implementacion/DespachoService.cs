using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class DespachoService : IDespachoService
{
    private readonly AppDbContext _context;
    private readonly INotificador _notificador;

    public DespachoService(AppDbContext context, INotificador notificador)
    {
        _context = context;
        _notificador = notificador;
    }

    private IQueryable<Despacho> Completos() =>
        _context.Despachos
            .Include(d => d.Ruta)
            .Include(d => d.Vehiculo)
            .Include(d => d.Conductor)
            .Include(d => d.Usuario)
            .Include(d => d.Detalle).ThenInclude(x => x.Pedido!).ThenInclude(p => p.Cliente!).ThenInclude(c => c.Mercado)
            .Include(d => d.Detalle).ThenInclude(x => x.Pedido!).ThenInclude(p => p.Detalle)
            .Include(d => d.Detalle).ThenInclude(x => x.Pedido!).ThenInclude(p => p.Ventas);

    public async Task<IEnumerable<DespachoResponse>> GetAllAsync(string? estado = null) =>
        (await Completos()
            .AsNoTracking()
            .Where(d => estado == null || d.Estado == estado)
            .OrderByDescending(d => d.Fecha)
            .ThenByDescending(d => d.Id)
            .Take(300)
            .ToListAsync())
        .Select(Map);

    public async Task<DespachoResponse> GetAsync(int id) => Map(await BuscarAsync(id));

    public async Task<ResumenDespachosResponse> GetResumenAsync()
    {
        var armados = _context.Despachos.Where(d => d.Estado == EstadoDespacho.Armado);

        return new ResumenDespachosResponse
        {
            Total = await _context.Despachos.CountAsync(),
            Armados = await armados.CountAsync(),
            // Los pedidos que estan en un camion y todavia no se entregaron:
            // es el numero que dice cuanto trabajo hay en la calle ahora.
            PedidosEnRuta = await armados
                .SelectMany(d => d.Detalle)
                .CountAsync(x => !x.Pedido!.Ventas.Any(v => v.Estado != EstadoNotaVenta.Anulada)),
        };
    }

    public async Task<IEnumerable<DespachoPedidoResponse>> PedidosDisponiblesAsync(
        int rutaId, int? despachoId = null)
    {
        /*
         * Un pedido esta disponible si sigue pendiente y no viaja ya en otro
         * camion.
         *
         * El "otro" importa: al EDITAR un despacho hay que seguir viendo los
         * pedidos que ya son suyos, o desapareceria de la pantalla justo lo
         * que se esta intentando corregir.
         */
        var comprometidos = _context.Despachos
            .Where(d => d.Estado == EstadoDespacho.Armado && (despachoId == null || d.Id != despachoId))
            .SelectMany(d => d.Detalle)
            .Select(x => x.PedidoId);

        var pedidos = await _context.Pedidos
            .AsNoTracking()
            .Include(p => p.Cliente!).ThenInclude(c => c.Mercado)
            .Include(p => p.Detalle)
            .Include(p => p.Ventas)
            .Where(p => p.Estado == EstadoPedido.Pendiente
                        && p.Cliente!.RutaId == rutaId
                        && !comprometidos.Contains(p.Id))
            .OrderBy(p => p.Fecha)
            .ToListAsync();

        return pedidos.Select(MapPedido);
    }

    public async Task<DespachoResponse> CrearAsync(DespachoRequest request, int? usuarioId)
    {
        await ValidarAsync(request);

        var despacho = new Despacho
        {
            Numero = await SiguienteNumeroAsync(),
            Fecha = (request.Fecha ?? DateTime.UtcNow).Date,
            RutaId = request.RutaId,
            VehiculoId = request.VehiculoId,
            ConductorId = request.ConductorId,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId,
        };

        foreach (var pedidoId in await PedidosValidosAsync(request, null))
        {
            despacho.Detalle.Add(new DespachoDetalle { PedidoId = pedidoId });
        }

        _context.Despachos.Add(despacho);
        await _context.SaveChangesAsync();

        var creado = Map(await BuscarAsync(despacho.Id));
        await _notificador.AvisarAsync("despachos", "creado", creado);
        return creado;
    }

    public async Task<DespachoResponse> ActualizarAsync(int id, DespachoRequest request)
    {
        await ValidarAsync(request);

        var despacho = await BuscarAsync(id);
        if (despacho.Estado == EstadoDespacho.Anulado)
        {
            throw new BadRequestException("Este despacho está anulado.");
        }

        despacho.Fecha = (request.Fecha ?? despacho.Fecha).Date;
        despacho.RutaId = request.RutaId;
        despacho.VehiculoId = request.VehiculoId;
        despacho.ConductorId = request.ConductorId;
        despacho.Observacion = Limpiar(request.Observacion);

        var validos = await PedidosValidosAsync(request, id);

        /*
         * Un pedido ya entregado no se saca del camion.
         *
         * Si se quitara, la venta quedaria sin decir en que reparto salio y el
         * despacho mentiria sobre lo que llevo. Lo que ya ocurrio no se edita.
         */
        var entregados = despacho.Detalle
            .Where(x => x.Pedido!.Ventas.Any(v => v.Estado != EstadoNotaVenta.Anulada))
            .Select(x => x.PedidoId)
            .ToHashSet();

        var faltan = entregados.Except(validos).ToList();
        if (faltan.Count > 0)
        {
            throw new BadRequestException(
                "No puedes quitar del despacho un pedido que ya se entregó y facturó.");
        }

        var actuales = despacho.Detalle.ToList();
        foreach (var linea in actuales.Where(x => !validos.Contains(x.PedidoId)))
        {
            despacho.Detalle.Remove(linea);
        }

        foreach (var pedidoId in validos.Where(id => actuales.All(x => x.PedidoId != id)))
        {
            despacho.Detalle.Add(new DespachoDetalle { PedidoId = pedidoId });
        }

        await _context.SaveChangesAsync();

        var actualizado = Map(await BuscarAsync(id));
        await _notificador.AvisarAsync("despachos", "actualizado", actualizado);
        return actualizado;
    }

    public async Task<DespachoResponse> AnularAsync(int id)
    {
        var despacho = await BuscarAsync(id);

        if (despacho.Estado == EstadoDespacho.Anulado)
        {
            throw new BadRequestException("Este despacho ya está anulado.");
        }

        // Con algo ya entregado, anularlo borraria el rastro de por donde
        // salio esa mercaderia.
        if (despacho.Detalle.Any(x => x.Pedido!.Ventas.Any(v => v.Estado != EstadoNotaVenta.Anulada)))
        {
            throw new BadRequestException(
                "Este despacho ya tiene entregas facturadas: no se puede anular.");
        }

        despacho.Estado = EstadoDespacho.Anulado;
        await _context.SaveChangesAsync();

        var anulado = Map(await BuscarAsync(id));
        await _notificador.AvisarAsync("despachos", "anulado", anulado);
        return anulado;
    }

    // ------------------------------------------------------------- Auxiliares

    private async Task<Despacho> BuscarAsync(int id) =>
        await Completos().FirstOrDefaultAsync(d => d.Id == id)
        ?? throw new NotFoundException($"No existe el despacho {id}");

    private async Task ValidarAsync(DespachoRequest request)
    {
        if (!await _context.Rutas.AnyAsync(r => r.Id == request.RutaId))
            throw new BadRequestException("Elige la ruta");

        var vehiculo = await _context.Vehiculos.FirstOrDefaultAsync(v => v.Id == request.VehiculoId)
            ?? throw new BadRequestException("Elige el vehículo");

        if (!vehiculo.Activo)
            throw new BadRequestException($"El vehículo {vehiculo.Placa} está desactivado");

        var conductor = await _context.Conductores.FirstOrDefaultAsync(c => c.Id == request.ConductorId)
            ?? throw new BadRequestException("Elige el conductor");

        if (!conductor.Activo)
            throw new BadRequestException($"{conductor.Nombre} está desactivado");
    }

    /// <summary>
    /// Los pedidos del request que de verdad se pueden cargar.
    ///
    /// Se comprueba contra la base y no se confía en lo que llegó: entre que
    /// la pantalla listó los disponibles y se pulsó guardar, otro pudo cargar
    /// el mismo pedido en su camión.
    /// </summary>
    private async Task<List<int>> PedidosValidosAsync(DespachoRequest request, int? despachoId)
    {
        var pedidos = request.PedidoIds.Distinct().ToList();
        if (pedidos.Count == 0) return [];

        var disponibles = (await PedidosDisponiblesAsync(request.RutaId, despachoId))
            .Select(p => p.PedidoId)
            .ToHashSet();

        // Los que ya son de este despacho y siguen siendo suyos: entran igual.
        if (despachoId is int id)
        {
            var propios = await _context.Despachos
                .Where(d => d.Id == id)
                .SelectMany(d => d.Detalle)
                .Select(x => x.PedidoId)
                .ToListAsync();

            foreach (var pedidoId in propios) disponibles.Add(pedidoId);
        }

        var invalidos = pedidos.Where(p => !disponibles.Contains(p)).ToList();
        if (invalidos.Count > 0)
        {
            throw new BadRequestException(
                "Alguno de los pedidos ya no está disponible: puede que otro despacho lo haya tomado.");
        }

        return pedidos;
    }

    private async Task<string> SiguienteNumeroAsync()
    {
        var ultimo = await _context.Despachos
            .OrderByDescending(d => d.Id)
            .Select(d => d.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"DP-{correlativo:0000}";
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static DespachoResponse Map(Despacho d)
    {
        var pedidos = d.Detalle.Select(x => MapPedido(x.Pedido!)).ToList();

        return new DespachoResponse
        {
            Id = d.Id,
            Numero = d.Numero,
            Fecha = d.Fecha,
            RutaId = d.RutaId,
            Ruta = d.Ruta?.Nombre ?? string.Empty,
            VehiculoId = d.VehiculoId,
            Vehiculo = d.Vehiculo?.Placa ?? string.Empty,
            ConductorId = d.ConductorId,
            Conductor = d.Conductor?.Nombre ?? string.Empty,
            Estado = d.Estado,
            Observacion = d.Observacion,
            Usuario = d.Usuario?.Nombre,
            Pedidos = pedidos.Count,
            Total = pedidos.Sum(p => p.Total),
            Entregados = pedidos.Count(p => p.NotaVentaId is not null),
            Detalle = pedidos,
        };
    }

    private static DespachoPedidoResponse MapPedido(Pedido p)
    {
        var venta = p.Ventas.FirstOrDefault(v => v.Estado != EstadoNotaVenta.Anulada);
        var lineas = p.Detalle.Where(d => !d.Anulado).ToList();

        return new DespachoPedidoResponse
        {
            PedidoId = p.Id,
            Numero = p.Numero,
            ClienteId = p.ClienteId,
            Cliente = p.Cliente?.Nombre ?? string.Empty,
            Direccion = p.Cliente?.Direccion,
            Mercado = p.Cliente?.Mercado?.Nombre,
            Telefono = p.Cliente?.Telefono,
            Total = lineas.Sum(d => d.Cantidad * d.PrecioUnitario),
            Lineas = lineas.Count,
            NotaVentaId = venta?.Id,
            NotaVentaNumero = venta?.Numero,
        };
    }
}
