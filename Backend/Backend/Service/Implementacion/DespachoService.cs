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
            .Include(d => d.Rutas).ThenInclude(r => r.Ruta)
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

    /// <summary>Una línea de pedido de un camión, con lo que hace falta para sumarla al reporte de carga.</summary>
    private sealed class LineaPedido
    {
        public int Id { get; init; }
        public DateTime PedidoFecha { get; init; }
        public DateTime Registro { get; init; }
        public int? MercadoId { get; init; }
        public string? Mercado { get; init; }
        public int ProductoId { get; init; }
        public string Codigo { get; init; } = string.Empty;
        public string Producto { get; init; } = string.Empty;
        public int? PresentacionId { get; init; }
        public string? Presentacion { get; init; }
        public decimal Factor { get; init; }
        public string UnidadCodigo { get; init; } = string.Empty;
        public string UnidadNombre { get; init; } = string.Empty;
        public string UnidadBase { get; init; } = string.Empty;
        public decimal CantidadPresentacion { get; init; }
        public decimal Cantidad { get; init; }
        public bool Anulado { get; init; }
    }

    private IQueryable<LineaPedido> LineasDelDespacho(int id, bool conAnuladas) =>
        _context.PedidoDetalles
            .AsNoTracking()
            .Where(l => (conAnuladas || !l.Anulado)
                        && _context.Despachos.Where(d => d.Id == id)
                            .SelectMany(d => d.Detalle)
                            .Any(x => x.PedidoId == l.PedidoId))
            .Select(l => new LineaPedido
            {
                Id = l.Id,
                PedidoFecha = l.Pedido!.Fecha,
                Registro = l.Pedido.FechaCreacion,
                MercadoId = l.Pedido.Cliente!.MercadoId,
                Mercado = l.Pedido.Cliente.Mercado != null ? l.Pedido.Cliente.Mercado.Nombre : null,
                ProductoId = l.ProductoId,
                Codigo = l.Producto!.Codigo,
                Producto = l.Producto.Nombre,
                PresentacionId = l.PresentacionId,
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
                CantidadPresentacion = l.CantidadPresentacion,
                Cantidad = l.Cantidad,
                Anulado = l.Anulado,
            });

    /// <summary>Suma por mercado, producto y presentación las cantidades que se le pasan.</summary>
    private static List<LineaCargaResponse> AgruparCarga(
        IEnumerable<(LineaPedido Linea, decimal Presentaciones, decimal EnBase)> filas) =>
        filas
            .GroupBy(f => (f.Linea.MercadoId, f.Linea.ProductoId, f.Linea.PresentacionId))
            .Select(g =>
            {
                var l = g.First().Linea;
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
                    Cantidad = g.Sum(x => x.Presentaciones),
                    EnUnidadBase = g.Sum(x => x.EnBase),
                };
            })
            .ToList();

    public async Task<List<LineaCargaResponse>> LineasCargaAsync(int id)
    {
        if (!await _context.Despachos.AnyAsync(d => d.Id == id))
            throw new NotFoundException($"No existe el despacho {id}");

        var lineas = await LineasDelDespacho(id, conAnuladas: false).ToListAsync();

        return AgruparCarga(lineas.Select(l => (l, l.CantidadPresentacion, l.Cantidad)));
    }

    public async Task<(List<LineaCargaResponse> Lineas, DateTime DiaCarga)> LineasCargaCorteAsync(int id, int corte)
    {
        if (!CortesCarga.EsValido(corte))
            throw new BadRequestException("Elige un corte válido.");

        if (!await _context.Despachos.AnyAsync(d => d.Id == id))
            throw new NotFoundException($"No existe el despacho {id}");

        // Con las anuladas: una línea que hoy está quitada pudo estar pedida a
        // las 15:00, y la base tiene que contarla.
        var lineas = await LineasDelDespacho(id, conAnuladas: true).ToListAsync();

        /*
         * El día de carga es el de los PEDIDOS: el más reciente del camión. El
         * día en que se reparte no cuenta. Lo registrado en días anteriores
         * queda dentro de la base, porque el primer corte llega hasta las 15:00
         * de este día sin límite por atrás.
         */
        var diaCarga = lineas.Count == 0 ? Zona.Hoy : lineas.Max(l => Zona.DiaDe(l.PedidoFecha));
        var primerCorte = Zona.AUtc(diaCarga + CortesCarga.HoraPrimerCorte);
        var segundoCorte = Zona.AUtc(diaCarga + CortesCarga.HoraSegundoCorte);

        var historiales = await HistorialesAsync(lineas);

        var filas = new List<(LineaPedido, decimal, decimal)>();
        foreach (var l in lineas)
        {
            var h = historiales[l.Id];
            var actual = l.Anulado ? (0m, 0m) : (l.CantidadPresentacion, l.Cantidad);

            var (pres, bas) = corte switch
            {
                CortesCarga.Primero => h.En(primerCorte),
                CortesCarga.Segundo => Restar(h.En(segundoCorte), h.En(primerCorte)),
                // Del segundo corte en adelante hasta hoy: lo que queda por
                // sumar. Por diferencia con lo actual, así los tres cortes
                // suman siempre lo mismo que el camión completo.
                _ => Restar(actual, h.En(segundoCorte)),
            };

            if (pres != 0 || bas != 0) filas.Add((l, pres, bas));
        }

        return (AgruparCarga(filas).Where(l => l.Cantidad != 0 || l.EnUnidadBase != 0).ToList(), diaCarga);
    }

    private static (decimal, decimal) Restar((decimal Pres, decimal Bas) a, (decimal Pres, decimal Bas) b) =>
        (a.Pres - b.Pres, a.Bas - b.Bas);

    /// <summary>
    /// Cuánto valía una línea de pedido en cada momento, según el registro de
    /// cambios. Ese registro guarda la hora exacta de cada aumento, baja o
    /// anulación, que es lo único que permite cortar el día por horas.
    /// </summary>
    private sealed class HistorialLinea
    {
        private readonly List<(DateTime Desde, decimal Pres, decimal Bas, bool Anulado)> _puntos = [];

        public void Agregar(DateTime desde, decimal pres, decimal bas, bool anulado) =>
            _puntos.Add((desde, pres, bas, anulado));

        /// <summary>Lo que valía a esa hora; cero si el pedido todavía no existía o la línea estaba anulada.</summary>
        public (decimal Pres, decimal Bas) En(DateTime instante)
        {
            var punto = _puntos.LastOrDefault(p => p.Desde <= instante);
            return punto == default || punto.Anulado ? (0m, 0m) : (punto.Pres, punto.Bas);
        }
    }

    private async Task<Dictionary<int, HistorialLinea>> HistorialesAsync(List<LineaPedido> lineas)
    {
        var ids = lineas.Select(l => l.Id.ToString()).ToList();

        var eventos = ids.Count == 0
            ? []
            : await _context.RegistrosAuditoria
                .AsNoTracking()
                .Where(r => r.Entidad == nameof(PedidoDetalle) && ids.Contains(r.EntidadId))
                .OrderBy(r => r.Fecha).ThenBy(r => r.Id)
                .Select(r => new { r.EntidadId, r.Accion, r.Fecha, r.ValoresAnteriores, r.ValoresNuevos })
                .ToListAsync();

        var porLinea = eventos.ToLookup(e => e.EntidadId);
        var resultado = new Dictionary<int, HistorialLinea>();

        foreach (var l in lineas)
        {
            var propios = porLinea[l.Id.ToString()].ToList();
            var creado = propios.FirstOrDefault(e => e.Accion == AccionAuditoria.Creado);
            var cambios = propios.Where(e => e.Accion == AccionAuditoria.Actualizado).ToList();

            var pres = l.CantidadPresentacion;
            var bas = l.Cantidad;
            var anulado = l.Anulado;
            DateTime desde;

            if (creado is not null)
            {
                // El alta trae todos los valores: de ahí se parte.
                var inicial = Leer(creado.ValoresNuevos);
                pres = inicial.Pres ?? pres;
                bas = inicial.Bas ?? bas;
                anulado = inicial.Anulado ?? false;
                desde = creado.Fecha;
            }
            else
            {
                // Sin alta en el registro (una línea anterior a la bitácora): se
                // parte de lo que valía antes del primer cambio de cada dato, y
                // se da por existente desde que se creó el pedido.
                var vistoPres = false;
                var vistoBas = false;
                var vistoAnulado = false;
                foreach (var c in cambios)
                {
                    var antes = Leer(c.ValoresAnteriores);
                    if (!vistoPres && antes.Pres is not null) { pres = antes.Pres.Value; vistoPres = true; }
                    if (!vistoBas && antes.Bas is not null) { bas = antes.Bas.Value; vistoBas = true; }
                    if (!vistoAnulado && antes.Anulado is not null) { anulado = antes.Anulado.Value; vistoAnulado = true; }
                }
                desde = l.Registro;
            }

            var historial = new HistorialLinea();
            historial.Agregar(desde, pres, bas, anulado);

            foreach (var c in cambios)
            {
                var nuevo = Leer(c.ValoresNuevos);
                pres = nuevo.Pres ?? pres;
                bas = nuevo.Bas ?? bas;
                anulado = nuevo.Anulado ?? anulado;
                historial.Agregar(c.Fecha, pres, bas, anulado);
            }

            resultado[l.Id] = historial;
        }

        return resultado;
    }

    /// <summary>Lo que un registro de cambios dice de cantidad y anulación; lo que no dice, vacío.</summary>
    private static (decimal? Pres, decimal? Bas, bool? Anulado) Leer(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return (null, null, null);

        try
        {
            using var doc = System.Text.Json.JsonDocument.Parse(json);
            var raiz = doc.RootElement;

            decimal? Numero(string nombre) =>
                raiz.TryGetProperty(nombre, out var v) && v.ValueKind == System.Text.Json.JsonValueKind.Number
                    ? v.GetDecimal()
                    : null;

            bool? Bandera(string nombre) =>
                raiz.TryGetProperty(nombre, out var v)
                && v.ValueKind is System.Text.Json.JsonValueKind.True or System.Text.Json.JsonValueKind.False
                    ? v.GetBoolean()
                    : null;

            return (Numero(nameof(PedidoDetalle.CantidadPresentacion)), Numero(nameof(PedidoDetalle.Cantidad)),
                Bandera(nameof(PedidoDetalle.Anulado)));
        }
        catch (System.Text.Json.JsonException)
        {
            return (null, null, null);
        }
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
            Cortes = new[] { CortesCarga.Todos, CortesCarga.Primero, CortesCarga.Segundo, CortesCarga.Tercero }
                .Select(c => new OpcionCorteCarga { Codigo = c, Nombre = CortesCarga.Nombre(c) })
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
        IReadOnlyCollection<int> rutaIds, int? despachoId = null, DateTime? diaDeVisita = null)
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

        /*
         * El día de visita: el lunes solo salen los clientes que se visitan el lunes.
         *
         * Es la regla del reparto del sistema anterior —día de visita del cliente Y ruta dentro de las
         * de ese camión— y es lo que separa los ~110 clientes del lunes de las rutas 1 y 7 de los cerca
         * de 700 que suman las dos rutas enteras. Sin fecha no se filtra por día: es lo que se pide
         * cuando alguien decide, a propósito, llevar a un cliente atrasado.
         */
        var dia = diaDeVisita is DateTime fecha ? DiaSemana.De(fecha) : null;

        var pedidos = await _context.Pedidos
            .AsNoTracking()
            .Include(p => p.Cliente!).ThenInclude(c => c.Mercado)
            .Include(p => p.Cliente!).ThenInclude(c => c.Ruta)
            .Include(p => p.Detalle)
            .Include(p => p.Ventas)
            .Where(p => p.Estado == EstadoPedido.Pendiente
                        && p.Cliente!.RutaId != null
                        && rutaIds.Contains(p.Cliente!.RutaId!.Value)
                        && (dia == null || p.Cliente!.DiaVisita == dia)
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
            RutaId = RutasDe(request)[0],
            VehiculoId = request.VehiculoId,
            ConductorId = request.ConductorId,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId,
        };

        foreach (var rutaId in RutasDe(request))
        {
            despacho.Rutas.Add(new DespachoRuta { RutaId = rutaId });
        }

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
        despacho.RutaId = RutasDe(request)[0];
        despacho.VehiculoId = request.VehiculoId;

        // Las rutas se sincronizan: se quitan las que ya no van y se agregan las nuevas.
        var rutasNuevas = RutasDe(request);
        foreach (var quitar in despacho.Rutas.Where(r => !rutasNuevas.Contains(r.RutaId)).ToList())
        {
            despacho.Rutas.Remove(quitar);
        }
        foreach (var rutaId in rutasNuevas.Where(id => despacho.Rutas.All(r => r.RutaId != id)))
        {
            despacho.Rutas.Add(new DespachoRuta { RutaId = rutaId });
        }
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

        var rutas = RutasDe(request);
        if (rutas.Count == 0)
            throw new BadRequestException("Elige al menos una ruta");

        var existentes = await _context.Rutas.CountAsync(r => rutas.Contains(r.Id));
        if (existentes != rutas.Count)
            throw new BadRequestException("Alguna de las rutas elegidas no existe");

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

        // Sin filtro de día: el día es una comodidad al LISTAR. Quien decidió llevar a un cliente de otro
        // día ya lo eligió en pantalla, y aquí solo se comprueba que el pedido siga libre y sea de las rutas.
        var disponibles = (await PedidosDisponiblesAsync(RutasDe(request), despachoId))
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

    /// <summary>Las rutas del request, sin repetir y en el orden en que llegaron. Acepta el `RutaId` de antes.</summary>
    private static List<int> RutasDe(DespachoRequest request)
    {
        var rutas = request.RutaIds.Where(id => id > 0).Distinct().ToList();
        if (rutas.Count == 0 && request.RutaId > 0) rutas.Add(request.RutaId);
        return rutas;
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
            Ruta = string.Join(" · ", NombresDeRutas(d)),
            RutaIds = d.Rutas.OrderBy(r => r.Id).Select(r => r.RutaId).ToList(),
            Rutas = NombresDeRutas(d),
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

    /// <summary>Los nombres de las rutas del despacho; si es de los de antes (sin lista), la ruta principal.</summary>
    private static List<string> NombresDeRutas(Despacho d)
    {
        var nombres = d.Rutas.OrderBy(r => r.Id).Select(r => r.Ruta?.Nombre).OfType<string>().ToList();
        if (nombres.Count == 0 && d.Ruta?.Nombre is string principal) nombres.Add(principal);
        return nombres;
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
            RutaCliente = p.Cliente?.Ruta?.Nombre,
            DiaVisita = p.Cliente?.DiaVisita,
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
