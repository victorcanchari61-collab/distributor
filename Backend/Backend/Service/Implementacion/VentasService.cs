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
    private readonly IValidator<CrearNotaVentaRequest> _notaVentaValidator;
    private readonly IValidator<PagoVentaRequest> _pagoValidator;
    private readonly INotificador _notificador;

    public VentasService(
        IVentasRepository repository,
        IProductoRepository productos,
        IInventarioService inventario,
        IAuditoriaService auditoria,
        IValidator<CrearPedidoRequest> pedidoValidator,
        IValidator<ConfirmarPedidoRequest> confirmarValidator,
        IValidator<CrearNotaVentaRequest> notaVentaValidator,
        IValidator<PagoVentaRequest> pagoValidator,
        INotificador notificador)
    {
        _repository = repository;
        _productos = productos;
        _inventario = inventario;
        _auditoria = auditoria;
        _pedidoValidator = pedidoValidator;
        _confirmarValidator = confirmarValidator;
        _notaVentaValidator = notaVentaValidator;
        _pagoValidator = pagoValidator;
        _notificador = notificador;
    }

    // --------------------------------------------------------------- Pedidos

    public async Task<IEnumerable<PedidoResponse>> GetPedidosAsync(string? estado = null)
    {
        var pedidos = await _repository.GetPedidosAsync(estado);
        return pedidos.Select(MapPedido);
    }

    public async Task<PedidoResponse> GetPedidoAsync(int id) =>
        MapPedido(await GetPedidoOrThrowAsync(id));

    public async Task<PedidoResponse> CrearPedidoAsync(CrearPedidoRequest request, int? usuarioId)
    {
        await _pedidoValidator.ValidateAndThrowAsync(request);

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

        pedido.ClienteId = request.ClienteId;
        pedido.ListaPrecioId = request.ListaPrecioId;
        pedido.Fecha = request.Fecha ?? pedido.Fecha;
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

        if (pedido.Estado != EstadoPedido.Pendiente)
        {
            throw new BadRequestException("Este pedido ya fue confirmado o anulado.");
        }

        // Un pedido no lleva pagos: la nota que nace al confirmarlo queda a
        // crédito, pendiente de cobro, hasta que se registre uno.
        var notaVenta = await CrearNotaVentaInternaAsync(
            clienteId: pedido.ClienteId,
            almacenId: request.AlmacenId,
            pedidoId: pedido.Id,
            formaPago: FormaPagoVenta.Credito,
            pagos: [],
            observacion: pedido.Observacion,
            // Una línea anulada al editar el pedido no se despacha: quedó
            // fuera del total y no debe salir del almacén.
            lineas: pedido.Detalle.Where(d => !d.Anulado).Select(d => new PedidoDetalle
            {
                ProductoId = d.ProductoId,
                PresentacionId = d.PresentacionId,
                CantidadPresentacion = d.CantidadPresentacion,
                Cantidad = d.Cantidad,
                PrecioUnitario = d.PrecioUnitario
            }).ToList(),
            usuarioId: usuarioId);

        pedido.Estado = EstadoPedido.Confirmado;
        await _repository.UpdatePedidoAsync(pedido);

        await _notificador.AvisarAsync("pedidos", "confirmado", MapPedido(pedido));
        return notaVenta;
    }

    /// <summary>Qué cambió en este pedido y sus líneas, para verlo desde el propio documento.</summary>
    public async Task<IEnumerable<AuditoriaResponse>> GetHistorialPedidoAsync(int id)
    {
        var pedido = await GetPedidoOrThrowAsync(id);
        var idsLineas = pedido.Detalle.Select(d => d.Id);
        return await _auditoria.GetHistorialDocumentoAsync("Pedido", id, "PedidoDetalle", idsLineas);
    }

    /// <summary>Qué cambió en esta nota de venta: ediciones de línea, anulaciones y movimientos de pago.</summary>
    public async Task<IEnumerable<AuditoriaResponse>> GetHistorialNotaVentaAsync(int id)
    {
        var notaVenta = await GetNotaVentaOrThrowAsync(id);
        var idsLineas = notaVenta.Detalle.Select(d => d.Id);
        var idsPagos = notaVenta.Pagos.Select(p => p.Id);

        var historial = (await _auditoria.GetHistorialDocumentoAsync("NotaVenta", id, "NotaVentaDetalle", idsLineas))
            .ToList();

        // El de arriba ya trajo los cambios de cabecera (Entidad == "NotaVenta");
        // de esta segunda pasada solo hacen falta los de PagoVenta, para no
        // repetir la cabecera dos veces.
        var historialPagos = await _auditoria.GetHistorialDocumentoAsync("NotaVenta", id, "PagoVenta", idsPagos);
        historial.AddRange(historialPagos.Where(r => r.Entidad == "PagoVenta"));

        return historial.OrderByDescending(r => r.Fecha).ThenByDescending(r => r.Id);
    }

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
        await _notificador.AvisarAsync("pedidos", "anulado", MapPedido(pedido));
    }

    // ----------------------------------------------------------- Notas de venta

    public async Task<IEnumerable<NotaVentaResponse>> GetNotasVentaAsync(string? estado = null)
    {
        var notas = await _repository.GetNotasVentaAsync(estado);
        return notas.Select(MapNotaVenta);
    }

    public async Task<NotaVentaResponse> GetNotaVentaAsync(int id) =>
        MapNotaVenta(await GetNotaVentaOrThrowAsync(id));

    public async Task<NotaVentaResponse> CrearNotaVentaAsync(CrearNotaVentaRequest request, int? usuarioId)
    {
        await _notaVentaValidator.ValidateAndThrowAsync(request);

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

        var lineas = await ResolverLineasAsync(request.Detalle);
        var nuevoTotal = Math.Round(lineas.Where(l => !l.Anulado).Sum(l => l.Cantidad * l.PrecioUnitario), 2);
        var pagado = Math.Round(notaVenta.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto), 2);

        if (nuevoTotal < pagado - 0.001m)
        {
            throw new BadRequestException(
                $"El nuevo total (S/ {nuevoTotal}) queda por debajo de lo ya cobrado (S/ {pagado}). "
                + "Anula o corrige el pago primero.");
        }

        // Se devuelve el stock que había salido con las cantidades anteriores:
        // abajo se vuelve a descontar ya con las cantidades corregidas.
        if (notaVenta.DocumentoInventarioId is int documentoAnteriorId)
        {
            await _inventario.AnularAsync(documentoAnteriorId, usuarioId);
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

        var total = Math.Round(notaVenta.Detalle.Sum(d => d.Cantidad * d.PrecioUnitario), 2);
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

        var total = Math.Round(notaVenta.Detalle.Sum(d => d.Cantidad * d.PrecioUnitario), 2);
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

        var notaVenta = new NotaVenta
        {
            Numero = await _repository.SiguienteNumeroNotaVentaAsync(),
            ClienteId = clienteId,
            PedidoId = pedidoId,
            AlmacenId = almacenId,
            Fecha = DateTime.UtcNow,
            Estado = EstadoNotaVenta.Confirmada,
            FormaPago = string.IsNullOrWhiteSpace(formaPago) ? FormaPagoVenta.Contado : formaPago,
            Observacion = Limpiar(observacion),
            UsuarioId = usuarioId,
            Detalle = lineas.Select(l => new NotaVentaDetalle
            {
                ProductoId = l.ProductoId,
                PresentacionId = l.PresentacionId,
                CantidadPresentacion = l.CantidadPresentacion,
                Cantidad = l.Cantidad,
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

            var cantidad = linea.Cantidad * factor;

            lineas.Add(new PedidoDetalle
            {
                Id = linea.Id ?? 0,
                PedidoId = pedidoId,
                ProductoId = producto.Id,
                PresentacionId = presentacion?.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidad,
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

    private async Task<Pedido> GetPedidoOrThrowAsync(int id) =>
        await _repository.GetPedidoAsync(id)
        ?? throw new NotFoundException($"No existe el pedido {id}");

    private async Task<NotaVenta> GetNotaVentaOrThrowAsync(int id) =>
        await _repository.GetNotaVentaAsync(id)
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
        Cantidad = d.Cantidad,
        PrecioUnitario = d.PrecioUnitario,
        Subtotal = Math.Round(d.Cantidad * d.PrecioUnitario, 2),
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
        Cantidad = d.Cantidad,
        PrecioUnitario = d.PrecioUnitario,
        Subtotal = Math.Round(d.Cantidad * d.PrecioUnitario, 2),
        Anulado = d.Anulado
    };

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
        Observacion = p.Observacion,
        Usuario = p.Usuario?.Nombre,
        ReservaStock = p.ReservaStock,
        AlmacenId = p.AlmacenId,
        Almacen = p.Almacen?.Nombre,
        // Una línea anulada se sigue mostrando (para no perder su rastro),
        // pero no suma al total.
        Total = Math.Round(p.Detalle.Where(d => !d.Anulado).Sum(d => d.Cantidad * d.PrecioUnitario), 2),
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
        Total = Math.Round(n.Detalle.Where(d => !d.Anulado).Sum(d => d.Cantidad * d.PrecioUnitario), 2),
        Detalle = n.Detalle.Select(MapLinea).ToList(),
        Pagos = n.Pagos.Select(MapPago).ToList(),
        TotalPagado = Math.Round(n.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto), 2)
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
