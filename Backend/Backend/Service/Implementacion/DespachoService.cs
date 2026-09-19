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

    public async Task<IEnumerable<DespachoResponse>> GetAllAsync(string? estado = null)
    {
        var despachos = (await Completos()
                .AsNoTracking()
                .Where(d => estado == null || d.Estado == estado)
                .OrderByDescending(d => d.Fecha)
                .ThenByDescending(d => d.Id)
                .Take(300)
                .ToListAsync())
            .Select(Map)
            .ToList();

        await AnotarNovedadesAsync(despachos);
        return despachos;
    }

    public async Task<DespachoResponse> GetAsync(int id)
    {
        var despacho = Map(await BuscarAsync(id));
        await AnotarNovedadesAsync([despacho]);
        return despacho;
    }

    /// <summary>
    /// Suma a cada pedido lo que no se entregó: el motivo si se marcó entero
    /// como no entregado, y cuántos productos se recortaron si se entregó en
    /// parte. Sale de una sola consulta para todos los despachos de la lista.
    /// </summary>
    private async Task AnotarNovedadesAsync(List<DespachoResponse> despachos)
    {
        var ids = despachos.Select(d => d.Id).ToList();
        if (ids.Count == 0) return;

        var novedades = await _context.NovedadesEntrega
            .AsNoTracking()
            .Where(n => n.DespachoId != null && ids.Contains(n.DespachoId.Value)
                        && n.Estado != EstadoNovedad.Anulada)
            .Select(n => new
            {
                DespachoId = n.DespachoId!.Value,
                n.PedidoId,
                n.Tipo,
                Motivo = n.Motivo!.Nombre,
                n.Observacion,
            })
            .ToListAsync();

        var porPedido = novedades.ToLookup(n => (n.DespachoId, n.PedidoId));

        foreach (var despacho in despachos)
        {
            foreach (var pedido in despacho.Detalle)
            {
                var propias = porPedido[(despacho.Id, pedido.PedidoId)].ToList();

                // Ya se entregó (hay venta): una marca vieja de "no entregado"
                // no puede seguir apareciendo. Ventas la anula al confirmar,
                // esto es por si quedó alguna suelta.
                if (pedido.NotaVentaId is null)
                {
                    var entero = propias.FirstOrDefault(n => n.Tipo == TipoNovedad.Pedido);
                    pedido.NoEntregadoMotivo = entero?.Motivo;
                    pedido.NoEntregadoObservacion = entero?.Observacion;
                }

                pedido.LineasConNovedad = propias.Count(n => n.Tipo == TipoNovedad.Linea);
            }

            despacho.NoEntregados = despacho.Detalle.Count(p => p.NoEntregadoMotivo is not null);
        }
    }

    public async Task<List<LineaCargaResponse>> LineasCargaAsync(int id)
    {
        if (!await _context.Despachos.AnyAsync(d => d.Id == id))
            throw new NotFoundException($"No existe el despacho {id}");

        var lineas = await _context.PedidoDetalles
            .AsNoTracking()
            .Where(l => !l.Anulado
                        && _context.Despachos.Where(d => d.Id == id)
                            .SelectMany(d => d.Detalle)
                            .Any(x => x.PedidoId == l.PedidoId))
            .Select(l => new
            {
                MercadoId = l.Pedido!.Cliente!.MercadoId,
                Mercado = l.Pedido.Cliente.Mercado != null ? l.Pedido.Cliente.Mercado.Nombre : null,
                l.ProductoId,
                l.Producto!.Codigo,
                Producto = l.Producto.Nombre,
                l.PresentacionId,
                Presentacion = l.Presentacion != null ? l.Presentacion.Nombre : null,
                Factor = l.Presentacion != null ? l.Presentacion.Factor : 1m,
                // Sin presentación se vendió en la unidad base: esa es su unidad.
                UnidadCodigo = l.Presentacion != null
                    ? l.Presentacion.Unidad!.Codigo
                    : l.Producto.UnidadBase!.Codigo,
                UnidadNombre = l.Presentacion != null
                    ? l.Presentacion.Unidad!.Nombre
                    : l.Producto.UnidadBase!.Nombre,
                UnidadBase = l.Producto.UnidadBase!.Codigo,
                l.CantidadPresentacion,
                l.Cantidad,
            })
            .ToListAsync();

        return lineas
            .GroupBy(l => (l.MercadoId, l.ProductoId, l.PresentacionId))
            .Select(g =>
            {
                var l = g.First();
                return new LineaCargaResponse
                {
                    MercadoId = l.MercadoId ?? 0,
                    Mercado = l.Mercado ?? "Sin mercado",
                    ProductoId = l.ProductoId,
                    Codigo = l.Codigo,
                    Producto = l.Producto,
                    PresentacionId = l.PresentacionId,
                    Presentacion = l.Presentacion ?? l.UnidadBase,
                    Factor = l.Factor,
                    UnidadCodigo = l.UnidadCodigo,
                    UnidadNombre = l.UnidadNombre,
                    UnidadBase = l.UnidadBase,
                    Cantidad = g.Sum(x => x.CantidadPresentacion),
                    EnUnidadBase = g.Sum(x => x.Cantidad),
                };
            })
            .ToList();
    }

    public async Task<OpcionesCargaResponse> OpcionesCargaAsync(int id)
    {
        var despacho = await BuscarAsync(id);
        var lineas = await LineasCargaAsync(id);

        return new OpcionesCargaResponse
        {
            Mercados = despacho.Detalle
                .GroupBy(x => (Id: x.Pedido?.Cliente?.MercadoId ?? 0,
                               Nombre: x.Pedido?.Cliente?.Mercado?.Nombre ?? "Sin mercado"))
                .Select(g => new OpcionMercadoCarga { Id = g.Key.Id, Nombre = g.Key.Nombre, Pedidos = g.Count() })
                // Como número cuando lo es: 1, 7, 8, 11 y no 1, 11, 7, 8.
                .OrderBy(m => int.TryParse(m.Nombre, out _) ? 0 : 1)
                .ThenBy(m => int.TryParse(m.Nombre, out var n) ? n : int.MaxValue)
                .ThenBy(m => m.Nombre)
                .ToList(),
            Unidades = lineas
                .GroupBy(l => (l.UnidadCodigo, l.UnidadNombre))
                .Select(g => new OpcionUnidadCarga
                {
                    Codigo = g.Key.UnidadCodigo,
                    Nombre = g.Key.UnidadNombre,
                    Productos = g.Select(l => l.ProductoId).Distinct().Count(),
                })
                .OrderBy(u => u.Nombre)
                .ToList(),
        };
    }

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
            PedidosDesde = request.PedidosDesde?.Date,
            PedidosHasta = request.PedidosHasta?.Date,
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
        despacho.PedidosDesde = request.PedidosDesde?.Date;
        despacho.PedidosHasta = request.PedidosHasta?.Date;
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
        if (request.PedidosDesde is DateTime desde && request.PedidosHasta is DateTime hasta
            && desde.Date > hasta.Date)
        {
            throw new BadRequestException("El \"desde\" de los pedidos no puede ser después del \"hasta\".");
        }

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
            PedidosDesde = d.PedidosDesde,
            PedidosHasta = d.PedidosHasta,
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
            ClienteDocumento = p.Cliente?.Documento,
            Fecha = p.Fecha,
            Direccion = p.Cliente?.Direccion,
            Mercado = p.Cliente?.Mercado?.Nombre,
            Telefono = p.Cliente?.Telefono,
            /*
             * Con el precio pactado por presentación, no con el derivado por
             * unidad base.
             *
             * El precio por kilo sale de dividir —S/ 13.60 la bolsa de 3 kg son
             * 4.5333 el kilo— y al volver a multiplicar ya no cierra: un camión
             * de seis pedidos que suman S/ 1,399.00 salía en S/ 1,398.9997. Es
             * el mismo total que se le cobra al cliente, así que tiene que ser el
             * del pedido, céntimo por céntimo.
             */
            Total = lineas.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion),
            Lineas = lineas.Count,
            NotaVentaId = venta?.Id,
            NotaVentaNumero = venta?.Numero,
        };
    }
}
