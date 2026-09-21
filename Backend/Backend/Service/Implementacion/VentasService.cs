using System.Text.Json;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Lo que pide un cliente, y lo que de eso se le vendió de verdad.
///
/// Reglas:
///
///   - Un pedido Pendiente es solo una intención: se edita o se anula libre.
///   - Confirmarlo es despacharlo: ese mismo paso crea la NotaVenta y ahí
///     recién sale el stock — el pedido nunca lo toca.
///   - Una nota de venta puede nacer de confirmar un pedido, o registrarse
///     directa. En los dos casos el stock sale completo al momento: no existe
///     una "nota de venta a medio despachar" como sí existe una compra a
///     medio recibir.
///   - Si el descuento de stock falla al crear la nota (no alcanza lo que
///     hay), la nota queda igual guardada pero Anulada: así el número no se
///     pierde y el error real queda en el historial, en vez de un registro
///     fantasma sin explicación.
/// </summary>
public class VentasService : IVentasService
{
    private readonly IVentasRepository _repository;
    private readonly IProductoRepository _productos;
    private readonly IInventarioService _inventario;
    private readonly IAuditoriaService _auditoria;
    private readonly IValidator<CrearPedidoRequest> _pedidoValidator;
    private readonly IValidator<ConfirmarPedidoRequest> _confirmarValidator;
    private readonly IValidator<NoEntregadoRequest> _noEntregadoValidator;
    private readonly INovedadService _novedades;
    private readonly IValidator<CrearNotaVentaRequest> _notaVentaValidator;
    private readonly IValidator<PagoVentaRequest> _pagoValidator;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;
    private readonly INotificador _notificador;
    private readonly IDevolucionService _devoluciones;

    public VentasService(
        IVentasRepository repository,
        IProductoRepository productos,
        IInventarioService inventario,
        IAuditoriaService auditoria,
        IValidator<CrearPedidoRequest> pedidoValidator,
        IValidator<ConfirmarPedidoRequest> confirmarValidator,
        IValidator<NoEntregadoRequest> noEntregadoValidator,
        INovedadService novedades,
        IValidator<CrearNotaVentaRequest> notaVentaValidator,
        IValidator<PagoVentaRequest> pagoValidator,
        IPermisoService permisos,
        IUsuarioActual usuarioActual,
        INotificador notificador,
        IDevolucionService devoluciones)
    {
        _repository = repository;
        _productos = productos;
        _inventario = inventario;
        _auditoria = auditoria;
        _pedidoValidator = pedidoValidator;
        _confirmarValidator = confirmarValidator;
        _noEntregadoValidator = noEntregadoValidator;
        _novedades = novedades;
        _notaVentaValidator = notaVentaValidator;
        _pagoValidator = pagoValidator;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
        _notificador = notificador;
        _devoluciones = devoluciones;
    }

    /*
     * Hasta donde llega lo que ve quien esta pidiendo.
     *
     * Se resuelve en cada llamada y no se guarda: es una consulta corta y
     * cachearla por instancia haria que un cambio de alcance no surtiera
     * efecto hasta la siguiente peticion, que es justo el problema que se
     * evito con los permisos.
     */
    private async Task<AlcanceFiltro?> AlcancePedidosAsync() => await AlcanceAsync("fact.pedidos");

    private async Task<AlcanceFiltro?> AlcanceVentasAsync() => await AlcanceAsync("fact.notaventa");

    /*
     * Un cliente que no es de mi ruta no se puede vender.
     *
     * Ocultarlo en el selector no basta: bastaria con mandar el id a mano. Solo aplica al alcance
     * "mis clientes"; "propios" limita lo que se VE y "todos" no limita nada.
     */
    private async Task ExigirClienteDeMiRutaAsync(int clienteId, string submodulo)
    {
        var alcance = await AlcanceAsync(submodulo);
        if (alcance is null || alcance.SinRestriccion || alcance.SoloPropios) return;

        var rutaDelCliente = await _repository.RutaDeClienteAsync(clienteId);
        if (alcance.RutaId is null || rutaDelCliente != alcance.RutaId)
        {
            throw new ForbiddenException("Solo puedes vender a los clientes de tu ruta");
        }
    }

    private async Task<AlcanceFiltro?> AlcanceAsync(string submodulo)
    {
        // Sin usuario en el token no hay a quien acotar. Ocurre en las llamadas
        // internas del propio sistema, que no pasan por un controlador.
        if (_usuarioActual.Id is not int id) return null;

        return await _permisos.AlcanceFiltroAsync(id, submodulo);
    }

    // --------------------------------------------------------------- Pedidos

    public async Task<IEnumerable<PedidoResponse>> GetPedidosAsync(string? estado = null)
    {
        var pedidos = await _repository.GetPedidosAsync(estado, await AlcancePedidosAsync());
        return await ConNoEntregadosAsync(pedidos.Select(MapPedido).ToList());
    }

    public async Task<PedidoResponse> GetPedidoAsync(int id) =>
        (await ConNoEntregadosAsync([MapPedido(await GetPedidoOrThrowAsync(id))]))[0];

    /// <summary>
    /// Anota en cada pedido por qué no se entregó, si se marcó así. Una sola
    /// consulta para toda la lista; un pedido que ya es venta no lo lleva.
    /// </summary>
    private async Task<List<PedidoResponse>> ConNoEntregadosAsync(List<PedidoResponse> pedidos)
    {
        var marcas = await _novedades.GetNoEntregadosAsync(pedidos.Select(p => p.Id));

        foreach (var pedido in pedidos)
        {
            if (pedido.NotaVentaId is null && marcas.TryGetValue(pedido.Id, out var marca))
            {
                pedido.NoEntregadoMotivo = marca.Motivo;
                pedido.NoEntregadoObservacion = marca.Observacion;
            }
        }

        return pedidos;
    }

    public async Task<PaginaResponse<PedidoResponse>> ListarPedidosAsync(ConsultaTablaRequest consulta)
    {
        var (items, total) = await _repository.ListarPedidosAsync(consulta, await AlcancePedidosAsync());

        return new PaginaResponse<PedidoResponse>
        {
            Items = await ConNoEntregadosAsync(items.Select(MapPedido).ToList()),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public async Task<ResumenPedidosResponse> GetResumenPedidosAsync() =>
        await _repository.ResumenPedidosAsync(await AlcancePedidosAsync());

    public async Task<PaginaResponse<NotaVentaResponse>> ListarNotasVentaAsync(ConsultaTablaRequest consulta)
    {
        var (items, total) = await _repository.ListarNotasVentaAsync(consulta, await AlcanceVentasAsync());

        return new PaginaResponse<NotaVentaResponse>
        {
            Items = items.Select(MapNotaVenta).ToList(),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public async Task<ResumenNotasVentaResponse> GetResumenNotasVentaAsync() =>
        await _repository.ResumenNotasVentaAsync(await AlcanceVentasAsync());

    public async Task<PedidoResponse> CrearPedidoAsync(CrearPedidoRequest request, int? usuarioId)
    {
        await _pedidoValidator.ValidateAndThrowAsync(request);
        await ExigirClienteDeMiRutaAsync(request.ClienteId, "fact.pedidos");

        if (request.ReservaStock)
        {
            await ValidarAlmacenReservaAsync(request.AlmacenId!.Value);
        }

        var pedido = new Pedido
        {
            Numero = await _repository.SiguienteNumeroPedidoAsync(),
            ClienteId = request.ClienteId,
            ListaPrecioId = request.ListaPrecioId,
            Fecha = request.Fecha ?? DateTime.UtcNow,
            Estado = EstadoPedido.Pendiente,
            CondicionPago = Limpiar(request.CondicionPago) ?? FormaPagoVenta.Contado,
            Observacion = Limpiar(request.Observacion),
            ReservaStock = request.ReservaStock,
            AlmacenId = request.ReservaStock ? request.AlmacenId : null,
            UsuarioId = usuarioId
        };

        pedido.Detalle = await ResolverLineasAsync(request.Detalle);

        await _repository.AddPedidoAsync(pedido);

        var creado = await GetPedidoAsync(pedido.Id);
        await _notificador.AvisarAsync("pedidos", "creado", creado);
        return creado;
    }

    public async Task<PedidoResponse> ActualizarPedidoAsync(int id, CrearPedidoRequest request)
    {
        await _pedidoValidator.ValidateAndThrowAsync(request);

        var pedido = await GetPedidoOrThrowAsync(id);

        if (pedido.Estado != EstadoPedido.Pendiente)
        {
            throw new BadRequestException(
                "Solo se puede editar un pedido Pendiente. Si ya se despachó, anúlalo y crea uno nuevo.");
        }

        if (request.ReservaStock)
        {
            await ValidarAlmacenReservaAsync(request.AlmacenId!.Value);
        }

        // Solo si CAMBIA de cliente: corregir un pedido viejo no debe fallar porque la ruta ya no sea la mia.
        if (pedido.ClienteId != request.ClienteId)
        {
            await ExigirClienteDeMiRutaAsync(request.ClienteId, "fact.pedidos");
        }
        pedido.ClienteId = request.ClienteId;
        pedido.ListaPrecioId = request.ListaPrecioId;
        pedido.Fecha = request.Fecha ?? pedido.Fecha;
        pedido.CondicionPago = Limpiar(request.CondicionPago) ?? FormaPagoVenta.Contado;
        pedido.Observacion = Limpiar(request.Observacion);
        pedido.ReservaStock = request.ReservaStock;
        pedido.AlmacenId = request.ReservaStock ? request.AlmacenId : null;

        await _repository.UpdatePedidoAsync(pedido);
        await _repository.ReemplazarDetallePedidoAsync(id, await ResolverLineasAsync(request.Detalle, id));

        var actualizado = await GetPedidoAsync(id);
        await _notificador.AvisarAsync("pedidos", "actualizado", actualizado);
        return actualizado;
    }

    public async Task<NotaVentaResponse> ConfirmarPedidoAsync(
        int id, ConfirmarPedidoRequest request, int? usuarioId)
    {
        await _confirmarValidator.ValidateAndThrowAsync(request);

        var pedido = await GetPedidoOrThrowAsync(id);

        if (pedido.Estado == EstadoPedido.Anulado)
        {
            throw new BadRequestException("Este pedido está anulado.");
        }

        /*
         * La regla es la venta viva, no el estado.
         *
         * Se mira si ya existe una nota de venta sin anular en vez de "esta
         * confirmado": asi, cuando se anula la venta, el pedido vuelve a poder
         * convertirse sin que haya que acordarse de tocar ningun estado a
         * mano. El estado pasa a ser el reflejo de esto, no su origen.
         */
        if (VentaVigente(pedido) is NotaVenta vigente)
        {
            throw new BadRequestException(
                $"Este pedido ya se convirtió en la venta {vigente.Numero}. Anúlala si necesitas rehacerla.");
        }

        // La venta que nace al confirmarlo lleva lo que el cliente pagó al recibir
        // (ver más abajo): todo, una parte o nada.
        /*
         * De donde sale: el de la reserva manda.
         *
         * Si el pedido aparto stock, la mercaderia ya esta comprometida en ese
         * almacen; descontar de otro dejaria la reserva viva en el primero y
         * el stock del segundo en negativo. Sin reserva, se pide al confirmar.
         */
        var almacenId = pedido.ReservaStock && pedido.AlmacenId is int reservado
            ? reservado
            : request.AlmacenId
              ?? throw new BadRequestException("Elige el almacén del que sale la mercadería.");

        var (lineasVenta, cambios) = await ResolverEntregaAsync(pedido, request);
        var motivos = await _novedades.ExigirMotivosAsync(cambios.Select(c => c.MotivoId));

        /*
         * La forma de pago sale de lo que se cobró, no de lo que se acordó.
         *
         * El pedido dice contado o crédito, pero solo como referencia: al
         * repartir se cobra todo, una parte o nada, sin importar lo acordado.
         * Si lo cobrado cubre el total, la venta es al contado; si no, queda a
         * crédito con ese adelanto (que puede ser cero) y el resto es deuda.
         * Un cobro de más lo rechaza la propia creación de la venta.
         */
        var pagos = request.Pagos ?? [];
        var totalVenta = Math.Round(lineasVenta.Sum(l => l.CantidadPresentacion * l.PrecioPresentacion), 2);
        var cobrado = Math.Round(pagos.Sum(p => p.Monto), 2);
        var forma = cobrado > 0 && cobrado >= totalVenta ? FormaPagoVenta.Contado : FormaPagoVenta.Credito;

        var notaVenta = await CrearNotaVentaInternaAsync(
            clienteId: pedido.ClienteId,
            almacenId: almacenId,
            pedidoId: pedido.Id,
            formaPago: forma,
            pagos: pagos,
            observacion: pedido.Observacion,
            lineas: lineasVenta,
            usuarioId: usuarioId);

        pedido.Estado = EstadoPedido.Confirmado;
        await _repository.UpdatePedidoAsync(pedido);

        // Solo con la venta ya hecha: si el stock no alcanzó y la venta
        // falló, no queda ninguna novedad huérfana.
        await _novedades.RegistrarLineasAsync(pedido, notaVenta.Id, cambios, motivos, usuarioId);

        // Si antes se marcó como no entregado y al final sí se entregó, esa
        // marca ya no aplica.
        await _novedades.AnularNoEntregadoAsync(pedido.Id);

        await _notificador.AvisarAsync("pedidos", "confirmado", MapPedido(pedido));
        return notaVenta;
    }

    /// <summary>
    /// Qué se le entrega de verdad al cliente: las líneas de la venta y, aparte,
    /// las novedades de lo que quedó corto.
    ///
    /// Por defecto sale todo lo pedido. Una línea entregada en menos exige su
    /// motivo, y una entregada en cero deja de ir en la venta — pero no todas a
    /// la vez: un pedido que no se entregó nada no es una venta, es un "no
    /// entregado".
    /// </summary>
    private async Task<(List<PedidoDetalle> Lineas, List<CambioEntrega> Cambios)> ResolverEntregaAsync(
        Pedido pedido, ConfirmarPedidoRequest request)
    {
        // Una línea anulada al editar el pedido no se despacha: quedó fuera
        // del total y no debe salir del almacén.
        var vivas = pedido.Detalle.Where(d => !d.Anulado).ToList();
        var indicadas = new Dictionary<int, LineaEntregaRequest>();

        foreach (var l in request.Lineas ?? [])
        {
            if (!indicadas.TryAdd(l.PedidoDetalleId, l))
                throw new BadRequestException("Una línea del pedido viene repetida.");

            if (vivas.All(d => d.Id != l.PedidoDetalleId))
                throw new BadRequestException("Una de las líneas ya no pertenece al pedido. Vuelve a abrirlo.");
        }

        var lineas = new List<PedidoDetalle>();
        var cambios = new List<CambioEntrega>();

        foreach (var d in vivas)
        {
            var nombre = d.Producto?.Nombre ?? "un producto";
            var entregada = d.Cantidad;

            if (indicadas.TryGetValue(d.Id, out var indicada))
            {
                entregada = Math.Round(indicada.Cantidad, 4);

                if (entregada > d.Cantidad)
                    throw new BadRequestException(
                        $"No se puede entregar más de lo pedido en {nombre}. Si el cliente quiere más, es otro pedido.");

                if (entregada < d.Cantidad)
                {
                    if (indicada.MotivoId is not int motivoId)
                        throw new BadRequestException($"Elige el motivo por el que {nombre} se entrega en menos.");

                    // Cuánto vale lo que quedó sin entregar, al precio del pedido.
                    var faltante = (d.Cantidad - entregada) / FactorDe(d);
                    var importe = Math.Round(faltante * d.PrecioPresentacion, 2);

                    cambios.Add(new CambioEntrega(d, entregada, importe, motivoId, indicada.Observacion));
                }
            }

            if (entregada <= 0) continue;

            // Completa, tal cual se pidió: un redondeo aquí movería el total
            // de un pedido que se entrega entero.
            if (entregada == d.Cantidad)
            {
                lineas.Add(CopiarLinea(d, d.PresentacionId, d.CantidadPresentacion, d.Cantidad, d.PrecioPresentacion));
                continue;
            }

            lineas.AddRange(await LineasEntregadasAsync(d, entregada));
        }

        if (lineas.Count == 0)
        {
            throw new BadRequestException(
                "No queda nada por entregar en este pedido. Si el cliente no recibió nada, márcalo como \"No entregado\".");
        }

        return (lineas, cambios);
    }

    /// <summary>Cuántas unidades base trae una presentación de esa línea.</summary>
    private static decimal FactorDe(PedidoDetalle d) =>
        d.Presentacion is { Factor: > 0 }
            ? d.Presentacion.Factor
            : d.CantidadPresentacion > 0 ? d.Cantidad / d.CantidadPresentacion : 1m;

    private static PedidoDetalle CopiarLinea(
        PedidoDetalle d, int? presentacionId, decimal cantidadPresentacion, decimal cantidad, decimal precioPresentacion) =>
        new()
        {
            ProductoId = d.ProductoId,
            PresentacionId = presentacionId,
            CantidadPresentacion = cantidadPresentacion,
            Cantidad = cantidad,
            PrecioPresentacion = precioPresentacion,
            PrecioUnitario = d.PrecioUnitario
        };

    /// <summary>
    /// La línea de una entrega parcial, partida en cajas enteras y unidades
    /// sueltas: 113 unidades de una caja de 12 son 9 cajas y 5 sueltas.
    ///
    /// Como una sola línea saldría "9.4167 cajas", y multiplicado por el precio
    /// de la caja ya no da el total justo (S/ 11,300.04 en vez de 11,300.00). Así
    /// cada línea es un número exacto de su presentación: las cajas al precio
    /// de la caja, las sueltas al precio por unidad.
    /// </summary>
    private async Task<List<PedidoDetalle>> LineasEntregadasAsync(PedidoDetalle d, decimal entregada)
    {
        var factor = FactorDe(d);

        if (d.PresentacionId is not null && factor > 1)
        {
            var cajas = Math.Floor(entregada / factor + 0.000001m);
            var sueltas = Math.Round(entregada - cajas * factor, 4);

            // La presentación de una unidad, para asentar las sueltas. Si el
            // producto no tiene, queda una sola línea fraccionada.
            var producto = await _productos.GetConDetalleAsync(d.ProductoId);
            var unidad = producto?.Presentaciones.FirstOrDefault(p => p.Factor == 1 && p.Activo);

            if (unidad is not null)
            {
                var partes = new List<PedidoDetalle>();

                if (cajas > 0)
                {
                    partes.Add(CopiarLinea(d, d.PresentacionId, cajas, cajas * factor, d.PrecioPresentacion));
                }

                if (sueltas > 0)
                {
                    partes.Add(CopiarLinea(d, unidad.Id, sueltas, sueltas, d.PrecioUnitario));
                }

                return partes;
            }
        }

        return [CopiarLinea(d, d.PresentacionId, Math.Round(entregada / factor, 4), entregada, d.PrecioPresentacion)];
    }

    public async Task<PedidoResponse> MarcarNoEntregadoAsync(int id, NoEntregadoRequest request, int? usuarioId)
    {
        await _noEntregadoValidator.ValidateAndThrowAsync(request);

        var pedido = await GetPedidoOrThrowAsync(id);

        if (pedido.Estado == EstadoPedido.Anulado)
            throw new BadRequestException("Este pedido está anulado.");

        if (VentaVigente(pedido) is NotaVenta vigente)
        {
            throw new BadRequestException(
                $"Este pedido ya se convirtió en la venta {vigente.Numero}: no se puede marcar como no entregado.");
        }

        var motivos = await _novedades.ExigirMotivosAsync([request.MotivoId]);
        await _novedades.RegistrarNoEntregadoAsync(pedido, motivos[request.MotivoId], request.Observacion, usuarioId);

        var respuesta = (await ConNoEntregadosAsync([MapPedido(pedido)]))[0];
        await _notificador.AvisarAsync("pedidos", "noEntregado", respuesta);
        return respuesta;
    }

    public async Task<PedidoResponse> DeshacerNoEntregadoAsync(int id)
    {
        var pedido = await GetPedidoOrThrowAsync(id);
        await _novedades.DeshacerNoEntregadoAsync(id);

        var respuesta = (await ConNoEntregadosAsync([MapPedido(pedido)]))[0];
        await _notificador.AvisarAsync("pedidos", "noEntregadoQuitado", respuesta);
        return respuesta;
    }

    /// <summary>
    /// Qué se le cambió a los productos de este pedido después de crearlo:
    /// cantidades corregidas y líneas anuladas, nada más. El alta no entra —
    /// lo que se pidió de entrada ya se ve en el propio detalle.
    /// </summary>
    public async Task<IEnumerable<AuditoriaResponse>> GetHistorialPedidoAsync(int id)
    {
        var pedido = await GetPedidoOrThrowAsync(id);
        var registros = await _auditoria.GetHistorialDocumentoAsync(
            "Pedido", id, "PedidoDetalle", pedido.Detalle.Select(d => d.Id));

        return SoloEdicionesDeLinea(
            registros,
            "PedidoDetalle",
            pedido.Detalle.ToDictionary(
                d => d.Id,
                d => (Producto: d.Producto?.Nombre ?? string.Empty, Cantidad: d.CantidadPresentacion)));
    }

    /// <summary>Lo mismo para una nota de venta: solo las correcciones a sus productos.</summary>
    public async Task<IEnumerable<AuditoriaResponse>> GetHistorialNotaVentaAsync(int id)
    {
        var notaVenta = await GetNotaVentaOrThrowAsync(id);
        var registros = await _auditoria.GetHistorialDocumentoAsync(
            "NotaVenta", id, "NotaVentaDetalle", notaVenta.Detalle.Select(d => d.Id));

        return SoloEdicionesDeLinea(
            registros,
            "NotaVentaDetalle",
            notaVenta.Detalle.ToDictionary(
                d => d.Id,
                d => (Producto: d.Producto?.Nombre ?? string.Empty, Cantidad: d.CantidadPresentacion)));
    }

    /// <summary>
    /// Deja pasar solo las ediciones de las líneas de producto y les pone el
    /// nombre del producto. Se descartan las altas y los cambios de cabecera:
    /// el historial responde "qué le cambiaron a los productos", no "qué pasó
    /// con el documento".
    /// </summary>
    private static List<AuditoriaResponse> SoloEdicionesDeLinea(
        IEnumerable<AuditoriaResponse> registros,
        string entidadLinea,
        Dictionary<int, (string Producto, decimal Cantidad)> lineas) =>
        registros
            .Where(r => r.Entidad == entidadLinea && r.Accion == AccionAuditoria.Actualizado)
            .Select(r =>
            {
                if (!int.TryParse(r.EntidadId, out var lineaId) || !lineas.TryGetValue(lineaId, out var linea))
                {
                    return r;
                }

                r.Descripcion = linea.Producto;

                // Al anular una línea solo cambia el flag: la bitácora no
                // registra cantidad porque la cantidad no se tocó. Pero para
                // quien lee el historial la línea SÍ pasó de N a 0 — es lo que
                // deja de pesarse. Se completa aquí para que la columna de
                // cantidades no quede vacía justo en el caso que más importa.
                if (r.ValoresNuevos?.TryGetValue("Anulado", out var anulado) == true && EsVerdadero(anulado))
                {
                    r.ValoresAnteriores ??= [];
                    r.ValoresNuevos["CantidadPresentacion"] = 0m;
                    r.ValoresAnteriores["CantidadPresentacion"] = linea.Cantidad;
                }

                return r;
            })
            .OrderByDescending(r => r.Fecha)
            .ThenByDescending(r => r.Id)
            .ToList();

    /// <summary>
    /// Un booleano de la bitácora. Los valores vienen de deserializar JSON a
    /// `object`, así que un `true` llega como <see cref="JsonElement"/> y no
    /// como `bool`: compararlo directo contra `true` siempre daría falso.
    /// </summary>
    private static bool EsVerdadero(object? valor) => valor switch
    {
        bool b => b,
        JsonElement { ValueKind: JsonValueKind.True } => true,
        string s => bool.TryParse(s, out var b) && b,
        _ => false
    };

    public async Task AnularPedidoAsync(int id)
    {
        var pedido = await GetPedidoOrThrowAsync(id);

        if (pedido.Estado != EstadoPedido.Pendiente)
        {
            throw new BadRequestException(
                "Solo se puede anular un pedido Pendiente. Uno confirmado ya generó su venta: anula esa.");
        }

        pedido.Estado = EstadoPedido.Anulado;
        await _repository.UpdatePedidoAsync(pedido);

        // Un "no entregado" pendiente de un pedido que ya no existe no se
        // puede seguir esperando de vuelta en el camión.
        await _novedades.AnularDePedidoAsync(id);

        await _notificador.AvisarAsync("pedidos", "anulado", MapPedido(pedido));
    }

    // ----------------------------------------------------------- Notas de venta

    public async Task<IEnumerable<NotaVentaResponse>> GetNotasVentaAsync(string? estado = null)
    {
        var notas = await _repository.GetNotasVentaAsync(estado, await AlcanceVentasAsync());
        return notas.Select(MapNotaVenta);
    }

    public async Task<NotaVentaResponse> GetNotaVentaAsync(int id) =>
        MapNotaVenta(await GetNotaVentaOrThrowAsync(id));

    public async Task<NotaVentaResponse> CrearNotaVentaAsync(CrearNotaVentaRequest request, int? usuarioId)
    {
        await _notaVentaValidator.ValidateAndThrowAsync(request);
        await ExigirClienteDeMiRutaAsync(request.ClienteId, "fact.notaventa");

        return await CrearNotaVentaInternaAsync(
            clienteId: request.ClienteId,
            almacenId: request.AlmacenId,
            pedidoId: null,
            formaPago: request.FormaPago,
            pagos: request.Pagos,
            observacion: request.Observacion,
            lineas: await ResolverLineasAsync(request.Detalle),
            usuarioId: usuarioId);
    }

    /// <summary>
    /// Corrige una venta ya confirmada. El stock no se ajusta a mano: se
    /// devuelve el que había salido con las cantidades anteriores (igual que
    /// una anulación) y se vuelve a descontar con las cantidades corregidas,
    /// así el kardex queda exacto sin importar si subió, bajó o se quitó una
    /// línea entera.
    /// </summary>
    public async Task<NotaVentaResponse> ActualizarNotaVentaAsync(int id, CrearNotaVentaRequest request, int? usuarioId)
    {
        await _notaVentaValidator.ValidateAndThrowAsync(request);

        var notaVenta = await GetNotaVentaOrThrowAsync(id);

        if (notaVenta.Estado == EstadoNotaVenta.Anulada)
        {
            throw new BadRequestException("Esta nota de venta está anulada: no se puede editar.");
        }

        var almacen = await _inventario.GetAlmacenAsync(request.AlmacenId);
        if (!almacen.Activo)
        {
            throw new BadRequestException("El almacén está desactivado");
        }

        /*
         * Quitar mercaderia de una venta ya hecha es una devolucion.
         *
         * El cliente se llevo lo que dice el documento: si ahora trae una caja
         * de vuelta, eso no se corrige borrandolo del papel —quedaria como si
         * nunca hubiera salido— sino registrando lo que devolvio. Y como una
         * devolucion necesita aprobacion, la venta NO baja aqui: se guarda la
         * solicitud y todo se aplica al aprobarla.
         */
        var devueltas = RecortesAsync(notaVenta, request.Detalle);

        var lineas = await ResolverLineasAsync(request.Detalle);
        var nuevoTotal = Math.Round(lineas.Where(l => !l.Anulado).Sum(l => l.CantidadPresentacion * l.PrecioPresentacion), 2);
        var pagado = Math.Round(notaVenta.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto), 2);

        if (nuevoTotal < pagado - 0.001m)
        {
            throw new BadRequestException(
                $"El nuevo total (S/ {nuevoTotal}) queda por debajo de lo ya cobrado (S/ {pagado}). "
                + "Anula o corrige el pago primero.");
        }

        /*
         * La devolucion se registra ANTES de tocar nada.
         *
         * Aqui es donde se comprueba que no se devuelva mas de lo que queda de
         * cada linea. Si eso falla mas abajo, la venta ya se habria quedado sin
         * su salida de stock anulada a medias: de este lado, un tope pasado
         * corta la edicion entera sin haber movido un solo registro.
         */
        if (devueltas.Count > 0)
        {
            await _devoluciones.CrearAsync(
                new DevolucionRequest
                {
                    NotaVentaId = id,
                    Motivo = "Quitado al editar la venta",
                    Detalle = devueltas,
                },
                usuarioId);
        }

        // Se devuelve el stock que había salido con las cantidades anteriores:
        // abajo se vuelve a descontar ya con las cantidades corregidas.
        if (notaVenta.DocumentoInventarioId is int documentoAnteriorId)
        {
            await _inventario.AnularAsync(documentoAnteriorId, usuarioId);
        }

        if (notaVenta.ClienteId != request.ClienteId)
        {
            await ExigirClienteDeMiRutaAsync(request.ClienteId, "fact.notaventa");
        }
        notaVenta.ClienteId = request.ClienteId;
        notaVenta.AlmacenId = request.AlmacenId;
        notaVenta.Observacion = Limpiar(request.Observacion);
        await _repository.UpdateNotaVentaAsync(notaVenta);

        await _repository.ReemplazarDetalleNotaVentaAsync(id, lineas.Select(l => new NotaVentaDetalle
        {
            Id = l.Id,
            ProductoId = l.ProductoId,
            PresentacionId = l.PresentacionId,
            CantidadPresentacion = l.CantidadPresentacion,
            Cantidad = l.Cantidad,
            PrecioPresentacion = l.PrecioPresentacion,
            PrecioUnitario = l.PrecioUnitario,
            Anulado = l.Anulado
        }));

        var actualizada = await GetNotaVentaOrThrowAsync(id);

        try
        {
            var documento = await _inventario.CrearSalidaVentaAsync(actualizada, usuarioId);
            actualizada.DocumentoInventarioId = documento.Id;
            await _repository.UpdateNotaVentaAsync(actualizada);
        }
        catch
        {
            // Igual que al crearla: si el nuevo descuento no se puede hacer
            // (ya no alcanza el stock), la nota no queda a medias — se anula.
            actualizada.Estado = EstadoNotaVenta.Anulada;
            actualizada.DocumentoInventarioId = null;
            await _repository.UpdateNotaVentaAsync(actualizada);
            throw;
        }

        var resultado = await GetNotaVentaAsync(id);
        await _notificador.AvisarAsync("notasventa", "actualizada", resultado);
        return resultado;
    }

    public async Task AnularNotaVentaAsync(int id, int? usuarioId)
    {
        var notaVenta = await GetNotaVentaOrThrowAsync(id);

        if (notaVenta.Estado == EstadoNotaVenta.Anulada)
        {
            throw new BadRequestException("Esta nota de venta ya está anulada.");
        }

        // Si el descuento de stock nunca llegó a completarse al crearla, no
        // hay nada que revertir: solo queda cerrar el estado.
        if (notaVenta.DocumentoInventarioId is int documentoId)
        {
            await _inventario.AnularAsync(documentoId, usuarioId);
        }

        notaVenta.Estado = EstadoNotaVenta.Anulada;
        await _repository.UpdateNotaVentaAsync(notaVenta);

        // Lo que esa venta dejó sin entregar ya no cuenta: al rehacerla
        // nacerán las novedades nuevas.
        await _novedades.AnularDeVentaAsync(id);

        // El pedido del que salio vuelve a quedar disponible: sin esto se
        // quedaria marcado como convertido para siempre y el cliente no
        // tendria forma de recibir su mercaderia.
        if (notaVenta.PedidoId is int pedidoId)
        {
            var pedido = await _repository.GetPedidoAsync(pedidoId);
            if (pedido is not null && pedido.Estado == EstadoPedido.Confirmado)
            {
                pedido.Estado = EstadoPedido.Pendiente;
                await _repository.UpdatePedidoAsync(pedido);
                await _notificador.AvisarAsync("pedidos", "reabierto", MapPedido(pedido));
            }
        }

        await _notificador.AvisarAsync("notasventa", "anulada", MapNotaVenta(notaVenta));
    }

    /// <summary>
    /// Un abono más contra la nota: no reemplaza los pagos existentes, se
    /// suma. No se acepta si ya está saldada o si el abono se pasa del saldo
    /// pendiente — no tiene sentido cobrar de más.
    /// </summary>
    public async Task<NotaVentaResponse> RegistrarPagoAsync(int id, PagoVentaRequest request, int? usuarioId)
    {
        await _pagoValidator.ValidateAndThrowAsync(request);

        var notaVenta = await GetNotaVentaOrThrowAsync(id);

        if (notaVenta.Estado == EstadoNotaVenta.Anulada)
        {
            throw new BadRequestException("Esta nota de venta está anulada: no se le pueden registrar pagos.");
        }

        var total = Math.Round(notaVenta.Detalle.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion), 2);
        var pagado = Math.Round(notaVenta.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto), 2);
        var saldo = total - pagado;

        if (saldo <= 0)
        {
            throw new BadRequestException("Esta nota de venta ya está pagada por completo.");
        }

        if (request.Monto > saldo)
        {
            throw new BadRequestException(
                $"El abono (S/ {request.Monto}) supera el saldo pendiente (S/ {saldo}).");
        }

        notaVenta.Pagos.Add(new PagoVenta
        {
            MetodoPagoId = request.MetodoPagoId,
            Monto = request.Monto,
            UsuarioId = usuarioId
        });
        await _repository.UpdateNotaVentaAsync(notaVenta);

        var actualizada = await GetNotaVentaAsync(id);
        await _notificador.AvisarAsync("notasventa", "pago", actualizada);
        return actualizada;
    }

    public async Task<NotaVentaResponse> ActualizarPagoAsync(int id, int pagoId, PagoVentaRequest request)
    {
        await _pagoValidator.ValidateAndThrowAsync(request);

        var notaVenta = await GetNotaVentaOrThrowAsync(id);

        if (notaVenta.Estado == EstadoNotaVenta.Anulada)
        {
            throw new BadRequestException("Esta nota de venta está anulada: no se le pueden editar pagos.");
        }

        var pago = notaVenta.Pagos.FirstOrDefault(p => p.Id == pagoId)
            ?? throw new NotFoundException($"Esta nota de venta no tiene el pago {pagoId}");

        if (pago.Anulado)
        {
            throw new BadRequestException("Este pago está anulado: no se puede editar.");
        }

        var total = Math.Round(notaVenta.Detalle.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion), 2);
        var pagadoSinEste = Math.Round(
            notaVenta.Pagos.Where(p => p.Id != pagoId && !p.Anulado).Sum(p => p.Monto), 2);

        if (pagadoSinEste + request.Monto > total + 0.001m)
        {
            throw new BadRequestException(
                $"Ese cambio deja lo pagado en S/ {pagadoSinEste + request.Monto}, más que el total de la venta (S/ {total}).");
        }

        pago.MetodoPagoId = request.MetodoPagoId;
        pago.Monto = request.Monto;
        await _repository.GuardarAsync();

        var actualizada = await GetNotaVentaAsync(id);
        await _notificador.AvisarAsync("notasventa", "pago", actualizada);
        return actualizada;
    }

    /// <summary>
    /// Anula un pago registrado por error: se conserva en el historial (no se
    /// borra), pero deja de contar para el total cobrado — su monto vuelve al
    /// saldo pendiente.
    /// </summary>
    public async Task<NotaVentaResponse> AnularPagoAsync(int id, int pagoId)
    {
        var notaVenta = await GetNotaVentaOrThrowAsync(id);

        if (notaVenta.Estado == EstadoNotaVenta.Anulada)
        {
            throw new BadRequestException("Esta nota de venta está anulada: no se le pueden anular pagos.");
        }

        var pago = notaVenta.Pagos.FirstOrDefault(p => p.Id == pagoId)
            ?? throw new NotFoundException($"Esta nota de venta no tiene el pago {pagoId}");

        if (pago.Anulado)
        {
            throw new BadRequestException("Este pago ya está anulado.");
        }

        pago.Anulado = true;
        await _repository.GuardarAsync();

        var actualizada = await GetNotaVentaAsync(id);
        await _notificador.AvisarAsync("notasventa", "pago", actualizada);
        return actualizada;
    }

    public async Task<PaginaResponse<NotaVentaResponse>> ListarCuentasPorCobrarAsync(
        ConsultaTablaRequest consulta)
    {
        var (items, total) = await _repository.ListarCuentasPorCobrarAsync(consulta);

        return new PaginaResponse<NotaVentaResponse>
        {
            Items = items.Select(MapNotaVenta).ToList(),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public Task<ResumenCuentasResponse> GetResumenCuentasPorCobrarAsync() =>
        _repository.ResumenCuentasPorCobrarAsync();

    public async Task<IEnumerable<NotaVentaResponse>> GetCuentasPorCobrarAsync()
    {
        var notas = await _repository.GetNotasVentaAsync(EstadoNotaVenta.Confirmada);
        return notas
            .Where(n => n.FormaPago == FormaPagoVenta.Credito)
            .Select(MapNotaVenta)
            .Where(n => n.Total - n.TotalPagado > 0);
    }

    public async Task<IEnumerable<CobroResponse>> GetMisCobrosAsync(int? usuarioId, DateTime? desde, DateTime? hasta)
    {
        var notas = await _repository.GetNotasVentaAsync(EstadoNotaVenta.Confirmada);

        return notas
            .SelectMany(n => n.Pagos.Select(p => (Nota: n, Pago: p)))
            .Where(x => usuarioId == null || x.Pago.UsuarioId == usuarioId)
            .Where(x => desde == null || x.Pago.Fecha >= desde)
            .Where(x => hasta == null || x.Pago.Fecha <= hasta)
            .OrderByDescending(x => x.Pago.Fecha)
            .Select(x => new CobroResponse
            {
                Id = x.Pago.Id,
                Fecha = x.Pago.Fecha,
                NotaVentaId = x.Nota.Id,
                NotaVentaNumero = x.Nota.Numero,
                ClienteId = x.Nota.ClienteId,
                Cliente = x.Nota.Cliente?.Nombre ?? string.Empty,
                MetodoPagoId = x.Pago.MetodoPagoId,
                MetodoPago = x.Pago.MetodoPago?.Nombre ?? string.Empty,
                Monto = x.Pago.Monto,
                Anulado = x.Pago.Anulado
            });
    }

    public async Task<PaginaResponse<CobroResponse>> ListarMisCobrosAsync(
        ConsultaTablaRequest consulta, int? usuarioId, DateTime? desde, DateTime? hasta)
    {
        var (items, total) = await _repository.ListarCobrosAsync(consulta, usuarioId, desde, hasta);

        return new PaginaResponse<CobroResponse>
        {
            Items = items.Select(MapCobro).ToList(),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public Task<ResumenCobrosResponse> GetResumenCobrosAsync(int? usuarioId, DateTime? desde, DateTime? hasta) =>
        _repository.ResumenCobrosAsync(usuarioId, desde, hasta);

    private static CobroResponse MapCobro(PagoVenta p) => new()
    {
        Id = p.Id,
        Fecha = p.Fecha,
        NotaVentaId = p.NotaVentaId,
        NotaVentaNumero = p.NotaVenta?.Numero ?? string.Empty,
        ClienteId = p.NotaVenta?.ClienteId ?? 0,
        Cliente = p.NotaVenta?.Cliente?.Nombre ?? string.Empty,
        MetodoPagoId = p.MetodoPagoId,
        MetodoPago = p.MetodoPago?.Nombre ?? string.Empty,
        Monto = p.Monto,
        Anulado = p.Anulado,
    };

    // ------------------------------------------------------------ Auxiliares

    /// <summary>
    /// Crea la NotaVenta (cabecera, líneas y pagos) y de inmediato descuenta
    /// el stock contra ella. Si el descuento falla, la nota queda guardada
    /// pero Anulada: el número no se pierde y el motivo real del fallo (por
    /// ejemplo, stock insuficiente) llega tal cual al que la creó.
    /// </summary>
    private async Task<NotaVentaResponse> CrearNotaVentaInternaAsync(
        int clienteId,
        int almacenId,
        int? pedidoId,
        string? formaPago,
        List<PagoVentaRequest> pagos,
        string? observacion,
        List<PedidoDetalle> lineas,
        int? usuarioId)
    {
        // Antes de guardar nada: si el almacén no existe o está desactivado,
        // mejor que falle aquí que dejar una nota guardada sin poder despachar.
        var almacen = await _inventario.GetAlmacenAsync(almacenId);
        if (!almacen.Activo)
        {
            throw new BadRequestException("El almacén está desactivado");
        }

        var forma = string.IsNullOrWhiteSpace(formaPago) ? FormaPagoVenta.Contado : formaPago;
        var total = Math.Round(lineas.Sum(l => l.CantidadPresentacion * l.PrecioPresentacion), 2);
        var cobrado = Math.Round(pagos.Sum(p => p.Monto), 2);

        // Al contado significa que el dinero entra ahora: sin esto se guardaba
        // una venta cobrada que en realidad nadie pagó, y como no es a credito
        // tampoco aparecia en cuentas por cobrar — la deuda desaparecia.
        if (forma == FormaPagoVenta.Contado && cobrado != total)
        {
            throw new BadRequestException(cobrado < total
                ? $"Una venta al contado se cobra completa: faltan S/ {total - cobrado:N2} por registrar."
                : $"Los pagos (S/ {cobrado:N2}) superan el total de la venta (S/ {total:N2}).");
        }

        // A credito el adelanto es opcional, pero nunca mayor que la venta.
        if (forma == FormaPagoVenta.Credito && cobrado > total)
        {
            throw new BadRequestException(
                $"El adelanto (S/ {cobrado:N2}) supera el total de la venta (S/ {total:N2}).");
        }

        var notaVenta = new NotaVenta
        {
            Numero = await _repository.SiguienteNumeroNotaVentaAsync(),
            ClienteId = clienteId,
            PedidoId = pedidoId,
            AlmacenId = almacenId,
            Fecha = DateTime.UtcNow,
            Estado = EstadoNotaVenta.Confirmada,
            FormaPago = forma,
            Observacion = Limpiar(observacion),
            UsuarioId = usuarioId,
            Detalle = lineas.Select(l => new NotaVentaDetalle
            {
                ProductoId = l.ProductoId,
                PresentacionId = l.PresentacionId,
                CantidadPresentacion = l.CantidadPresentacion,
                Cantidad = l.Cantidad,
                PrecioPresentacion = l.PrecioPresentacion,
                PrecioUnitario = l.PrecioUnitario
            }).ToList(),
            Pagos = pagos.Select(p => new PagoVenta
            {
                MetodoPagoId = p.MetodoPagoId,
                Monto = p.Monto,
                UsuarioId = usuarioId
            }).ToList()
        };

        await _repository.AddNotaVentaAsync(notaVenta);

        try
        {
            var documento = await _inventario.CrearSalidaVentaAsync(notaVenta, usuarioId);
            notaVenta.DocumentoInventarioId = documento.Id;
            await _repository.UpdateNotaVentaAsync(notaVenta);
        }
        catch
        {
            notaVenta.Estado = EstadoNotaVenta.Anulada;
            await _repository.UpdateNotaVentaAsync(notaVenta);
            throw;
        }

        var creada = await GetNotaVentaAsync(notaVenta.Id);
        await _notificador.AvisarAsync("notasventa", "creado", creada);
        return creada;
    }

    /// <summary>
    /// Cada línea: resuelve el producto y la presentación, y convierte la
    /// cantidad a unidad base — igual que hace Compras al registrar una línea.
    /// </summary>
    /// <summary>
    /// Lo que la edicion quiere quitarle a la venta, y que en vez de quitarse
    /// se registra como devolucion.
    ///
    /// Devuelve las bajas de cantidad y las lineas que se anulan, Y DEJA EL
    /// REQUEST COMO ESTABA: la venta guarda lo que el cliente se llevo, que es
    /// lo que dice el documento que firmo, hasta que alguien apruebe la
    /// devolucion. Lo que sube de cantidad o se agrega se aplica normal — eso
    /// es vender mas, no devolver.
    /// </summary>
    private static List<LineaDevolucionRequest> RecortesAsync(
        NotaVenta notaVenta, List<LineaVentaRequest> detalle)
    {
        var previas = notaVenta.Detalle
            .Where(d => !d.Anulado)
            .ToDictionary(d => d.Id);

        var recortes = new List<LineaDevolucionRequest>();

        foreach (var linea in detalle)
        {
            if (linea.Id is not int lineaId) continue;
            if (!previas.TryGetValue(lineaId, out var antes)) continue;

            var pedida = linea.Anulado ? 0m : linea.Cantidad;
            var recorte = antes.CantidadPresentacion - pedida;
            if (recorte <= 0.0001m) continue;

            recortes.Add(new LineaDevolucionRequest
            {
                NotaVentaDetalleId = antes.Id,
                Cantidad = recorte,
                // Vuelve al stock: quien edita la venta no dice en que estado
                // llego la mercaderia. Si esta rota, se da de baja despues por
                // un ajuste, que es donde se explica el motivo.
                ReingresaStock = true,
            });

            // La linea se queda como estaba. La devolucion, al aprobarse, es
            // la que baja la cantidad y el importe.
            linea.Cantidad = antes.CantidadPresentacion;
            linea.Anulado = false;
        }

        /*
         * Quitar la fila entera es lo mismo que bajarla a cero.
         *
         * El formulario no manda la linea borrada: simplemente deja de venir.
         * Sin esto se perdia sin dejar devolucion, y como la venta si bajaba de
         * importe, chocaba con lo ya cobrado — que fue justo lo que se vio.
         */
        var enviadas = detalle
            .Where(l => l.Id is int)
            .Select(l => l.Id!.Value)
            .ToHashSet();

        foreach (var antes in previas.Values.Where(d => !enviadas.Contains(d.Id)))
        {
            recortes.Add(new LineaDevolucionRequest
            {
                NotaVentaDetalleId = antes.Id,
                Cantidad = antes.CantidadPresentacion,
                ReingresaStock = true,
            });

            // Vuelve al request tal como estaba: la quita la devolucion al
            // aprobarse, no esta edicion.
            var factor = antes.CantidadPresentacion > 0
                ? antes.Cantidad / antes.CantidadPresentacion
                : 1m;

            detalle.Add(new LineaVentaRequest
            {
                Id = antes.Id,
                ProductoId = antes.ProductoId,
                PresentacionId = antes.PresentacionId,
                Cantidad = antes.CantidadPresentacion,
                PrecioUnitario = antes.PrecioPresentacion,
            });
        }

        return recortes;
    }

    private async Task<List<PedidoDetalle>> ResolverLineasAsync(
        List<LineaVentaRequest> detalle, int pedidoId = 0)
    {
        var lineas = new List<PedidoDetalle>();

        foreach (var linea in detalle)
        {
            var producto = await _productos.GetConDetalleAsync(linea.ProductoId)
                ?? throw new BadRequestException($"No existe el producto {linea.ProductoId}");

            if (!producto.ControlaStock)
            {
                throw new BadRequestException(
                    $"'{producto.Nombre}' no controla stock: no se puede vender.");
            }

            var factor = 1m;
            ProductoPresentacion? presentacion = null;

            if (linea.PresentacionId is int presentacionId)
            {
                presentacion = await _productos.GetPresentacionAsync(presentacionId)
                    ?? throw new BadRequestException("La presentación indicada no existe");

                if (presentacion.ProductoId != producto.Id)
                {
                    throw new BadRequestException(
                        $"La presentación '{presentacion.Nombre}' no es de '{producto.Nombre}'.");
                }

                factor = presentacion.Factor;
            }

            // Una línea quitada del pedido no se valida: ya no cuenta para nada.
            if (!linea.Anulado && !DisponibilidadPresentacion.SeVende(producto, presentacion))
            {
                throw new BadRequestException(
                    $"'{producto.Nombre}' no se vende en {presentacion?.Nombre ?? "su unidad base"}: " +
                    "elige otra presentación o quita la línea.");
            }

            var cantidad = linea.Cantidad * factor;

            lineas.Add(new PedidoDetalle
            {
                Id = linea.Id ?? 0,
                PedidoId = pedidoId,
                ProductoId = producto.Id,
                PresentacionId = presentacion?.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidad,
                /*
                 * Lo que se pacto, tal cual: S/ 212.50 el saco.
                 *
                 * Antes solo se guardaba el precio por unidad base y al volver
                 * a la pantalla habia que multiplicarlo por el factor; como la
                 * division redondea, 13.60 el saco de 3 kilos volvia como
                 * 13.5999. Ahora el de base se deriva de este y no al reves.
                 */
                PrecioPresentacion = linea.PrecioUnitario,
                PrecioUnitario = cantidad == 0 ? 0 : Math.Round(linea.PrecioUnitario / factor, 4),
                Anulado = linea.Anulado
            });
        }

        return lineas;
    }

    private async Task ValidarAlmacenReservaAsync(int almacenId)
    {
        var almacen = await _inventario.GetAlmacenAsync(almacenId);
        if (!almacen.Activo)
        {
            throw new BadRequestException("El almacén está desactivado");
        }
    }

    /*
     * Todo acceso a UN pedido pasa por aqui — verlo, editarlo, confirmarlo,
     * anularlo — y por eso el alcance se aplica en este punto y no en cada
     * metodo: asi no queda ninguna puerta sin cerrar, y la que se abra manana
     * tampoco.
     *
     * Fuera de alcance responde "no existe" y no "no puedes": decir que existe
     * un pedido que no se puede ver ya es contar algo de un cliente ajeno.
     */
    private async Task<Pedido> GetPedidoOrThrowAsync(int id) =>
        await _repository.GetPedidoAsync(id, await AlcancePedidosAsync())
        ?? throw new NotFoundException($"No existe el pedido {id}");

    private async Task<NotaVenta> GetNotaVentaOrThrowAsync(int id) =>
        await _repository.GetNotaVentaAsync(id, await AlcanceVentasAsync())
        ?? throw new NotFoundException($"No existe la nota de venta {id}");

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static LineaVentaResponse MapLinea(PedidoDetalle d) => new()
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
        PrecioUnitario = d.PrecioUnitario,
        PrecioPresentacion = d.PrecioPresentacion,
        Subtotal = Math.Round(d.CantidadPresentacion * d.PrecioPresentacion, 2),
        Anulado = d.Anulado
    };

    private static LineaVentaResponse MapLinea(NotaVentaDetalle d) => new()
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
        PrecioUnitario = d.PrecioUnitario,
        PrecioPresentacion = d.PrecioPresentacion,
        Subtotal = Math.Round(d.CantidadPresentacion * d.PrecioPresentacion, 2),
        Anulado = d.Anulado
    };

    /// <summary>
    /// La venta viva de un pedido: la que nació de él y no está anulada.
    ///
    /// No puede haber dos — es lo que impide convertir el mismo pedido dos
    /// veces —, pero sí puede haber varias anuladas detrás.
    /// </summary>
    private static NotaVenta? VentaVigente(Pedido p) =>
        p.Ventas.FirstOrDefault(v => v.Estado != EstadoNotaVenta.Anulada);

    private static PedidoResponse MapPedido(Pedido p) => new()
    {
        Id = p.Id,
        Numero = p.Numero,
        ClienteId = p.ClienteId,
        Cliente = p.Cliente?.Nombre ?? string.Empty,
        ListaPrecioId = p.ListaPrecioId,
        ListaPrecio = p.ListaPrecio?.Nombre,
        Fecha = p.Fecha,
        Estado = p.Estado,
        CondicionPago = p.CondicionPago,
        Observacion = p.Observacion,
        Usuario = p.Usuario?.Nombre,
        ReservaStock = p.ReservaStock,
        NotaVentaId = VentaVigente(p)?.Id,
        NotaVentaNumero = VentaVigente(p)?.Numero,
        AlmacenId = p.AlmacenId,
        Almacen = p.Almacen?.Nombre,
        // Una línea anulada se sigue mostrando (para no perder su rastro),
        // pero no suma al total.
        Total = Math.Round(p.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion), 2),
        Detalle = p.Detalle.Select(MapLinea).ToList()
    };

    private static NotaVentaResponse MapNotaVenta(NotaVenta n) => new()
    {
        Id = n.Id,
        Numero = n.Numero,
        ClienteId = n.ClienteId,
        Cliente = n.Cliente?.Nombre ?? string.Empty,
        PedidoId = n.PedidoId,
        PedidoNumero = n.Pedido?.Numero,
        AlmacenId = n.AlmacenId,
        Almacen = n.Almacen?.Nombre ?? string.Empty,
        Fecha = n.Fecha,
        Estado = n.Estado,
        FormaPago = n.FormaPago,
        Observacion = n.Observacion,
        Usuario = n.Usuario?.Nombre,
        // Una línea anulada se sigue mostrando (para no perder su rastro),
        // pero no suma al total.
        Total = Math.Round(n.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion), 2),
        Detalle = n.Detalle.Select(MapLinea).ToList(),
        Pagos = n.Pagos.Select(MapPago).ToList(),
        TotalPagado = Math.Round(n.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto), 2),
        // Historico: lo que el cliente trajo de vuelta. Ya NO se le resta al
        // total —el detalle viene descontado al aprobarse—, esta para poder
        // decir cuanto se devolvio de esta venta.
        TotalDevuelto = Math.Round(
            n.Devoluciones
                .Where(d => d.Estado == EstadoDevolucion.Aprobada)
                .Sum(d => d.Detalle.Sum(l => l.Cantidad * l.PrecioUnitario)), 2),
        Devoluciones = n.Devoluciones
            .OrderByDescending(d => d.Id)
            .Select(d => new DevolucionDeVentaResponse
            {
                Id = d.Id,
                Numero = d.Numero,
                Fecha = d.Fecha,
                Estado = d.Estado,
                Motivo = d.Motivo,
                MotivoRechazo = d.MotivoRechazo,
                Usuario = d.Usuario?.Nombre,
                AprobadoPor = d.AprobadoPor?.Nombre,
                Total = Math.Round(d.Detalle.Sum(l => l.Cantidad * l.PrecioUnitario), 2),
                Detalle = d.Detalle
                    .Select(l => new LineaDevueltaResponse
                    {
                        NotaVentaDetalleId = l.NotaVentaDetalleId,
                        Producto = l.NotaVentaDetalle?.Producto?.Nombre ?? string.Empty,
                        Cantidad = l.CantidadPresentacion,
                        Unidad = l.NotaVentaDetalle?.Presentacion?.Nombre
                            ?? l.NotaVentaDetalle?.Producto?.UnidadBase?.Codigo
                            ?? string.Empty,
                        Importe = Math.Round(l.Cantidad * l.PrecioUnitario, 2),
                    })
                    .ToList(),
            })
            .ToList()
    };

    private static PagoVentaResponse MapPago(PagoVenta p) => new()
    {
        Id = p.Id,
        MetodoPagoId = p.MetodoPagoId,
        MetodoPago = p.MetodoPago?.Nombre ?? string.Empty,
        Monto = p.Monto,
        Fecha = p.Fecha,
        Usuario = p.Usuario?.Nombre,
        Anulado = p.Anulado
    };
}
