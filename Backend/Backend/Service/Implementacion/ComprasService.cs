using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Lo que se le pide a un proveedor, y lo que de eso queda listo para recibir.
///
/// Reglas:
///
///   - Una orden Pendiente es solo una intención: se edita o se anula libre.
///   - Confirmarla es aceptar que el proveedor va a despachar. Desde ahí no
///     se edita, y ese mismo paso crea la Compra — el seguimiento sigue ahí,
///     no en la orden.
///   - Una compra puede nacer de confirmar una orden, o registrarse directa
///     (al contado, sin negociación previa). Las dos terminan igual: listas
///     para que Recepciones las vaya descargando.
///   - Una compra con algo ya recibido no se anula entera: hay que anular las
///     recepciones una por una (eso sí revierte el stock correctamente).
/// </summary>
public class ComprasService : IComprasService
{
    private readonly IComprasRepository _repository;
    private readonly IProductoRepository _productos;
    private readonly IValidator<CrearOrdenCompraRequest> _ordenValidator;
    private readonly IValidator<CrearCompraRequest> _compraValidator;
    private readonly IValidator<PagoCompraRequest> _pagoValidator;
    private readonly INotificador _notificador;

    public ComprasService(
        IComprasRepository repository,
        IProductoRepository productos,
        IValidator<CrearOrdenCompraRequest> ordenValidator,
        IValidator<CrearCompraRequest> compraValidator,
        IValidator<PagoCompraRequest> pagoValidator,
        INotificador notificador)
    {
        _repository = repository;
        _productos = productos;
        _ordenValidator = ordenValidator;
        _compraValidator = compraValidator;
        _pagoValidator = pagoValidator;
        _notificador = notificador;
    }

    // ------------------------------------------------------- Ordenes de compra

    public async Task<IEnumerable<OrdenCompraResponse>> GetOrdenesAsync(string? estado = null)
    {
        var ordenes = await _repository.GetOrdenesAsync(estado);
        return ordenes.Select(MapOrden);
    }

    public async Task<OrdenCompraResponse> GetOrdenAsync(int id) =>
        MapOrden(await GetOrdenOrThrowAsync(id));

    public async Task<OrdenCompraResponse> CrearOrdenAsync(
        CrearOrdenCompraRequest request, int? usuarioId)
    {
        await _ordenValidator.ValidateAndThrowAsync(request);

        var orden = new OrdenCompra
        {
            Numero = await _repository.SiguienteNumeroOrdenAsync(),
            ProveedorId = request.ProveedorId,
            Fecha = request.Fecha ?? DateTime.UtcNow,
            FechaEsperada = request.FechaEsperada,
            Estado = EstadoOrdenCompra.Pendiente,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId
        };

        orden.Detalle = await ResolverLineasAsync(request.Detalle);

        await _repository.AddOrdenAsync(orden);

        var creada = await GetOrdenAsync(orden.Id);
        await _notificador.AvisarAsync("ordenescompra", "creado", creada);
        return creada;
    }

    public async Task<OrdenCompraResponse> ActualizarOrdenAsync(int id, CrearOrdenCompraRequest request)
    {
        await _ordenValidator.ValidateAndThrowAsync(request);

        var orden = await GetOrdenOrThrowAsync(id);

        if (orden.Estado != EstadoOrdenCompra.Pendiente)
        {
            throw new BadRequestException(
                "Solo se puede editar una orden Pendiente. Si el proveedor ya la confirmó, anúlala y crea una nueva.");
        }

        orden.ProveedorId = request.ProveedorId;
        orden.Fecha = request.Fecha ?? orden.Fecha;
        orden.FechaEsperada = request.FechaEsperada;
        orden.Observacion = Limpiar(request.Observacion);

        await _repository.UpdateOrdenAsync(orden);
        await _repository.ReemplazarDetalleOrdenAsync(id, await ResolverLineasAsync(request.Detalle, id));

        var actualizada = await GetOrdenAsync(id);
        await _notificador.AvisarAsync("ordenescompra", "actualizado", actualizada);
        return actualizada;
    }

    public async Task<OrdenCompraResponse> ConfirmarOrdenAsync(int id)
    {
        var orden = await GetOrdenOrThrowAsync(id);

        if (orden.Estado != EstadoOrdenCompra.Pendiente)
        {
            throw new BadRequestException("Esta orden ya fue confirmada o anulada.");
        }

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        orden.Estado = EstadoOrdenCompra.Confirmada;
        await _repository.UpdateOrdenAsync(orden);

        // Nace la Compra: mismo proveedor, mismas líneas y costo pactado,
        // lista para que Recepciones la vaya descargando.
        var compra = new Compra
        {
            Numero = await _repository.SiguienteNumeroCompraAsync(),
            ProveedorId = orden.ProveedorId,
            OrdenCompraId = orden.Id,
            Fecha = DateTime.UtcNow,
            Estado = EstadoCompra.Pendiente,
            Observacion = orden.Observacion,
            UsuarioId = orden.UsuarioId,
            Detalle = orden.Detalle.Select(d => new CompraDetalle
            {
                ProductoId = d.ProductoId,
                PresentacionId = d.PresentacionId,
                CantidadPresentacion = d.CantidadPresentacion,
                Cantidad = d.Cantidad,
                CostoUnitario = d.CostoUnitario,
                CantidadRecibida = 0
            }).ToList()
        };

        await _repository.AddCompraAsync(compra);

        await transaccion.CommitAsync();

        var confirmada = await GetOrdenAsync(id);
        await _notificador.AvisarAsync("ordenescompra", "confirmada", confirmada);
        await _notificador.AvisarAsync("compras", "creado", MapCompra(compra));
        return confirmada;
    }

    public async Task AnularOrdenAsync(int id)
    {
        var orden = await GetOrdenOrThrowAsync(id);

        if (orden.Estado != EstadoOrdenCompra.Pendiente)
        {
            throw new BadRequestException(
                "Solo se puede anular una orden Pendiente. Una confirmada ya generó su compra: anula esa.");
        }

        orden.Estado = EstadoOrdenCompra.Anulada;
        await _repository.UpdateOrdenAsync(orden);
        await _notificador.AvisarAsync("ordenescompra", "anulada", MapOrden(orden));
    }

    // ------------------------------------------------------------------ Compras

    public async Task<IEnumerable<CompraResponse>> GetComprasAsync(string? estado = null)
    {
        var compras = await _repository.GetComprasAsync(estado);
        return compras.Select(MapCompra);
    }

    public async Task<CompraResponse> GetCompraAsync(int id) =>
        MapCompra(await GetCompraOrThrowAsync(id));

    public async Task<CompraResponse> CrearCompraAsync(CrearCompraRequest request, int? usuarioId)
    {
        await _compraValidator.ValidateAndThrowAsync(request);

        var compra = new Compra
        {
            Numero = await _repository.SiguienteNumeroCompraAsync(),
            ProveedorId = request.ProveedorId,
            OrdenCompraId = null,
            Fecha = request.Fecha ?? DateTime.UtcNow,
            Estado = EstadoCompra.Pendiente,
            TipoComprobante = string.IsNullOrWhiteSpace(request.TipoComprobante)
                ? TipoComprobanteCompra.Factura
                : request.TipoComprobante,
            SerieComprobante = Limpiar(request.SerieComprobante),
            NumeroComprobante = Limpiar(request.NumeroComprobante),
            FormaPago = string.IsNullOrWhiteSpace(request.FormaPago)
                ? FormaPagoCompra.Contado
                : request.FormaPago,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId
        };

        var lineas = await ResolverLineasAsync(request.Detalle);
        compra.Detalle = lineas.Select(l => new CompraDetalle
        {
            ProductoId = l.ProductoId,
            PresentacionId = l.PresentacionId,
            CantidadPresentacion = l.CantidadPresentacion,
            Cantidad = l.Cantidad,
            CostoUnitario = l.CostoUnitario,
            CantidadRecibida = 0
        }).ToList();

        // Un pago mixto puede quedar corto (crédito parcial), pero nunca pasarse:
        // no tiene sentido pagar más de lo que cuesta la compra.
        var total = Math.Round(lineas.Sum(l => l.Cantidad * l.CostoUnitario), 2);
        var totalPagado = Math.Round(request.Pagos.Sum(p => p.Monto), 2);
        if (totalPagado > total)
        {
            throw new BadRequestException(
                $"Los pagos suman S/ {totalPagado}, más que el total de la compra (S/ {total}).");
        }

        compra.Pagos = request.Pagos.Select(p => new CompraPago
        {
            MetodoPagoId = p.MetodoPagoId,
            Monto = p.Monto
        }).ToList();

        await _repository.AddCompraAsync(compra);

        var creada = await GetCompraAsync(compra.Id);
        await _notificador.AvisarAsync("compras", "creado", creada);
        return creada;
    }

    public async Task<CompraResponse> ActualizarCompraAsync(int id, CrearCompraRequest request)
    {
        await _compraValidator.ValidateAndThrowAsync(request);

        var compra = await GetCompraOrThrowAsync(id);

        if (compra.Estado != EstadoCompra.Pendiente)
        {
            throw new BadRequestException(
                "Solo se puede editar una compra Pendiente. Si ya tiene mercadería recibida, anula las recepciones primero.");
        }

        var lineas = await ResolverLineasAsync(request.Detalle);
        var total = Math.Round(lineas.Sum(l => l.Cantidad * l.CostoUnitario), 2);
        var totalPagado = Math.Round(request.Pagos.Sum(p => p.Monto), 2);
        if (totalPagado > total)
        {
            throw new BadRequestException(
                $"Los pagos suman S/ {totalPagado}, más que el total de la compra (S/ {total}).");
        }

        compra.ProveedorId = request.ProveedorId;
        compra.Fecha = request.Fecha ?? compra.Fecha;
        compra.TipoComprobante = string.IsNullOrWhiteSpace(request.TipoComprobante)
            ? TipoComprobanteCompra.Factura
            : request.TipoComprobante;
        compra.SerieComprobante = Limpiar(request.SerieComprobante);
        compra.NumeroComprobante = Limpiar(request.NumeroComprobante);
        compra.FormaPago = string.IsNullOrWhiteSpace(request.FormaPago)
            ? FormaPagoCompra.Contado
            : request.FormaPago;
        compra.Observacion = Limpiar(request.Observacion);

        await _repository.UpdateCompraAsync(compra);

        await _repository.ReemplazarDetalleCompraAsync(id, lineas.Select(l => new CompraDetalle
        {
            CompraId = id,
            ProductoId = l.ProductoId,
            PresentacionId = l.PresentacionId,
            CantidadPresentacion = l.CantidadPresentacion,
            Cantidad = l.Cantidad,
            CostoUnitario = l.CostoUnitario,
            CantidadRecibida = 0
        }));

        await _repository.ReemplazarPagosCompraAsync(id, request.Pagos.Select(p => new CompraPago
        {
            CompraId = id,
            MetodoPagoId = p.MetodoPagoId,
            Monto = p.Monto
        }));

        var actualizada = await GetCompraAsync(id);
        await _notificador.AvisarAsync("compras", "actualizado", actualizada);
        return actualizada;
    }

    public async Task AnularCompraAsync(int id)
    {
        var compra = await GetCompraOrThrowAsync(id);

        if (compra.Estado == EstadoCompra.Anulada)
        {
            throw new BadRequestException("Esta compra ya está anulada.");
        }

        if (compra.Estado != EstadoCompra.Pendiente)
        {
            throw new BadRequestException(
                "Esta compra ya tiene mercadería recibida: anula las recepciones, no la compra completa.");
        }

        compra.Estado = EstadoCompra.Anulada;
        await _repository.UpdateCompraAsync(compra);
        await _notificador.AvisarAsync("compras", "anulada", MapCompra(compra));
    }

    /// <summary>
    /// Un abono más contra la compra: no reemplaza los pagos existentes, se
    /// suma. No se acepta si ya está saldada o si el abono se pasa del saldo
    /// pendiente — no tiene sentido pagar de más.
    /// </summary>
    public async Task<CompraResponse> RegistrarPagoAsync(int id, PagoCompraRequest request)
    {
        await _pagoValidator.ValidateAndThrowAsync(request);

        var compra = await GetCompraOrThrowAsync(id);

        if (compra.Estado == EstadoCompra.Anulada)
        {
            throw new BadRequestException("Esta compra está anulada: no se le pueden registrar pagos.");
        }

        var total = Math.Round(compra.Detalle.Sum(d => d.Cantidad * d.CostoUnitario), 2);
        var pagado = Math.Round(compra.Pagos.Sum(p => p.Monto), 2);
        var saldo = total - pagado;

        if (saldo <= 0)
        {
            throw new BadRequestException("Esta compra ya está pagada por completo.");
        }

        if (request.Monto > saldo)
        {
            throw new BadRequestException(
                $"El abono (S/ {request.Monto}) supera el saldo pendiente (S/ {saldo}).");
        }

        compra.Pagos.Add(new CompraPago { MetodoPagoId = request.MetodoPagoId, Monto = request.Monto });
        await _repository.UpdateCompraAsync(compra);

        var actualizada = await GetCompraAsync(id);
        await _notificador.AvisarAsync("compras", "pago", actualizada);
        return actualizada;
    }

    public async Task<IEnumerable<CompraResponse>> GetCuentasPorPagarAsync()
    {
        var compras = await _repository.GetComprasAsync();
        return compras
            .Where(c => c.Estado != EstadoCompra.Anulada && c.FormaPago == FormaPagoCompra.Credito)
            .Select(MapCompra)
            .Where(c => c.Total - c.TotalPagado > 0);
    }

    // ------------------------------------------------------------ Auxiliares

    /// <summary>
    /// Cada línea: resuelve el producto y la presentación, y convierte la
    /// cantidad y el costo a unidad base — igual que hace un ajuste al
    /// registrar una entrada.
    /// </summary>
    private async Task<List<OrdenCompraDetalle>> ResolverLineasAsync(
        List<LineaCompraRequest> detalle, int ordenId = 0)
    {
        var lineas = new List<OrdenCompraDetalle>();

        foreach (var linea in detalle)
        {
            var producto = await _productos.GetConDetalleAsync(linea.ProductoId)
                ?? throw new BadRequestException($"No existe el producto {linea.ProductoId}");

            if (!producto.ControlaStock)
            {
                throw new BadRequestException(
                    $"'{producto.Nombre}' no controla stock: no se puede comprar.");
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
            var costoTotal = linea.CostoPresentacion * linea.Cantidad;

            lineas.Add(new OrdenCompraDetalle
            {
                OrdenCompraId = ordenId,
                ProductoId = producto.Id,
                PresentacionId = presentacion?.Id,
                CantidadPresentacion = linea.Cantidad,
                Cantidad = cantidad,
                CostoUnitario = cantidad == 0 ? 0 : Math.Round(costoTotal / cantidad, 4)
            });
        }

        return lineas;
    }

    private async Task<OrdenCompra> GetOrdenOrThrowAsync(int id) =>
        await _repository.GetOrdenAsync(id)
        ?? throw new NotFoundException($"No existe la orden de compra {id}");

    private async Task<Compra> GetCompraOrThrowAsync(int id) =>
        await _repository.GetCompraAsync(id)
        ?? throw new NotFoundException($"No existe la compra {id}");

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static LineaCompraResponse MapLinea(OrdenCompraDetalle d) => new()
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
        CostoUnitario = d.CostoUnitario,
        CostoTotal = Math.Round(d.Cantidad * d.CostoUnitario, 2)
    };

    private static OrdenCompraResponse MapOrden(OrdenCompra o) => new()
    {
        Id = o.Id,
        Numero = o.Numero,
        ProveedorId = o.ProveedorId,
        Proveedor = o.Proveedor?.Nombre ?? string.Empty,
        Fecha = o.Fecha,
        FechaEsperada = o.FechaEsperada,
        Estado = o.Estado,
        Observacion = o.Observacion,
        Usuario = o.Usuario?.Nombre,
        Total = Math.Round(o.Detalle.Sum(d => d.Cantidad * d.CostoUnitario), 2),
        Detalle = o.Detalle.Select(MapLinea).ToList()
    };

    private static CompraDetalleResponse MapCompraDetalle(CompraDetalle d) => new()
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
        CostoUnitario = d.CostoUnitario,
        CostoTotal = Math.Round(d.Cantidad * d.CostoUnitario, 2),
        CantidadRecibida = d.CantidadRecibida,
        CantidadPendiente = d.Cantidad - d.CantidadRecibida
    };

    private static CompraResponse MapCompra(Compra c) => new()
    {
        Id = c.Id,
        Numero = c.Numero,
        ProveedorId = c.ProveedorId,
        Proveedor = c.Proveedor?.Nombre ?? string.Empty,
        OrdenCompraId = c.OrdenCompraId,
        OrdenCompraNumero = c.OrdenCompra?.Numero,
        Fecha = c.Fecha,
        Estado = c.Estado,
        TipoComprobante = c.TipoComprobante,
        SerieComprobante = c.SerieComprobante,
        NumeroComprobante = c.NumeroComprobante,
        FormaPago = c.FormaPago,
        Observacion = c.Observacion,
        Usuario = c.Usuario?.Nombre,
        Total = Math.Round(c.Detalle.Sum(d => d.Cantidad * d.CostoUnitario), 2),
        Detalle = c.Detalle.Select(MapCompraDetalle).ToList(),
        Pagos = c.Pagos.Select(MapPago).ToList(),
        TotalPagado = Math.Round(c.Pagos.Sum(p => p.Monto), 2)
    };

    private static PagoCompraResponse MapPago(CompraPago p) => new()
    {
        Id = p.Id,
        MetodoPagoId = p.MetodoPagoId,
        MetodoPago = p.MetodoPago?.Nombre ?? string.Empty,
        Monto = p.Monto
    };
}
