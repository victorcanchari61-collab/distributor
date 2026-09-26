using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// El nucleo del inventario.
///
/// Reglas que sostienen todo:
///
///   - El stock NO se escribe: se calcula desde los movimientos. No existe un
///     campo "stock" que alguien actualice, porque el dia que un proceso falle
///     a la mitad quedaria mintiendo para siempre.
///   - Toda cantidad se guarda en unidad base. La presentacion se conserva
///     aparte para que el papel siga diciendo "2 sacos".
///   - Las entradas declaran su costo y crean una capa. Las salidas NO lo
///     declaran: lo heredan de las capas que consumen, de la mas antigua a la
///     mas nueva.
///   - Cada consumo queda registrado (ConsumoCapa). Es lo que permite que una
///     anulacion devuelva la mercaderia al costo con que salio.
///   - Un documento confirmado no se edita: se anula con otro documento.
///   - Todo ocurre dentro de una transaccion con las capas bloqueadas.
/// </summary>
public class InventarioService : IInventarioService
{
    private readonly IInventarioRepository _repository;
    private readonly IProductoRepository _productos;
    private readonly IValidator<CreateAlmacenRequest> _createAlmacen;
    private readonly IValidator<UpdateAlmacenRequest> _updateAlmacen;
    private readonly IValidator<CreateMotivoRequest> _createMotivo;
    private readonly IValidator<UpdateMotivoRequest> _updateMotivo;
    private readonly IValidator<CrearAjusteRequest> _ajusteValidator;
    private readonly IValidator<CrearTransferenciaRequest> _transferenciaValidator;
    private readonly IValidator<CrearPrestamoRequest> _prestamoValidator;
    private readonly IValidator<DevolverPrestamoRequest> _devolucionValidator;
    private readonly IValidator<CrearRecepcionRequest> _recepcionValidator;
    private readonly IComprasRepository _compras;
    private readonly IVentasRepository _ventas;
    private readonly INotificador _notificador;

    public InventarioService(
        IInventarioRepository repository,
        IProductoRepository productos,
        IValidator<CreateAlmacenRequest> createAlmacen,
        IValidator<UpdateAlmacenRequest> updateAlmacen,
        IValidator<CreateMotivoRequest> createMotivo,
        IValidator<UpdateMotivoRequest> updateMotivo,
        IValidator<CrearAjusteRequest> ajusteValidator,
        IValidator<CrearTransferenciaRequest> transferenciaValidator,
        IValidator<CrearPrestamoRequest> prestamoValidator,
        IValidator<DevolverPrestamoRequest> devolucionValidator,
        IValidator<CrearRecepcionRequest> recepcionValidator,
        IComprasRepository compras,
        IVentasRepository ventas,
        INotificador notificador)
    {
        _repository = repository;
        _productos = productos;
        _createAlmacen = createAlmacen;
        _updateAlmacen = updateAlmacen;
        _createMotivo = createMotivo;
        _updateMotivo = updateMotivo;
        _ajusteValidator = ajusteValidator;
        _transferenciaValidator = transferenciaValidator;
        _prestamoValidator = prestamoValidator;
        _devolucionValidator = devolucionValidator;
        _recepcionValidator = recepcionValidator;
        _compras = compras;
        _ventas = ventas;
        _notificador = notificador;
    }

    // ------------------------------------------------------------- Almacenes

    public async Task<IEnumerable<AlmacenResponse>> GetAlmacenesAsync()
    {
        var almacenes = await _repository.GetAlmacenesAsync();
        // Productos y valorizado de todos en una consulta. Antes era una por
        // almacén, y encima filtrando "producto 0": siempre daban cero.
        var totales = await _repository.GetTotalesPorAlmacenAsync();
        return almacenes.Select(a => MapAlmacen(a, totales.GetValueOrDefault(a.Id))).ToList();
    }

    public async Task<AlmacenResponse> GetAlmacenAsync(int id)
    {
        var almacen = await GetAlmacenOrThrowAsync(id);
        return MapAlmacen(almacen, (await _repository.GetTotalesPorAlmacenAsync(id)).GetValueOrDefault(id));
    }

    public async Task<AlmacenResponse> CreateAlmacenAsync(CreateAlmacenRequest request)
    {
        await _createAlmacen.ValidateAndThrowAsync(request);

        var codigo = request.Codigo.Trim().ToUpperInvariant();
        if (await _repository.ExisteCodigoAlmacenAsync(codigo))
        {
            throw new ConflictException("Ya existe un almacén con ese código");
        }

        // El primero es el principal: sin uno marcado, una entrada sin almacen
        // no sabria donde ir.
        var esPrimero = !(await _repository.GetAlmacenesAsync()).Any();

        var almacen = new Almacen
        {
            Codigo = codigo,
            Nombre = request.Nombre.Trim(),
            Direccion = Limpiar(request.Direccion),
            EsPrincipal = esPrimero || request.EsPrincipal,
            Activo = true
        };

        if (almacen.EsPrincipal && !esPrimero)
        {
            await QuitarPrincipalAsync();
        }

        await _repository.AddAlmacenAsync(almacen);
        var response = MapAlmacen(almacen, (0, 0m));
        await _notificador.AvisarAsync("almacenes", "creado", response);
        return response;
    }

    public async Task<AlmacenResponse> UpdateAlmacenAsync(int id, UpdateAlmacenRequest request)
    {
        await _updateAlmacen.ValidateAndThrowAsync(request);

        var almacen = await GetAlmacenOrThrowAsync(id);
        var codigo = request.Codigo.Trim().ToUpperInvariant();

        if (await _repository.ExisteCodigoAlmacenAsync(codigo, id))
        {
            throw new ConflictException("Ya existe un almacén con ese código");
        }

        if (request.EsPrincipal && !request.Activo)
        {
            throw new BadRequestException("El almacén principal no se puede desactivar");
        }

        // Siempre tiene que haber uno: para quitarle el principal a este,
        // se marca otro y este se desmarca solo.
        if (almacen.EsPrincipal && !request.EsPrincipal)
        {
            throw new BadRequestException("Marca otro almacén como principal; este dejará de serlo automáticamente");
        }

        if (request.EsPrincipal && !almacen.EsPrincipal)
        {
            await QuitarPrincipalAsync();
        }

        almacen.Codigo = codigo;
        almacen.Nombre = request.Nombre.Trim();
        almacen.Direccion = Limpiar(request.Direccion);
        almacen.EsPrincipal = request.EsPrincipal;
        almacen.Activo = request.Activo;

        await _repository.UpdateAlmacenAsync(almacen);
        var response = MapAlmacen(almacen, (await _repository.GetTotalesPorAlmacenAsync(id)).GetValueOrDefault(id));
        await _notificador.AvisarAsync("almacenes", "actualizado", response);
        return response;
    }

    /// <summary>Desmarca al principal actual: solo puede haber uno.</summary>
    private async Task QuitarPrincipalAsync()
    {
        foreach (var otro in (await _repository.GetAlmacenesAsync()).Where(a => a.EsPrincipal))
        {
            otro.EsPrincipal = false;
            await _repository.UpdateAlmacenAsync(otro);
        }
    }

    public async Task DeleteAlmacenAsync(int id)
    {
        var almacen = await GetAlmacenOrThrowAsync(id);

        if (almacen.EsPrincipal)
        {
            throw new BadRequestException("El almacén principal no se elimina");
        }

        var movimientos = await _repository.ContarMovimientosAlmacenAsync(id);
        if (movimientos > 0)
        {
            throw new BadRequestException(
                $"El almacén tiene {movimientos} movimiento(s). Desactívalo en vez de eliminarlo.");
        }

        await _repository.DeleteAlmacenAsync(almacen);
        await _notificador.AvisarAsync("almacenes", "eliminado", new { id });
    }

    // ---------------------------------------------------------------- Motivos

    public async Task<IEnumerable<MotivoResponse>> GetMotivosAsync()
    {
        var motivos = await _repository.GetMotivosAsync();
        var respuesta = new List<MotivoResponse>();

        foreach (var motivo in motivos)
        {
            respuesta.Add(MapMotivo(motivo, await _repository.ContarMovimientosMotivoAsync(motivo.Id)));
        }

        return respuesta;
    }

    public async Task<MotivoResponse> CreateMotivoAsync(CreateMotivoRequest request)
    {
        await _createMotivo.ValidateAndThrowAsync(request);

        var codigo = request.Codigo.Trim().ToUpperInvariant();
        if (await _repository.ExisteCodigoMotivoAsync(codigo))
        {
            throw new ConflictException("Ya existe un motivo con ese código");
        }

        var motivo = new MotivoMovimiento
        {
            Codigo = codigo,
            Nombre = request.Nombre.Trim(),
            Tipo = request.Tipo,
            DelSistema = false,
            // Si suma stock hay que decir cuanto costo; si resta, se hereda.
            PideCosto = request.Tipo == TipoMovimiento.Entrada,
            Activo = true
        };

        await _repository.AddMotivoAsync(motivo);
        var response = MapMotivo(motivo, 0);
        await _notificador.AvisarAsync("motivos", "creado", response);
        return response;
    }

    public async Task<MotivoResponse> UpdateMotivoAsync(int id, UpdateMotivoRequest request)
    {
        await _updateMotivo.ValidateAndThrowAsync(request);

        var motivo = await GetMotivoOrThrowAsync(id);

        // Los del sistema los usa cada venta y cada compra que se registre:
        // cambiarles el signo o el codigo descuadraria movimientos historicos.
        if (motivo.DelSistema)
        {
            throw new BadRequestException(
                "Los motivos del sistema no se modifican: los usa cada documento que mueve stock.");
        }

        var codigo = request.Codigo.Trim().ToUpperInvariant();
        if (await _repository.ExisteCodigoMotivoAsync(codigo, id))
        {
            throw new ConflictException("Ya existe un motivo con ese código");
        }

        var movimientos = await _repository.ContarMovimientosMotivoAsync(id);
        if (movimientos > 0 && request.Tipo != motivo.Tipo)
        {
            throw new BadRequestException(
                $"El motivo ya tiene {movimientos} movimiento(s): no se puede cambiar de entrada a salida.");
        }

        motivo.Codigo = codigo;
        motivo.Nombre = request.Nombre.Trim();
        motivo.Tipo = request.Tipo;
        motivo.PideCosto = request.Tipo == TipoMovimiento.Entrada;
        motivo.Activo = request.Activo;

        await _repository.UpdateMotivoAsync(motivo);
        var response = MapMotivo(motivo, movimientos);
        await _notificador.AvisarAsync("motivos", "actualizado", response);
        return response;
    }

    public async Task DeleteMotivoAsync(int id)
    {
        var motivo = await GetMotivoOrThrowAsync(id);

        if (motivo.DelSistema)
        {
            throw new BadRequestException("Los motivos del sistema no se eliminan");
        }

        var movimientos = await _repository.ContarMovimientosMotivoAsync(id);
        if (movimientos > 0)
        {
            throw new BadRequestException(
                $"El motivo tiene {movimientos} movimiento(s). Desactívalo en vez de eliminarlo.");
        }

        await _repository.DeleteMotivoAsync(motivo);
        await _notificador.AvisarAsync("motivos", "eliminado", new { id });
    }

    // ------------------------------------------------------------------ Stock

    public async Task<IEnumerable<StockResponse>> GetStockAsync(int? almacenId)
    {
        // Solo lo que de verdad entró al almacén: un producto recién importado
        // al catálogo no está "en" ningún almacén hasta que recibe mercadería.
        var productos = await _productos.GetConCapasAsync(almacenId);

        var ids = productos.Select(p => p.Id).ToList();
        var resumen = await _repository.GetResumenAsync(ids, almacenId);
        var almacen = almacenId is int id ? await _repository.GetAlmacenAsync(id) : null;
        var reservado = await _ventas.GetReservadoPorProductoAsync(almacenId);
        // Son todos los que tienen capas: se agrupa sin mandar la lista de ids.
        var actividad = await _repository.GetActividadAsync(null, almacenId, DiasDeRitmo);
        var transito = await _compras.GetEnTransitoPorProductoAsync();

        return productos.Select(p => MapStock(
            p, resumen.GetValueOrDefault(p.Id), reservado.GetValueOrDefault(p.Id),
            almacenId, almacen?.Nombre,
            actividad.GetValueOrDefault(p.Id), transito.GetValueOrDefault(p.Id)));
    }

    /// <summary>
    /// Cuántos días de ventas se miran para calcular el ritmo. Un mes: menos
    /// que eso y una semana floja dispara el número, más y no refleja la
    /// temporada en la que se está.
    /// </summary>
    private const int DiasDeRitmo = 30;

    /// <summary>
    /// Una página del stock. Los agregados (stock, valorizado, reservado) se
    /// piden SOLO para los productos de la página: eso es lo que evita recorrer
    /// el catálogo entero en cada carga.
    /// </summary>
    public async Task<PaginaResponse<StockResponse>> ListarStockAsync(
        ConsultaTablaRequest consulta, int? almacenId)
    {
        var (productos, total) = await _productos.ListarConStockAsync(consulta, almacenId);

        var ids = productos.Select(p => p.Id).ToList();
        var resumen = await _repository.GetResumenAsync(ids, almacenId);
        var almacen = almacenId is int id ? await _repository.GetAlmacenAsync(id) : null;
        var reservado = await _ventas.GetReservadoPorProductoAsync(almacenId, ids);
        var actividad = await _repository.GetActividadAsync(ids, almacenId, DiasDeRitmo);
        var transito = await _compras.GetEnTransitoPorProductoAsync(ids);
        var capas = (await _repository.GetCapasDisponiblesAsync(ids, almacenId)).ToLookup(c => c.ProductoId);

        return new PaginaResponse<StockResponse>
        {
            Items = productos.Select(p =>
            {
                var fila = MapStock(p, resumen.GetValueOrDefault(p.Id),
                                    reservado.GetValueOrDefault(p.Id),
                                    almacenId, almacen?.Nombre,
                                    actividad.GetValueOrDefault(p.Id),
                                    transito.GetValueOrDefault(p.Id));
                fila.Capas = capas[p.Id].Select(MapCapa).ToList();
                return fila;
            }).ToList(),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public Task<ResumenStockResponse> GetResumenStockAsync(int? almacenId) =>
        _repository.ResumenStockAsync(almacenId);

    private static StockResponse MapStock(
        Producto p, ResumenStock? r, decimal reservado, int? almacenId, string? almacen,
        ActividadStock? actividad = null, decimal enTransito = 0)
    {
        var stock = r?.Stock ?? 0;

        /*
         * Para cuantos dias alcanza.
         *
         * Es el stock dividido entre lo que se vende al dia, sacado del ultimo
         * mes. Sin ventas en ese mes no hay ritmo que proyectar y se devuelve
         * null: decir "alcanza para infinito" seria peor que no decir nada.
         */
        var porDia = (actividad?.VendidoReciente ?? 0) / DiasDeRitmo;
        int? diasStock = porDia > 0 ? (int)Math.Floor(stock / porDia) : null;

        return new StockResponse
        {
            ProductoId = p.Id,
            Codigo = p.Codigo,
            Producto = p.Nombre,
            Categoria = p.Categoria?.Nombre,
            Marca = p.Marca?.Nombre,
            UnidadBase = p.UnidadBase?.Codigo ?? string.Empty,
            AlmacenId = almacenId ?? 0,
            Almacen = almacen ?? "Todos",
            Stock = stock,
            Reservado = reservado,
            Disponible = stock - reservado,
            StockMinimo = p.StockMinimo,
            BajoMinimo = p.StockMinimo > 0 && stock <= p.StockMinimo,
            CostoActual = r?.CostoMin,
            CostoUltimo = r?.CostoMax,
            Valorizado = r?.Valorizado ?? 0,
            EnTransito = enTransito,
            UltimaEntrada = actividad?.UltimaEntrada,
            UltimaSalida = actividad?.UltimaSalida,
            DiasStock = diasStock,
        };
    }

    public async Task<StockResponse> GetStockProductoAsync(int productoId, int? almacenId)
    {
        var producto = await _productos.GetConDetalleAsync(productoId)
            ?? throw new NotFoundException($"No existe el producto {productoId}");

        var capas = await _repository.GetCapasDisponiblesAsync(productoId, almacenId);
        var ultima = await _repository.GetUltimaCapaAsync(productoId, almacenId);
        var almacen = almacenId is int id ? await _repository.GetAlmacenAsync(id) : null;
        var reservado = (await _ventas.GetReservadoPorProductoAsync(almacenId)).GetValueOrDefault(productoId);
        var stock = capas.Sum(c => c.CantidadDisponible);

        return new StockResponse
        {
            ProductoId = producto.Id,
            Codigo = producto.Codigo,
            Producto = producto.Nombre,
            Categoria = producto.Categoria?.Nombre,
            Marca = producto.Marca?.Nombre,
            UnidadBase = producto.UnidadBase?.Codigo ?? string.Empty,
            AlmacenId = almacenId ?? 0,
            Almacen = almacen?.Nombre ?? "Todos",
            Stock = stock,
            Reservado = reservado,
            Disponible = stock - reservado,
            StockMinimo = producto.StockMinimo,
            BajoMinimo = producto.StockMinimo > 0 && stock <= producto.StockMinimo,
            // La mas antigua con mercaderia: es la que se consume ahora.
            CostoActual = capas.FirstOrDefault()?.CostoUnitario,
            CostoUltimo = ultima?.CostoUnitario,
            Valorizado = capas.Sum(c => c.CantidadDisponible * c.CostoUnitario),
            Capas = capas.Select(MapCapa).ToList()
        };
    }

    public async Task<IEnumerable<LoteResponse>> GetLotesAsync()
    {
        var hoy = DateTime.UtcNow.Date;
        var capas = await _repository.GetCapasConVencimientoAsync();

        return capas.Select(c => new LoteResponse
        {
            CapaId = c.Id,
            ProductoId = c.ProductoId,
            Codigo = c.Producto?.Codigo ?? string.Empty,
            Producto = c.Producto?.Nombre ?? string.Empty,
            UnidadBase = c.Producto?.UnidadBase?.Codigo ?? string.Empty,
            AlmacenId = c.AlmacenId,
            Almacen = c.Almacen?.Nombre ?? string.Empty,
            Lote = c.Lote,
            FechaVencimiento = c.FechaVencimiento,
            DiasParaVencer = c.FechaVencimiento is DateTime v ? (v.Date - hoy).Days : null,
            CantidadDisponible = c.CantidadDisponible,
            CostoUnitario = c.CostoUnitario,
            Valor = Math.Round(c.CantidadDisponible * c.CostoUnitario, 2)
        });
    }

    // ----------------------------------------------------------------- Kardex

    /// <summary>
    /// Una página del kardex. El saldo no se puede calcular con solo las filas
    /// de la página — es un acumulado — así que el repositorio entrega además
    /// con cuánto entra cada producto a la página, y acá se sigue sumando
    /// desde ahí en orden cronológico.
    /// </summary>
    public async Task<PaginaResponse<KardexResponse>> ListarKardexAsync(
        ConsultaTablaRequest consulta, int? almacenId)
    {
        var (items, total, aperturas, intermedios) = await _repository.ListarKardexAsync(consulta, almacenId);

        var saldos = new Dictionary<(int, int), SaldoKardex>(aperturas);
        var porId = new Dictionary<int, (SaldoKardex Antes, SaldoKardex Despues)>();

        // Se recorre el libro real (los movimientos intermedios, estén o no en
        // la página) más las reservas de la página, que no mueven nada. Así el
        // saldo de cada fila es el verdadero aunque haya filtros.
        var recorrido = intermedios
            .Select(m => (m.Id, m.Fecha, m.ProductoId, m.AlmacenId, m.Tipo, m.Cantidad, m.CostoTotal))
            .Concat(items.Where(f => f.Tipo == TipoKardex.Reserva)
                .Select(f => (f.Id, f.Fecha, f.ProductoId, f.AlmacenId, f.Tipo, f.Cantidad, f.CostoTotal)));

        // Siempre de lo mas viejo a lo mas nuevo: es el unico orden en el que
        // un acumulado tiene sentido, sin importar como se pidio la pagina.
        foreach (var m in recorrido.OrderBy(m => m.Fecha).ThenBy(m => m.Id))
        {
            var clave = (m.ProductoId, m.AlmacenId);
            var antes = saldos.GetValueOrDefault(clave, new SaldoKardex(0, 0));
            var despues = Aplicar(antes, m.Tipo, m.Cantidad, m.CostoTotal);

            saldos[clave] = despues;
            porId[m.Id] = (antes, despues);
        }

        return new PaginaResponse<KardexResponse>
        {
            Items = items.Select(m => MapKardex(m, porId[m.Id].Antes, porId[m.Id].Despues)).ToList(),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public async Task<ResumenKardexResponse> GetResumenKardexAsync(int? almacenId)
    {
        var (entradas, salidas) = await _repository.ResumenKardexAsync(almacenId);
        return new ResumenKardexResponse { Entradas = entradas, Salidas = salidas };
    }

    /*
     * El saldo despues de un movimiento, en cantidad y en plata.
     *
     * Una entrada suma lo que costo; una salida resta lo que costaba la capa
     * que se consumio —no el precio al que se vendio—, que es lo que deja que
     * el valorizado del kardex cuadre con el del stock.
     */
    private static SaldoKardex Aplicar(SaldoKardex antes, string tipo, decimal cantidad, decimal costoTotal) =>
        tipo switch
        {
            // Una reserva no mueve nada: aparta. El stock queda igual antes y
            // despues, y por eso la fila se lee como un aviso y no como un
            // movimiento.
            TipoKardex.Reserva => antes,
            TipoMovimiento.Entrada =>
                new SaldoKardex(antes.Cantidad + cantidad, antes.Valor + costoTotal),
            _ => new SaldoKardex(antes.Cantidad - cantidad, antes.Valor - costoTotal),
        };

    /// <summary>
    /// Cuánto se puede prometer de cada producto: stock (capas con saldo) menos
    /// lo que apartan los pedidos pendientes. Nada de catálogo ni costos.
    /// </summary>
    public async Task<IEnumerable<DisponibleResponse>> GetDisponibleAsync(int? almacenId)
    {
        var stock = await _repository.GetStockPorProductoAsync(almacenId);
        var reservado = await _ventas.GetReservadoPorProductoAsync(almacenId);

        return stock.Keys.Union(reservado.Keys)
            .Select(id =>
            {
                var r = reservado.GetValueOrDefault(id);
                return new DisponibleResponse
                {
                    ProductoId = id,
                    Disponible = stock.GetValueOrDefault(id) - r,
                    Reservado = r,
                };
            })
            .ToList();
    }

    private static KardexResponse MapKardex(
        FilaKardex f, SaldoKardex antes, SaldoKardex despues) => new()
    {
        Id = f.Id,
        Fecha = f.Fecha,
        Documento = f.Documento,
        TipoDocumento = f.TipoDocumento,
        Motivo = f.Motivo,
        Tipo = f.Tipo,
        ProductoId = f.ProductoId,
        Producto = f.Producto,
        UnidadBase = f.UnidadBase,
        Almacen = f.Almacen,
        Presentacion = f.Presentacion,
        CantidadPresentacion = f.CantidadPresentacion,
        Cantidad = f.Cantidad,
        CostoUnitario = f.CostoUnitario,
        CostoTotal = f.CostoTotal,
        SaldoAnterior = antes.Cantidad,
        Saldo = despues.Cantidad,
        ValorizadoAnterior = Math.Round(antes.Valor, 2),
        Valorizado = Math.Round(despues.Valor, 2),
        Anulado = f.Anulado,
    };

    public async Task<IEnumerable<KardexResponse>> GetKardexAsync(
        int? productoId, int? almacenId, DateTime? desde, DateTime? hasta)
    {
        /*
         * Lo pide el APK sin fechas, y antes eso devolvía la tabla de
         * movimientos entera. Ahora: el último mes por defecto, nunca más de
         * un año, y cada producto arranca con el saldo que traía antes del
         * rango (no desde cero), así el saldo de cada fila sigue siendo el real.
         */
        var (inicio, fin) = Zona.RangoUtc(desde, hasta);
        var movimientos = await _repository.GetKardexAsync(productoId, almacenId, inicio, fin.AddTicks(-1));

        // El saldo se acumula por producto y almacen: mezclar dos productos en
        // una sola columna daria un numero sin sentido.
        var saldos = movimientos.Count == 0
            ? new Dictionary<(int, int), SaldoKardex>()
            : new Dictionary<(int, int), SaldoKardex>(
                await _repository.GetSaldosAntesAsync(inicio, movimientos.Select(m => m.ProductoId).Distinct(), almacenId));
        var respuesta = new List<KardexResponse>();

        foreach (var m in movimientos)
        {
            var clave = (m.ProductoId, m.AlmacenId);
            var antes = saldos.GetValueOrDefault(clave, new SaldoKardex(0, 0));
            // Este kardex —el que no pagina— sigue siendo solo de movimientos:
            // la entrada suma y la salida resta, sin reservas de por medio.
            var despues = m.Tipo == TipoMovimiento.Entrada
                ? new SaldoKardex(antes.Cantidad + m.Cantidad, antes.Valor + m.CostoTotal)
                : new SaldoKardex(antes.Cantidad - m.Cantidad, antes.Valor - m.CostoTotal);
            saldos[clave] = despues;

            respuesta.Add(new KardexResponse
            {
                Id = m.Id,
                Fecha = m.Fecha,
                Documento = m.Documento?.Numero ?? string.Empty,
                TipoDocumento = m.Documento?.Tipo ?? string.Empty,
                Motivo = m.Motivo?.Nombre ?? string.Empty,
                Tipo = m.Tipo,
                ProductoId = m.ProductoId,
                Producto = m.Producto?.Nombre ?? string.Empty,
                UnidadBase = m.Producto?.UnidadBase?.Codigo ?? string.Empty,
                Almacen = m.Almacen?.Nombre ?? string.Empty,
                Presentacion = m.Presentacion?.Nombre,
                CantidadPresentacion = m.CantidadPresentacion,
                Cantidad = m.Cantidad,
                CostoUnitario = m.CostoUnitario,
                CostoTotal = m.CostoTotal,
                SaldoAnterior = antes.Cantidad,
                Saldo = despues.Cantidad,
                ValorizadoAnterior = Math.Round(antes.Valor, 2),
                Valorizado = Math.Round(despues.Valor, 2),
                Anulado = m.Documento?.Estado == EstadoDocumento.Anulado
            });
        }

        // Se devuelve del mas nuevo al mas viejo, que es como se lee, pero el
        // saldo ya viene calculado en el orden correcto.
        respuesta.Reverse();
        return respuesta;
    }

    // ---------------------------------------------------------------- Ajustes

    public async Task<IEnumerable<DocumentoInventarioResponse>> GetDocumentosAsync(
        string? familia = null)
    {
        var documentos = (await _repository.GetDocumentosAsync(familia)).ToList();
        var respuesta = new List<DocumentoInventarioResponse>();

        foreach (var d in documentos)
        {
            var anuladoPor = d.Estado == EstadoDocumento.Anulado
                ? await _repository.GetNumeroAnulacionAsync(d.Id)
                : null;
            respuesta.Add(MapDocumento(d, conDetalle: false, anuladoPor));
        }

        return respuesta;
    }

    public async Task<PaginaResponse<DocumentoInventarioResponse>> ListarDocumentosAsync(
        ConsultaTablaRequest consulta, string? familia)
    {
        var (items, total) = await _repository.ListarDocumentosAsync(consulta, familia);
        foreach (var d in items) d.Total = Math.Round(d.Total, 2);

        return new PaginaResponse<DocumentoInventarioResponse>
        {
            Items = items,
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public async Task<ResumenDocumentosResponse> GetResumenDocumentosAsync(string? familia)
    {
        var (total, confirmados, anulados) = await _repository.ResumenDocumentosAsync(familia);
        return new ResumenDocumentosResponse
        {
            Total = total,
            Confirmados = confirmados,
            Anulados = anulados,
        };
    }

    public Task<ResumenPrestamosResponse> GetResumenPrestamosAsync() => _repository.ResumenPrestamosAsync();

    public async Task<PaginaResponse<PrestamoFilaResponse>> ListarPrestamosAsync(ConsultaTablaRequest consulta)
    {
        var (items, total) = await _repository.ListarPrestamosAsync(consulta);

        return new PaginaResponse<PrestamoFilaResponse>
        {
            Items = items,
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public async Task<DocumentoInventarioResponse> GetDocumentoAsync(int id)
    {
        var documento = await _repository.GetDocumentoAsync(id)
            ?? throw new NotFoundException($"No existe el documento {id}");

        var anuladoPor = documento.Estado == EstadoDocumento.Anulado
            ? await _repository.GetNumeroAnulacionAsync(id)
            : null;

        return MapDocumento(documento, conDetalle: true, anuladoPor);
    }

    public async Task<DocumentoInventarioResponse> CrearAjusteAsync(
        CrearAjusteRequest request, int? usuarioId)
    {
        await _ajusteValidator.ValidateAndThrowAsync(request);

        var almacen = await GetAlmacenOrThrowAsync(request.AlmacenId);
        if (!almacen.Activo)
        {
            throw new BadRequestException("El almacén está desactivado");
        }

        var motivo = await GetMotivoOrThrowAsync(request.MotivoId);

        // Un ajuste solo admite motivos manuales: si se pudiera elegir "Venta"
        // a mano, el stock bajaria sin que exista la venta.
        if (motivo.DelSistema)
        {
            throw new BadRequestException(
                $"'{motivo.Nombre}' lo genera un documento del sistema; no se elige en un ajuste.");
        }

        if (!motivo.Activo)
        {
            throw new BadRequestException("El motivo está desactivado");
        }

        var esEntrada = motivo.Tipo == TipoMovimiento.Entrada;
        var fecha = request.Fecha ?? DateTime.UtcNow;

        var documento = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.Ajuste),
            Tipo = TipoDocumentoInventario.Ajuste,
            AlmacenId = almacen.Id,
            MotivoId = motivo.Id,
            Fecha = fecha,
            Estado = EstadoDocumento.Confirmado,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId
        };

        // Transaccion: descontar capas, grabar consumos y crear movimientos es
        // una sola cosa. A medias dejaria el stock mintiendo.
        await using var transaccion = await _repository.IniciarTransaccionAsync();

        await _repository.AddDocumentoAsync(documento);
        await _repository.GuardarAsync();

        // El flete se reparte entre las lineas segun lo que pesa cada una en el
        // total: la linea mas cara carga mas flete.
        var baseFlete = request.Detalle.Sum(l => (l.CostoPresentacion ?? 0) * l.Cantidad);

        foreach (var linea in request.Detalle)
        {
            var producto = await _productos.GetConDetalleAsync(linea.ProductoId)
                ?? throw new BadRequestException($"No existe el producto {linea.ProductoId}");

            if (!producto.ControlaStock)
            {
                throw new BadRequestException(
                    $"'{producto.Nombre}' no controla stock: no puede entrar en un ajuste.");
            }

            var (factor, presentacion) = await ResolverFactorAsync(linea.PresentacionId, producto);
            var cantidad = linea.Cantidad * factor;

            var movimiento = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = producto.Id,
                AlmacenId = almacen.Id,
                MotivoId = motivo.Id,
                Tipo = motivo.Tipo,
                PresentacionId = presentacion?.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidad,
                Fecha = fecha
            };

            if (esEntrada)
            {
                var costoLinea = (linea.CostoPresentacion ?? 0) * linea.Cantidad;

                // Reparto proporcional del flete; si nada tiene costo, se
                // reparte por cantidad para no perder la plata del flete.
                var flete = baseFlete > 0
                    ? request.Flete * (costoLinea / baseFlete)
                    : request.Flete / request.Detalle.Count;

                movimiento.CostoUnitario = cantidad == 0
                    ? 0
                    : Math.Round((costoLinea + flete) / cantidad, 4);
                movimiento.CostoTotal = Math.Round(costoLinea + flete, 4);

                await _repository.AddDocumentoMovimientoAsync(movimiento);
                await _repository.GuardarAsync();

                await _repository.AddCapaAsync(new CapaCosto
                {
                    ProductoId = producto.Id,
                    AlmacenId = almacen.Id,
                    MovimientoId = movimiento.Id,
                    CantidadInicial = cantidad,
                    CantidadDisponible = cantidad,
                    CostoUnitario = movimiento.CostoUnitario,
                    Lote = Limpiar(linea.Lote),
                    FechaVencimiento = linea.FechaVencimiento,
                    Origen = motivo.Id == Motivos.CargaInicial
                        ? OrigenCapa.CargaInicial
                        : OrigenCapa.Ajuste,
                    Fecha = fecha
                });
                await _repository.GuardarAsync();
            }
            else
            {
                await _repository.AddDocumentoMovimientoAsync(movimiento);
                await _repository.GuardarAsync();

                // El costo NO se declara: sale de las capas que se consumen.
                await ConsumirAsync(movimiento, producto, almacen.Id, cantidad);
            }
        }

        await transaccion.CommitAsync();

        var creado = await GetDocumentoAsync(documento.Id);
        await _notificador.AvisarAsync("ajustes", "creado", creado);
        await _notificador.AvisarAsync("stock", "cambio", new { almacenId = almacen.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { almacenId = almacen.Id });
        return creado;
    }

    // ----------------------------------------------------------- Transferencias

    public async Task<DocumentoInventarioResponse> CrearTransferenciaAsync(
        CrearTransferenciaRequest request, int? usuarioId)
    {
        await _transferenciaValidator.ValidateAndThrowAsync(request);

        var origen = await GetAlmacenOrThrowAsync(request.AlmacenOrigenId);
        var destino = await GetAlmacenOrThrowAsync(request.AlmacenDestinoId);

        if (!origen.Activo) throw new BadRequestException("El almacén de origen está desactivado");
        if (!destino.Activo) throw new BadRequestException("El almacén de destino está desactivado");

        var motivoSalida = await GetMotivoOrThrowAsync(Motivos.TransferenciaSalida);
        var motivoIngreso = await GetMotivoOrThrowAsync(Motivos.TransferenciaIngreso);
        var fecha = request.Fecha ?? DateTime.UtcNow;

        var documento = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.Transferencia),
            Tipo = TipoDocumentoInventario.Transferencia,
            AlmacenId = origen.Id,
            AlmacenDestinoId = destino.Id,
            MotivoId = motivoSalida.Id,
            Fecha = fecha,
            Estado = EstadoDocumento.Confirmado,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId
        };

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        await _repository.AddDocumentoAsync(documento);
        await _repository.GuardarAsync();

        foreach (var linea in request.Detalle)
        {
            var producto = await _productos.GetConDetalleAsync(linea.ProductoId)
                ?? throw new BadRequestException($"No existe el producto {linea.ProductoId}");

            if (!producto.ControlaStock)
            {
                throw new BadRequestException(
                    $"'{producto.Nombre}' no controla stock: no se puede transferir.");
            }

            var (factor, presentacion) = await ResolverFactorAsync(linea.PresentacionId, producto);
            var cantidad = linea.Cantidad * factor;

            var salida = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = producto.Id,
                AlmacenId = origen.Id,
                MotivoId = motivoSalida.Id,
                Tipo = TipoMovimiento.Salida,
                PresentacionId = presentacion?.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidad,
                Fecha = fecha
            };

            await _repository.AddDocumentoMovimientoAsync(salida);
            await _repository.GuardarAsync();

            // El costo NO se declara: es el mismo con el que la mercaderia
            // estaba en origen. ConsumirAsync ya deja registrado de que capas
            // salio, en ConsumoCapa.
            await ConsumirAsync(salida, producto, origen.Id, cantidad);

            var entrada = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = producto.Id,
                AlmacenId = destino.Id,
                MotivoId = motivoIngreso.Id,
                Tipo = TipoMovimiento.Entrada,
                PresentacionId = presentacion?.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidad,
                CostoUnitario = salida.CostoUnitario,
                CostoTotal = salida.CostoTotal,
                Fecha = fecha
            };

            await _repository.AddDocumentoMovimientoAsync(entrada);
            await _repository.GuardarAsync();

            // Una capa nueva en destino por cada capa que se toco en origen:
            // preserva el costo exacto de cada una, en vez de promediarlas. El
            // lote y el vencimiento viajan con la mercadería: siguen siendo el
            // mismo lote, solo cambió de almacén.
            foreach (var consumo in await _repository.GetConsumosAsync(salida.Id))
            {
                await _repository.AddCapaAsync(new CapaCosto
                {
                    ProductoId = producto.Id,
                    AlmacenId = destino.Id,
                    MovimientoId = entrada.Id,
                    CantidadInicial = consumo.Cantidad,
                    CantidadDisponible = consumo.Cantidad,
                    CostoUnitario = consumo.CostoUnitario,
                    Lote = consumo.Capa?.Lote,
                    FechaVencimiento = consumo.Capa?.FechaVencimiento,
                    Origen = OrigenCapa.Transferencia,
                    Fecha = fecha
                });
            }

            await _repository.GuardarAsync();
        }

        await transaccion.CommitAsync();

        var creada = await GetDocumentoAsync(documento.Id);
        await _notificador.AvisarAsync("transferencias", "creado", creada);
        await _notificador.AvisarAsync("stock", "cambio", new { origen = origen.Id, destino = destino.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { origen = origen.Id, destino = destino.Id });
        return creada;
    }

    public async Task<DocumentoInventarioResponse> AnularAsync(int documentoId, int? usuarioId)
    {
        var original = await _repository.GetDocumentoAsync(documentoId)
            ?? throw new NotFoundException($"No existe el documento {documentoId}");

        if (original.Estado == EstadoDocumento.Anulado)
        {
            throw new BadRequestException("El documento ya está anulado");
        }

        if (original.Tipo == TipoDocumentoInventario.Anulacion)
        {
            throw new BadRequestException("Una anulación no se anula. Registra un ajuste nuevo.");
        }

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        var anulacion = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.Anulacion),
            Tipo = TipoDocumentoInventario.Anulacion,
            AlmacenId = original.AlmacenId,
            AlmacenDestinoId = original.AlmacenDestinoId,
            CompraId = original.CompraId,
            MotivoId = original.MotivoId,
            Fecha = DateTime.UtcNow,
            Estado = EstadoDocumento.Confirmado,
            Observacion = $"Anula {original.Numero}",
            UsuarioId = usuarioId,
            DocumentoAnuladoId = original.Id
        };

        await _repository.AddDocumentoAsync(anulacion);
        await _repository.GuardarAsync();

        foreach (var m in original.Movimientos)
        {
            // Por movimiento, no por documento: una transferencia trae en el
            // MISMO documento una salida (origen) y una entrada (destino), con
            // motivos distintos. Decidirlo a nivel de documento invertiria mal
            // la mitad de las lineas.
            var eraEntrada = m.Tipo == TipoMovimiento.Entrada;

            // Una recepción o una venta anulada se tipifican distinto
            // (COMPRA_ANULADA, VENTA_ANULADA) en vez del motivo original: son
            // movimientos de sentido contrario y conviene poder distinguirlos
            // en el kardex, igual que ya estaba sembrado el motivo.
            var motivoEspejoId = m.CompraDetalleId is not null
                ? Motivos.CompraAnulada
                : m.NotaVentaDetalleId is not null
                    ? Motivos.VentaAnulada
                    : m.MotivoId;

            var espejo = new MovimientoInventario
            {
                DocumentoId = anulacion.Id,
                ProductoId = m.ProductoId,
                AlmacenId = m.AlmacenId,
                MotivoId = motivoEspejoId,
                // Signo invertido: lo que entro sale y lo que salio entra.
                Tipo = eraEntrada ? TipoMovimiento.Salida : TipoMovimiento.Entrada,
                PresentacionId = m.PresentacionId,
                CantidadPresentacion = m.CantidadPresentacion,
                Cantidad = m.Cantidad,
                CostoUnitario = m.CostoUnitario,
                CostoTotal = m.CostoTotal,
                Fecha = anulacion.Fecha,
                MovimientoOrigenId = m.Id
            };

            await _repository.AddDocumentoMovimientoAsync(espejo);
            await _repository.GuardarAsync();

            if (eraEntrada)
            {
                // Se retiran las capas que creo (una transferencia puede crear
                // varias, una por cada costo de origen). Si ya se uso algo de
                // cualquiera de ellas, no hay nada que retirar sin descuadrar
                // el costo de lo que ya salio.
                var capas = await _repository.GetCapasDeMovimientoAsync(m.Id);
                if (capas.Count == 0)
                {
                    throw new BadRequestException("No se encontró la mercadería de este documento.");
                }

                if (capas.Any(c => c.CantidadDisponible < c.CantidadInicial))
                {
                    throw new BadRequestException(
                        "No se puede anular: ya se vendió o se usó parte de esta mercadería. "
                        + "Registra un ajuste de salida por la diferencia.");
                }

                foreach (var capa in capas)
                {
                    capa.CantidadDisponible = 0;
                }

                // Era una recepción: la línea de la compra vuelve a quedar
                // pendiente por lo que se está devolviendo, y la compra baja
                // de estado si ya no queda nada recibido.
                if (m.CompraDetalleId is int compraDetalleId)
                {
                    var detalle = await _compras.GetCompraDetalleConCompraAsync(compraDetalleId);
                    if (detalle?.Compra is not null)
                    {
                        detalle.CantidadRecibida -= m.Cantidad;
                        detalle.Compra.Estado = detalle.Compra.Detalle.All(d => d.CantidadRecibida <= 0)
                            ? EstadoCompra.Pendiente
                            : detalle.Compra.Detalle.All(d => d.CantidadRecibida >= d.Cantidad)
                                ? EstadoCompra.RecibidaTotal
                                : EstadoCompra.RecibidaParcial;
                        await _compras.GuardarAsync();
                    }
                }
            }
            else
            {
                // Se devuelve a las MISMAS capas de las que salio, al costo que
                // tenian entonces. Reponer al costo de hoy inventaria utilidad.
                foreach (var consumo in await _repository.GetConsumosAsync(m.Id))
                {
                    var capa = await _repository.GetCapaAsync(consumo.CapaId);
                    if (capa is null) continue;

                    capa.CantidadDisponible += consumo.Cantidad;
                }
            }

            // Era una devolución de préstamo, en cualquiera de los dos sentidos
            // (vuelve mercadería propia, o sale la que se estaba devolviendo):
            // la línea deja de contar esto como devuelto, y el préstamo vuelve
            // a Pendiente si ya se había marcado Devuelto.
            if (m.PrestamoDetalleId is int prestamoDetalleId)
            {
                var detalle = await _repository.GetPrestamoDetalleConPrestamoAsync(prestamoDetalleId);
                if (detalle?.Prestamo is not null)
                {
                    detalle.CantidadDevuelta -= m.Cantidad;
                    detalle.Prestamo.Estado = detalle.Prestamo.Detalle.All(d => d.CantidadDevuelta >= d.Cantidad)
                        ? EstadoPrestamo.Devuelto
                        : EstadoPrestamo.Pendiente;
                }
            }

            await _repository.GuardarAsync();
        }

        original.Estado = EstadoDocumento.Anulado;
        await _repository.UpdateDocumentoAsync(original);

        await transaccion.CommitAsync();

        var response = await GetDocumentoAsync(anulacion.Id);
        var modulo = original.Tipo switch
        {
            TipoDocumentoInventario.Transferencia => "transferencias",
            TipoDocumentoInventario.Recepcion => "recepciones",
            TipoDocumentoInventario.NotaVenta => "notasventa",
            TipoDocumentoInventario.Prestamo or TipoDocumentoInventario.DevolucionPrestamo => "prestamos",
            _ => "ajustes"
        };
        await _notificador.AvisarAsync(modulo, "anulado", response);
        if (original.Tipo == TipoDocumentoInventario.Recepcion)
        {
            await _notificador.AvisarAsync("compras", "actualizado", new { compraId = original.CompraId });
        }
        await _notificador.AvisarAsync("stock", "cambio", new { documentoId = original.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { documentoId = original.Id });
        return response;
    }

    // ---------------------------------------------------------- Recepciones

    public async Task<DocumentoInventarioResponse> CrearRecepcionAsync(
        CrearRecepcionRequest request, int? usuarioId)
    {
        await _recepcionValidator.ValidateAndThrowAsync(request);

        var almacen = await GetAlmacenOrThrowAsync(request.AlmacenId);
        if (!almacen.Activo) throw new BadRequestException("El almacén está desactivado");

        var compra = await _compras.GetCompraAsync(request.CompraId)
            ?? throw new NotFoundException($"No existe la compra {request.CompraId}");

        if (compra.Estado == EstadoCompra.Anulada)
        {
            throw new BadRequestException("Esta compra está anulada.");
        }

        if (compra.Estado == EstadoCompra.RecibidaTotal)
        {
            throw new BadRequestException("Esta compra ya se recibió por completo.");
        }

        var motivo = await GetMotivoOrThrowAsync(Motivos.Compra);
        var fecha = request.Fecha ?? DateTime.UtcNow;

        var documento = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.Recepcion),
            Tipo = TipoDocumentoInventario.Recepcion,
            AlmacenId = almacen.Id,
            MotivoId = motivo.Id,
            CompraId = compra.Id,
            Fecha = fecha,
            Estado = EstadoDocumento.Confirmado,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId
        };

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        await _repository.AddDocumentoAsync(documento);
        await _repository.GuardarAsync();

        foreach (var linea in request.Detalle)
        {
            var detalle = compra.Detalle.FirstOrDefault(d => d.Id == linea.CompraDetalleId)
                ?? throw new BadRequestException(
                    $"La línea {linea.CompraDetalleId} no pertenece a esta compra.");

            var pendiente = detalle.Cantidad - detalle.CantidadRecibida;
            if (linea.Cantidad > pendiente)
            {
                throw new BadRequestException(
                    $"'{detalle.Producto?.Nombre}': quedan {pendiente} {detalle.Producto?.UnidadBase?.Codigo} "
                    + "por recibir, no se puede recibir más que eso.");
            }

            var movimiento = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = detalle.ProductoId,
                AlmacenId = almacen.Id,
                MotivoId = motivo.Id,
                Tipo = motivo.Tipo,
                PresentacionId = detalle.PresentacionId,
                // Igual que en una devolución de préstamo: se registra en
                // unidad base, que es lo único que no cambia si llega solo
                // una parte de lo pactado en la línea.
                CantidadPresentacion = linea.Cantidad,
                Cantidad = linea.Cantidad,
                CostoUnitario = detalle.CostoUnitario,
                CostoTotal = Math.Round(linea.Cantidad * detalle.CostoUnitario, 4),
                Fecha = fecha,
                CompraDetalleId = detalle.Id
            };

            await _repository.AddDocumentoMovimientoAsync(movimiento);
            await _repository.GuardarAsync();

            await _repository.AddCapaAsync(new CapaCosto
            {
                ProductoId = detalle.ProductoId,
                AlmacenId = almacen.Id,
                MovimientoId = movimiento.Id,
                CantidadInicial = linea.Cantidad,
                CantidadDisponible = linea.Cantidad,
                CostoUnitario = detalle.CostoUnitario,
                Lote = Limpiar(linea.Lote),
                FechaVencimiento = linea.FechaVencimiento,
                Origen = OrigenCapa.Compra,
                Fecha = fecha
            });
            await _repository.GuardarAsync();

            detalle.CantidadRecibida += linea.Cantidad;
        }

        compra.Estado = compra.Detalle.All(d => d.CantidadRecibida >= d.Cantidad)
            ? EstadoCompra.RecibidaTotal
            : EstadoCompra.RecibidaParcial;
        await _compras.UpdateCompraAsync(compra);

        await transaccion.CommitAsync();

        var creada = await GetDocumentoAsync(documento.Id);
        await _notificador.AvisarAsync("recepciones", "creado", creada);
        await _notificador.AvisarAsync("compras", "actualizado", new { compraId = compra.Id });
        await _notificador.AvisarAsync("stock", "cambio", new { almacenId = almacen.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { almacenId = almacen.Id });
        return creada;
    }

    // ------------------------------------------------------------------ Ventas

    public async Task<DocumentoInventarioResponse> CrearSalidaVentaAsync(NotaVenta notaVenta, int? usuarioId)
    {
        var almacen = await GetAlmacenOrThrowAsync(notaVenta.AlmacenId);
        var motivo = await GetMotivoOrThrowAsync(Motivos.Venta);
        var fecha = notaVenta.Fecha;

        var documento = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.NotaVenta),
            Tipo = TipoDocumentoInventario.NotaVenta,
            AlmacenId = almacen.Id,
            MotivoId = motivo.Id,
            NotaVentaId = notaVenta.Id,
            Fecha = fecha,
            Estado = EstadoDocumento.Confirmado,
            UsuarioId = usuarioId
        };

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        await _repository.AddDocumentoAsync(documento);
        await _repository.GuardarAsync();

        // Una línea anulada al editar la nota no debe salir del almacén: se
        // conserva solo para el historial, igual que en un Pedido.
        foreach (var linea in notaVenta.Detalle.Where(d => !d.Anulado))
        {
            var producto = await _productos.GetConDetalleAsync(linea.ProductoId)
                ?? throw new BadRequestException($"No existe el producto {linea.ProductoId}");

            var movimiento = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = producto.Id,
                AlmacenId = almacen.Id,
                MotivoId = motivo.Id,
                Tipo = motivo.Tipo,
                PresentacionId = linea.PresentacionId,
                CantidadPresentacion = linea.CantidadPresentacion,
                Cantidad = linea.Cantidad,
                Fecha = fecha,
                NotaVentaDetalleId = linea.Id
            };

            await _repository.AddDocumentoMovimientoAsync(movimiento);
            await _repository.GuardarAsync();

            // El costo NO se declara: sale de las capas que se consumen, mas
            // antiguas primero — la venta se lleva lo que ya estaba, no lo que
            // se cobra por ella.
            await ConsumirAsync(movimiento, producto, almacen.Id, linea.Cantidad);
        }

        await transaccion.CommitAsync();

        var creado = await GetDocumentoAsync(documento.Id);
        await _notificador.AvisarAsync("stock", "cambio", new { almacenId = almacen.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { almacenId = almacen.Id });
        return creado;
    }


    public async Task<DocumentoInventarioResponse> CrearDevolucionClienteAsync(
        Devolucion devolucion, int? usuarioId)
    {
        var almacen = await GetAlmacenOrThrowAsync(devolucion.AlmacenId);
        var entrada = await GetMotivoOrThrowAsync(Motivos.DevolucionCliente);
        var merma = await GetMotivoOrThrowAsync(Motivos.Merma);
        var fecha = DateTime.UtcNow;

        var documento = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.DevolucionCliente),
            Tipo = TipoDocumentoInventario.DevolucionCliente,
            AlmacenId = almacen.Id,
            MotivoId = entrada.Id,
            NotaVentaId = devolucion.NotaVentaId,
            Fecha = fecha,
            Estado = EstadoDocumento.Confirmado,
            Observacion = $"Devolución {devolucion.Numero}",
            UsuarioId = usuarioId
        };

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        await _repository.AddDocumentoAsync(documento);
        await _repository.GuardarAsync();

        foreach (var linea in devolucion.Detalle)
        {
            var venta = linea.NotaVentaDetalle
                ?? throw new BadRequestException("La línea devuelta no tiene su línea de venta.");

            var producto = await _productos.GetConDetalleAsync(venta.ProductoId)
                ?? throw new BadRequestException($"No existe el producto {venta.ProductoId}");

            var movimiento = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = producto.Id,
                AlmacenId = almacen.Id,
                MotivoId = entrada.Id,
                Tipo = TipoMovimiento.Entrada,
                PresentacionId = venta.PresentacionId,
                CantidadPresentacion = linea.CantidadPresentacion,
                Cantidad = linea.Cantidad,
                Fecha = fecha,
                NotaVentaDetalleId = venta.Id
            };

            await _repository.AddDocumentoMovimientoAsync(movimiento);
            await _repository.GuardarAsync();

            var repuesto = await ReponerDeLaVentaAsync(movimiento, venta, linea.Cantidad, almacen.Id);

            movimiento.CostoUnitario = linea.Cantidad > 0 ? repuesto / linea.Cantidad : 0m;
            movimiento.CostoTotal = repuesto;
            await _repository.GuardarAsync();

            if (linea.ReingresaStock) continue;

            /*
             * Lo dañado entra y sale en el acto.
             *
             * Podria no entrar nunca, pero entonces la mercaderia se esfumaria
             * del sistema: no habria forma de responder cuanto se perdio por
             * devoluciones en mal estado. Asi queda una entrada y una merma.
             */
            var baja = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = producto.Id,
                AlmacenId = almacen.Id,
                MotivoId = merma.Id,
                Tipo = TipoMovimiento.Salida,
                PresentacionId = venta.PresentacionId,
                CantidadPresentacion = linea.CantidadPresentacion,
                Cantidad = linea.Cantidad,
                Fecha = fecha,
                NotaVentaDetalleId = venta.Id
            };

            await _repository.AddDocumentoMovimientoAsync(baja);
            await _repository.GuardarAsync();

            await ConsumirAsync(baja, producto, almacen.Id, linea.Cantidad);
        }

        await transaccion.CommitAsync();

        var creado = await GetDocumentoAsync(documento.Id);
        await _notificador.AvisarAsync("stock", "cambio", new { almacenId = almacen.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { almacenId = almacen.Id });
        return creado;
    }

    public async Task<DocumentoInventarioResponse> CrearRecojoAsync(RecojoVenta recojo, int? usuarioId)
    {
        var almacenId = recojo.AlmacenId
            ?? throw new BadRequestException("El recojo todavía no tiene almacén: hay que verificarlo primero.");
        var almacen = await GetAlmacenOrThrowAsync(almacenId);
        var entrada = await GetMotivoOrThrowAsync(Motivos.DevolucionCliente);
        var producto = await _productos.GetConDetalleAsync(recojo.ProductoId)
            ?? throw new BadRequestException($"No existe el producto {recojo.ProductoId}");
        var fecha = DateTime.UtcNow;

        var documento = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.Recojo),
            Tipo = TipoDocumentoInventario.Recojo,
            AlmacenId = almacen.Id,
            MotivoId = entrada.Id,
            NotaVentaId = recojo.NotaVentaId,
            Fecha = fecha,
            Estado = EstadoDocumento.Confirmado,
            Observacion = $"Recojo en {recojo.NotaVenta?.Numero ?? $"venta {recojo.NotaVentaId}"}",
            UsuarioId = usuarioId,
        };

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        await _repository.AddDocumentoAsync(documento);
        await _repository.GuardarAsync();

        var movimiento = new MovimientoInventario
        {
            DocumentoId = documento.Id,
            ProductoId = producto.Id,
            AlmacenId = almacen.Id,
            MotivoId = entrada.Id,
            Tipo = TipoMovimiento.Entrada,
            PresentacionId = recojo.PresentacionId,
            CantidadPresentacion = recojo.CantidadPresentacion,
            Cantidad = recojo.Cantidad,
            Fecha = fecha,
            RecojoVentaId = recojo.Id,
            // No viene de ninguna capa conocida —no es la misma venta la que se
            // esta revirtiendo—, asi que entra como capa nueva. Se valoriza al
            // precio del propio recojo: es lo mas cercano que se puede saber,
            // igual que hace una devolucion cuando no encuentra su origen.
            CostoUnitario = recojo.Cantidad > 0 ? recojo.Importe / recojo.Cantidad : 0m,
            CostoTotal = recojo.Importe,
        };

        await _repository.AddDocumentoMovimientoAsync(movimiento);
        await _repository.GuardarAsync();

        await _repository.AddCapaAsync(new CapaCosto
        {
            ProductoId = producto.Id,
            AlmacenId = almacen.Id,
            MovimientoId = movimiento.Id,
            CantidadInicial = recojo.Cantidad,
            CantidadDisponible = recojo.Cantidad,
            CostoUnitario = movimiento.CostoUnitario,
            Origen = OrigenCapa.Devolucion,
            Fecha = fecha,
        });
        await _repository.GuardarAsync();

        await transaccion.CommitAsync();

        var creado = await GetDocumentoAsync(documento.Id);
        await _notificador.AvisarAsync("stock", "cambio", new { almacenId = almacen.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { almacenId = almacen.Id });
        return creado;
    }

    /// <summary>
    /// Devuelve la mercadería a las capas de las que salió esa venta.
    ///
    /// Se reparte proporcionalmente entre los consumos de aquella salida: si
    /// la venta se llevó 6 de una capa y 4 de otra, devolver 5 repone 3 y 2.
    /// Si ya no se encuentra el movimiento original — datos viejos —, entra
    /// como capa nueva al costo al que se vendió, que es lo más cercano que
    /// se puede saber.
    /// </summary>
    private async Task<decimal> ReponerDeLaVentaAsync(
        MovimientoInventario movimiento, NotaVentaDetalle venta, decimal cantidad, int almacenId)
    {
        var salida = await _repository.GetMovimientoDeVentaAsync(venta.Id);
        var consumos = salida is null
            ? []
            : await _repository.GetConsumosAsync(salida.Id);

        var total = consumos.Sum(c => c.Cantidad);
        if (total <= 0)
        {
            var capa = new CapaCosto
            {
                ProductoId = venta.ProductoId,
                AlmacenId = almacenId,
                MovimientoId = movimiento.Id,
                CantidadInicial = cantidad,
                CantidadDisponible = cantidad,
                CostoUnitario = venta.PrecioUnitario,
                Origen = OrigenCapa.Devolucion,
                Fecha = movimiento.Fecha
            };

            await _repository.AddCapaAsync(capa);
            await _repository.GuardarAsync();
            return cantidad * venta.PrecioUnitario;
        }

        var repuesto = 0m;
        var restante = cantidad;

        foreach (var consumo in consumos)
        {
            if (restante <= 0) break;

            var parte = Math.Min(restante, Math.Round(cantidad * (consumo.Cantidad / total), 4));
            if (parte <= 0) continue;

            var capa = await _repository.GetCapaAsync(consumo.CapaId);
            if (capa is null) continue;

            capa.CantidadDisponible += parte;
            repuesto += parte * capa.CostoUnitario;
            restante -= parte;
        }

        // El redondeo puede dejar una miga: va a la ultima capa tocada.
        if (restante > 0 && consumos.Count > 0)
        {
            var capa = await _repository.GetCapaAsync(consumos[^1].CapaId);
            if (capa is not null)
            {
                capa.CantidadDisponible += restante;
                repuesto += restante * capa.CostoUnitario;
            }
        }

        await _repository.GuardarAsync();
        return repuesto;
    }

    // ------------------------------------------------------------ Auxiliares


    /// <summary>
    /// Descuenta de las capas mas antiguas hasta cubrir la cantidad, dejando
    /// registrado cuanto se tomo de cada una.
    /// </summary>
    private async Task ConsumirAsync(
        MovimientoInventario movimiento, Producto producto, int almacenId, decimal cantidad)
    {
        var capas = await _repository.GetCapasParaConsumirAsync(producto.Id, almacenId);
        var disponible = capas.Sum(c => c.CantidadDisponible);
        var unidad = producto.UnidadBase?.Codigo ?? "unidades";

        // La verificacion va DENTRO de la transaccion y con las capas
        // bloqueadas: comprobar antes dejaria pasar dos salidas simultaneas.
        if (disponible < cantidad)
        {
            throw new BadRequestException(
                $"'{producto.Nombre}': se pidieron {cantidad} {unidad} y quedan {disponible}.");
        }

        var restante = cantidad;
        decimal costoTotal = 0;

        foreach (var capa in capas)
        {
            if (restante <= 0) break;

            var tomado = Math.Min(capa.CantidadDisponible, restante);
            restante -= tomado;
            capa.CantidadDisponible -= tomado;
            costoTotal += tomado * capa.CostoUnitario;

            await _repository.AddConsumoAsync(new ConsumoCapa
            {
                MovimientoId = movimiento.Id,
                CapaId = capa.Id,
                Cantidad = tomado,
                CostoUnitario = capa.CostoUnitario
            });
        }

        movimiento.CostoTotal = Math.Round(costoTotal, 4);
        movimiento.CostoUnitario = cantidad == 0 ? 0 : Math.Round(costoTotal / cantidad, 4);

        await _repository.GuardarAsync();
    }

    private async Task<(decimal Factor, ProductoPresentacion? Presentacion)> ResolverFactorAsync(
        int? presentacionId, Producto producto)
    {
        if (presentacionId is not int id) return (1m, null);

        var presentacion = await _productos.GetPresentacionAsync(id)
            ?? throw new BadRequestException("La presentación indicada no existe");

        if (presentacion.ProductoId != producto.Id)
        {
            throw new BadRequestException(
                $"La presentación '{presentacion.Nombre}' no es de '{producto.Nombre}'.");
        }

        return (presentacion.Factor, presentacion);
    }

    private async Task<Almacen> GetAlmacenOrThrowAsync(int id) =>
        await _repository.GetAlmacenAsync(id)
        ?? throw new NotFoundException($"No existe el almacén {id}");

    private async Task<MotivoMovimiento> GetMotivoOrThrowAsync(int id) =>
        await _repository.GetMotivoAsync(id)
        ?? throw new NotFoundException($"No existe el motivo {id}");

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static AlmacenResponse MapAlmacen(Almacen a, (int Productos, decimal Valorizado) totales) => new()
    {
        Id = a.Id,
        Codigo = a.Codigo,
        Nombre = a.Nombre,
        Direccion = a.Direccion,
        EsPrincipal = a.EsPrincipal,
        Activo = a.Activo,
        Productos = totales.Productos,
        Valorizado = Math.Round(totales.Valorizado, 2)
    };

    private static MotivoResponse MapMotivo(MotivoMovimiento m, int movimientos) => new()
    {
        Id = m.Id,
        Codigo = m.Codigo,
        Nombre = m.Nombre,
        Tipo = m.Tipo,
        DelSistema = m.DelSistema,
        PideCosto = m.PideCosto,
        Activo = m.Activo,
        Movimientos = movimientos
    };

    private static CapaResponse MapCapa(CapaCosto c) => new()
    {
        Id = c.Id,
        CantidadInicial = c.CantidadInicial,
        CantidadDisponible = c.CantidadDisponible,
        CostoUnitario = c.CostoUnitario,
        Valor = Math.Round(c.CantidadDisponible * c.CostoUnitario, 4),
        Origen = c.Origen,
        Lote = c.Lote,
        FechaVencimiento = c.FechaVencimiento,
        Fecha = c.Fecha
    };

    private static DocumentoInventarioResponse MapDocumento(
        DocumentoInventario d, bool conDetalle, string? anuladoPor = null) => new()
    {
        Id = d.Id,
        Numero = d.Numero,
        Tipo = d.Tipo,
        Fecha = d.Fecha,
        AlmacenId = d.AlmacenId,
        Almacen = d.Almacen?.Nombre ?? string.Empty,
        AlmacenDestinoId = d.AlmacenDestinoId,
        AlmacenDestino = d.AlmacenDestino?.Nombre,
        CompraId = d.CompraId,
        Compra = d.Compra?.Numero,
        MotivoId = d.MotivoId,
        Motivo = d.Motivo?.Nombre ?? string.Empty,
        MotivoTipo = d.Motivo?.Tipo ?? string.Empty,
        Estado = d.Estado,
        Observacion = d.Observacion,
        Usuario = d.Usuario?.Nombre,
        AnuladoPor = anuladoPor,
        Total = Math.Round(d.Movimientos.Sum(m => m.CostoTotal), 2),
        Lineas = d.Movimientos.Count,
        Detalle = conDetalle
            ? d.Movimientos.Select(m => new LineaDocumentoResponse
            {
                Id = m.Id,
                ProductoId = m.ProductoId,
                Codigo = m.Producto?.Codigo ?? string.Empty,
                Producto = m.Producto?.Nombre ?? string.Empty,
                UnidadBase = m.Producto?.UnidadBase?.Codigo ?? string.Empty,
                PresentacionId = m.PresentacionId,
                Presentacion = m.Presentacion?.Nombre,
                CantidadPresentacion = m.CantidadPresentacion,
                PrecioPorPresentacion = m.Presentacion?.PrecioPorPresentacion ?? false,
                Cantidad = m.Cantidad,
                CostoUnitario = m.CostoUnitario,
                CostoTotal = m.CostoTotal,
                Tipo = m.Tipo,
                AlmacenId = m.AlmacenId,
                Almacen = m.Almacen?.Nombre ?? string.Empty
            }).ToList()
            : []
    };

    // ------------------------------------------------------------- Prestamos

    public async Task<IEnumerable<PrestamoResponse>> GetPrestamosAsync()
    {
        var prestamos = await _repository.GetPrestamosAsync();
        return prestamos.Select(MapPrestamo);
    }

    public async Task<PrestamoResponse> GetPrestamoAsync(int id) =>
        MapPrestamo(await GetPrestamoOrThrowAsync(id));

    public async Task<PrestamoResponse> CrearPrestamoAsync(
        CrearPrestamoRequest request, int? usuarioId)
    {
        await _prestamoValidator.ValidateAndThrowAsync(request);

        var almacen = await GetAlmacenOrThrowAsync(request.AlmacenId);
        if (!almacen.Activo) throw new BadRequestException("El almacén está desactivado");

        var esDado = request.Tipo == TipoPrestamo.Dado;
        var motivo = await GetMotivoOrThrowAsync(
            esDado ? Motivos.PrestamoDado : Motivos.PrestamoRecibido);
        var fecha = request.Fecha ?? DateTime.UtcNow;

        var documento = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.Prestamo),
            Tipo = TipoDocumentoInventario.Prestamo,
            AlmacenId = almacen.Id,
            MotivoId = motivo.Id,
            Fecha = fecha,
            Estado = EstadoDocumento.Confirmado,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId
        };

        var prestamo = new Prestamo
        {
            Numero = documento.Numero,
            Tipo = request.Tipo,
            Contraparte = request.Contraparte.Trim(),
            AlmacenId = almacen.Id,
            Fecha = fecha,
            Estado = EstadoPrestamo.Pendiente,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId
        };

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        await _repository.AddDocumentoAsync(documento);
        await _repository.AddPrestamoAsync(prestamo);
        await _repository.GuardarAsync();

        foreach (var linea in request.Detalle)
        {
            var producto = await _productos.GetConDetalleAsync(linea.ProductoId)
                ?? throw new BadRequestException($"No existe el producto {linea.ProductoId}");

            if (!producto.ControlaStock)
            {
                throw new BadRequestException($"'{producto.Nombre}' no controla stock.");
            }

            var (factor, presentacion) = await ResolverFactorAsync(linea.PresentacionId, producto);
            var cantidad = linea.Cantidad * factor;

            var movimiento = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = producto.Id,
                AlmacenId = almacen.Id,
                MotivoId = motivo.Id,
                Tipo = motivo.Tipo,
                PresentacionId = presentacion?.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidad,
                Fecha = fecha
            };

            if (esDado)
            {
                // Sale como cualquier salida: hereda el costo de las capas que
                // consume, y queda registrado de cuales para poder devolver.
                await _repository.AddDocumentoMovimientoAsync(movimiento);
                await _repository.GuardarAsync();
                await ConsumirAsync(movimiento, producto, almacen.Id, cantidad);
            }
            else
            {
                // No es compra: no hay factura. Se valoriza al costo de
                // referencia del producto, o al que se indique, solo para que
                // el stock no quede en cero soles mientras esta prestado.
                var costoPresentacion = linea.CostoPresentacion
                    ?? (producto.CostoReferencia ?? 0) * factor;
                var costoTotal = costoPresentacion * linea.Cantidad;

                movimiento.CostoUnitario = cantidad == 0 ? 0 : Math.Round(costoTotal / cantidad, 4);
                movimiento.CostoTotal = Math.Round(costoTotal, 4);

                await _repository.AddDocumentoMovimientoAsync(movimiento);
                await _repository.GuardarAsync();

                await _repository.AddCapaAsync(new CapaCosto
                {
                    ProductoId = producto.Id,
                    AlmacenId = almacen.Id,
                    MovimientoId = movimiento.Id,
                    CantidadInicial = cantidad,
                    CantidadDisponible = cantidad,
                    CostoUnitario = movimiento.CostoUnitario,
                    Origen = OrigenCapa.Prestamo,
                    Fecha = fecha
                });
                await _repository.GuardarAsync();
            }

            await _repository.AddPrestamoDetalleAsync(new PrestamoDetalle
            {
                PrestamoId = prestamo.Id,
                ProductoId = producto.Id,
                PresentacionId = presentacion?.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidad,
                CantidadDevuelta = 0,
                MovimientoId = movimiento.Id
            });
            await _repository.GuardarAsync();
        }

        await transaccion.CommitAsync();

        var creado = await GetPrestamoAsync(prestamo.Id);
        await _notificador.AvisarAsync("prestamos", "creado", creado);
        await _notificador.AvisarAsync("stock", "cambio", new { almacenId = almacen.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { almacenId = almacen.Id });
        return creado;
    }

    public async Task<PrestamoResponse> DevolverPrestamoAsync(
        int prestamoId, DevolverPrestamoRequest request, int? usuarioId)
    {
        await _devolucionValidator.ValidateAndThrowAsync(request);

        var prestamo = await GetPrestamoOrThrowAsync(prestamoId);
        var almacenDevolucion = await GetAlmacenOrThrowAsync(request.AlmacenId);
        if (!almacenDevolucion.Activo)
        {
            throw new BadRequestException("El almacén elegido está desactivado.");
        }

        if (prestamo.Estado == EstadoPrestamo.Devuelto)
        {
            throw new BadRequestException("Este préstamo ya se devolvió por completo.");
        }

        var esDado = prestamo.Tipo == TipoPrestamo.Dado;
        var motivo = await GetMotivoOrThrowAsync(
            esDado ? Motivos.DevolucionPrestamoDado : Motivos.DevolucionPrestamoRecibido);

        var documento = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.DevolucionPrestamo),
            Tipo = TipoDocumentoInventario.DevolucionPrestamo,
            AlmacenId = almacenDevolucion.Id,
            MotivoId = motivo.Id,
            Fecha = DateTime.UtcNow,
            Estado = EstadoDocumento.Confirmado,
            Observacion = $"Devolución de {prestamo.Numero}",
            UsuarioId = usuarioId
        };

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        await _repository.AddDocumentoAsync(documento);
        await _repository.GuardarAsync();

        foreach (var linea in request.Detalle)
        {
            var detalle = prestamo.Detalle.FirstOrDefault(d => d.Id == linea.PrestamoDetalleId)
                ?? throw new BadRequestException(
                    $"La línea {linea.PrestamoDetalleId} no pertenece a este préstamo.");

            var pendiente = detalle.Cantidad - detalle.CantidadDevuelta;
            if (linea.Cantidad > pendiente)
            {
                throw new BadRequestException(
                    $"'{detalle.Producto?.Nombre}': quedan {pendiente} {detalle.Producto?.UnidadBase?.Codigo} "
                    + "por devolver, no se puede devolver más que eso.");
            }

            var movimiento = new MovimientoInventario
            {
                DocumentoId = documento.Id,
                ProductoId = detalle.ProductoId,
                AlmacenId = almacenDevolucion.Id,
                MotivoId = motivo.Id,
                Tipo = motivo.Tipo,
                PresentacionId = detalle.PresentacionId,
                // La presentacion no se recalcula: la devolucion se registra
                // en unidad base, que es lo unico que no cambia de signo.
                CantidadPresentacion = linea.Cantidad,
                Cantidad = linea.Cantidad,
                Fecha = documento.Fecha,
                // De aqui sale, al anular esta devolucion, saber que linea del
                // prestamo corregir y cuanto: igual que CompraDetalleId en una
                // recepcion.
                PrestamoDetalleId = detalle.Id
            };

            await _repository.AddDocumentoMovimientoAsync(movimiento);
            await _repository.GuardarAsync();

            if (esDado)
            {
                /*
                 * Entra como una capa NUEVA en el almacén elegido, valorizada
                 * igual que siempre —al costo de las capas que salieron en su
                 * momento—, pero sin volver a esas capas puntuales: como el
                 * almacén puede ser otro, no hay una capa "de origen" a la que
                 * regresar. Así, anular esta devolución después es el mismo
                 * camino genérico que cualquier entrada (se retira la capa que
                 * esta línea creó).
                 */
                var restante = linea.Cantidad;
                decimal costoTotal = 0;

                foreach (var consumo in await _repository.GetConsumosAsync(detalle.MovimientoId))
                {
                    if (restante <= 0) break;

                    var tomado = Math.Min(consumo.Cantidad, restante);
                    restante -= tomado;
                    costoTotal += tomado * consumo.CostoUnitario;
                }

                movimiento.CostoTotal = Math.Round(costoTotal, 4);
                movimiento.CostoUnitario = linea.Cantidad == 0
                    ? 0
                    : Math.Round(costoTotal / linea.Cantidad, 4);

                await _repository.AddCapaAsync(new CapaCosto
                {
                    ProductoId = detalle.ProductoId,
                    AlmacenId = almacenDevolucion.Id,
                    MovimientoId = movimiento.Id,
                    CantidadInicial = linea.Cantidad,
                    CantidadDisponible = linea.Cantidad,
                    CostoUnitario = movimiento.CostoUnitario,
                    Origen = OrigenCapa.Devolucion,
                    Fecha = documento.Fecha
                });
            }
            else if (almacenDevolucion.Id == prestamo.AlmacenId)
            {
                // Mismo almacén del préstamo: sale de la capa que ESTE préstamo
                // creó al entrar, no del stock en general — no hay que devolver
                // mercadería comprada de más.
                var capas = await _repository.GetCapasDeMovimientoAsync(detalle.MovimientoId);
                var disponible = capas.Sum(c => c.CantidadDisponible);

                if (disponible < linea.Cantidad)
                {
                    throw new BadRequestException(
                        $"'{detalle.Producto?.Nombre}': ya se usó o se vendió parte de este préstamo, "
                        + $"solo quedan {disponible} {detalle.Producto?.UnidadBase?.Codigo} para devolver.");
                }

                var restante = linea.Cantidad;
                decimal costoTotal = 0;

                foreach (var capa in capas)
                {
                    if (restante <= 0) break;

                    var tomado = Math.Min(capa.CantidadDisponible, restante);
                    capa.CantidadDisponible -= tomado;
                    restante -= tomado;
                    costoTotal += tomado * capa.CostoUnitario;

                    await _repository.AddConsumoAsync(new ConsumoCapa
                    {
                        MovimientoId = movimiento.Id,
                        CapaId = capa.Id,
                        Cantidad = tomado,
                        CostoUnitario = capa.CostoUnitario
                    });
                }

                movimiento.CostoTotal = Math.Round(costoTotal, 4);
                movimiento.CostoUnitario = linea.Cantidad == 0
                    ? 0
                    : Math.Round(costoTotal / linea.Cantidad, 4);
            }
            else
            {
                // Otro almacén: ya no es necesariamente lo mismo que entró con
                // el préstamo —pudo haberse movido internamente—, así que sale
                // del stock general de ese almacén, como cualquier salida.
                await ConsumirAsync(movimiento, detalle.Producto!, almacenDevolucion.Id, linea.Cantidad);
            }

            detalle.CantidadDevuelta += linea.Cantidad;
            await _repository.GuardarAsync();
        }

        prestamo.Estado = prestamo.Detalle.All(d => d.CantidadDevuelta >= d.Cantidad)
            ? EstadoPrestamo.Devuelto
            : EstadoPrestamo.Pendiente;
        await _repository.UpdatePrestamoAsync(prestamo);

        await transaccion.CommitAsync();

        var response = await GetPrestamoAsync(prestamo.Id);
        await _notificador.AvisarAsync("prestamos", "devolucion", response);
        await _notificador.AvisarAsync("stock", "cambio", new { prestamoId = prestamo.Id });
        await _notificador.AvisarAsync("kardex", "cambio", new { prestamoId = prestamo.Id });
        return response;
    }

    public async Task<PrestamoResponse> AnularPrestamoAsync(int prestamoId, int? usuarioId)
    {
        var prestamo = await GetPrestamoOrThrowAsync(prestamoId);

        if (prestamo.Estado == EstadoPrestamo.Anulado)
        {
            throw new BadRequestException("Este préstamo ya está anulado.");
        }

        if (prestamo.Detalle.Any(d => d.CantidadDevuelta > 0))
        {
            throw new BadRequestException(
                "No se puede anular: ya hay una devolución registrada sobre este préstamo. "
                + "Anula primero esa devolución.");
        }

        var documentoId = prestamo.Detalle.First().Movimiento!.DocumentoId;
        await AnularAsync(documentoId, usuarioId);

        prestamo.Estado = EstadoPrestamo.Anulado;
        await _repository.UpdatePrestamoAsync(prestamo);

        var response = await GetPrestamoAsync(prestamo.Id);
        await _notificador.AvisarAsync("prestamos", "anulado", response);
        return response;
    }

    private async Task<Prestamo> GetPrestamoOrThrowAsync(int id) =>
        await _repository.GetPrestamoAsync(id)
        ?? throw new NotFoundException($"No existe el préstamo {id}");

    private static PrestamoResponse MapPrestamo(Prestamo p) => new()
    {
        Id = p.Id,
        Numero = p.Numero,
        Tipo = p.Tipo,
        Contraparte = p.Contraparte,
        AlmacenId = p.AlmacenId,
        Almacen = p.Almacen?.Nombre ?? string.Empty,
        Fecha = p.Fecha,
        Estado = p.Estado,
        Observacion = p.Observacion,
        Usuario = p.Usuario?.Nombre,
        Total = Math.Round(p.Detalle.Sum(d => d.Movimiento?.CostoTotal ?? 0), 2),
        Detalle = p.Detalle.Select(d => new PrestamoDetalleResponse
        {
            Id = d.Id,
            ProductoId = d.ProductoId,
            Codigo = d.Producto?.Codigo ?? string.Empty,
            Producto = d.Producto?.Nombre ?? string.Empty,
            UnidadBase = d.Producto?.UnidadBase?.Codigo ?? string.Empty,
            PresentacionId = d.PresentacionId,
            Presentacion = d.Presentacion?.Nombre,
            CantidadPresentacion = d.CantidadPresentacion,
            PrecioPorPresentacion = d.Presentacion?.PrecioPorPresentacion ?? false,
            Cantidad = d.Cantidad,
            CantidadDevuelta = d.CantidadDevuelta,
            CantidadPendiente = d.Cantidad - d.CantidadDevuelta,
            CostoUnitario = d.Movimiento?.CostoUnitario ?? 0,
            CostoTotal = d.Movimiento?.CostoTotal ?? 0
        }).ToList(),
        // Cada devolucion es un documento propio: se agrupan las lineas de
        // todas las PrestamoDetalle por el documento que las registro, para
        // que cada devolucion salga como un solo renglon con sus lineas
        // adentro, no una fila suelta por producto.
        Devoluciones = p.Detalle
            .SelectMany(d => d.MovimientosDevolucion.Select(m => (Detalle: d, Movimiento: m)))
            .GroupBy(x => x.Movimiento.DocumentoId)
            .Select(g => new PrestamoDevolucionResponse
            {
                Id = g.Key,
                Numero = g.First().Movimiento.Documento?.Numero ?? string.Empty,
                Fecha = g.First().Movimiento.Documento?.Fecha ?? default,
                Estado = g.First().Movimiento.Documento?.Estado ?? string.Empty,
                AlmacenId = g.First().Movimiento.Documento?.AlmacenId ?? 0,
                Almacen = g.First().Movimiento.Documento?.Almacen?.Nombre ?? string.Empty,
                Usuario = g.First().Movimiento.Documento?.Usuario?.Nombre,
                Detalle = g.Select(x => new LineaDevolucionPrestamoResponse
                {
                    PrestamoDetalleId = x.Detalle.Id,
                    Producto = x.Detalle.Producto?.Nombre ?? string.Empty,
                    Presentacion = x.Movimiento.Presentacion?.Nombre,
                    UnidadBase = x.Detalle.Producto?.UnidadBase?.Codigo ?? string.Empty,
                    CantidadPresentacion = x.Movimiento.CantidadPresentacion,
                    Cantidad = x.Movimiento.Cantidad,
                }).ToList(),
            })
            .OrderByDescending(dv => dv.Fecha)
            .ThenByDescending(dv => dv.Id)
            .ToList()
    };
}
