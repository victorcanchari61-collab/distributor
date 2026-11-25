using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Devoluciones a proveedor y el saldo a favor que dejan.
///
/// Reglas:
///
///   - Una devolución nace de una compra y es parcial: unas líneas, unas cantidades. Cada línea dice de dónde sale (lo
///     que ya había llegado sale del stock; lo que no llegó, no) y qué da el proveedor a cambio.
///   - Reposición: el proveedor traerá lo mismo otro día. La plata no se toca y esa cantidad vuelve a quedar por
///     recibir en la compra: la reposición se recibe con una recepción normal.
///   - Descuento: la línea de la compra baja de cantidad, así que la compra entera baja de total (y con ella lo que
///     se debe). Si ya se le había pagado más que el total nuevo, la diferencia queda como saldo a favor.
///   - El saldo a favor se cierra cuando se cierre: el proveedor devuelve la plata (hoy, después, en partes) o se usa
///     para pagar otra compra suya.
///   - Anular una devolución la deshace entera, salvo que ya se haya recibido la reposición o se haya cobrado o
///     usado el saldo a favor que dio: eso hay que deshacerlo primero.
/// </summary>
public class DevolucionProveedorService : IDevolucionProveedorService
{
    private readonly IComprasRepository _repository;
    private readonly IComprasService _compras;
    private readonly IInventarioService _inventario;
    private readonly IFinanzasService _finanzas;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly INotificador _notificador;
    private readonly IValidator<CrearDevolucionProveedorRequest> _validator;
    private readonly IValidator<CobrarSaldoProveedorRequest> _cobroValidator;
    private readonly IValidator<AplicarSaldoProveedorRequest> _aplicarValidator;

    public DevolucionProveedorService(
        IComprasRepository repository,
        IComprasService compras,
        IInventarioService inventario,
        IFinanzasService finanzas,
        ICuentaFinancieraService cuentas,
        INotificador notificador,
        IValidator<CrearDevolucionProveedorRequest> validator,
        IValidator<CobrarSaldoProveedorRequest> cobroValidator,
        IValidator<AplicarSaldoProveedorRequest> aplicarValidator)
    {
        _repository = repository;
        _compras = compras;
        _inventario = inventario;
        _finanzas = finanzas;
        _cuentas = cuentas;
        _notificador = notificador;
        _validator = validator;
        _cobroValidator = cobroValidator;
        _aplicarValidator = aplicarValidator;
    }

    // ------------------------------------------------------------ Devoluciones

    public async Task<IEnumerable<DevolucionProveedorResponse>> GetAllAsync(int? compraId)
    {
        var devoluciones = await _repository.GetDevolucionesAsync(compraId);
        var porReponer = PorReponer(devoluciones);
        return devoluciones.Select(d => Map(d, porReponer));
    }

    public async Task<DevolucionProveedorResponse> GetAsync(int id) => await MapAsync(await BuscarAsync(id));

    public async Task<DevolucionProveedorResponse> CrearAsync(CrearDevolucionProveedorRequest request, int? usuarioId)
    {
        await _validator.ValidateAndThrowAsync(request);

        var compra = await _repository.GetCompraAsync(request.CompraId)
            ?? throw new NotFoundException($"No existe la compra {request.CompraId}");

        if (compra.Estado == EstadoCompra.Anulada)
        {
            throw new BadRequestException("Esta compra está anulada: no hay nada que devolver.");
        }

        // Una línea de la compra puede venir dos veces (una de lo recibido y otra de lo que no llegó), pero no dos
        // veces del mismo origen: sumarlas en silencio escondería un error de quien la arma.
        if (request.Detalle.GroupBy(l => (l.CompraDetalleId, l.Origen)).Any(g => g.Count() > 1))
        {
            throw new BadRequestException("Hay un producto repetido: indica su cantidad una sola vez.");
        }

        // Todo se valida ANTES de mover nada: la salida de stock se confirma sola (en su propia transacción).
        var lineas = new List<(CompraDetalle Detalle, LineaDevolucionProveedorRequest Linea)>();
        foreach (var linea in request.Detalle)
        {
            var detalle = compra.Detalle.FirstOrDefault(d => d.Id == linea.CompraDetalleId)
                ?? throw new BadRequestException($"La línea {linea.CompraDetalleId} no es de esta compra.");

            var unidad = detalle.Producto?.UnidadBase?.Codigo ?? string.Empty;
            var nombre = detalle.Producto?.Nombre ?? "El producto";

            if (linea.Origen == OrigenDevolucionProveedor.Recibido && linea.Cantidad > detalle.CantidadRecibida)
            {
                throw new BadRequestException(
                    $"'{nombre}': llegaron {detalle.CantidadRecibida:0.####} {unidad}, no se puede devolver más que eso.");
            }

            var pendiente = detalle.Cantidad - detalle.CantidadRecibida;
            if (linea.Origen == OrigenDevolucionProveedor.Pendiente && linea.Cantidad > pendiente)
            {
                throw new BadRequestException(
                    $"'{nombre}': faltan llegar {Math.Max(0, pendiente):0.####} {unidad}, no se puede devolver más que eso.");
            }

            lineas.Add((detalle, linea));
        }

        var recibidas = lineas
            .Where(l => l.Linea.Origen == OrigenDevolucionProveedor.Recibido)
            .Select(l => (l.Detalle, l.Linea.Cantidad))
            .ToList();

        var hayReposicion = lineas.Any(l => l.Linea.Resolucion == ResolucionDevolucionProveedor.Reposicion);

        var descuento = Math.Round(lineas
            .Where(l => l.Linea.Resolucion == ResolucionDevolucionProveedor.Descuento)
            .Sum(l => l.Linea.Cantidad * l.Detalle.CostoUnitario), 2);

        // Lo descontado baja primero lo que se debe; lo que pase de eso ya estaba pagado y queda a favor.
        var total = Math.Round(compra.Detalle.Sum(d => d.Cantidad * d.CostoUnitario), 2);
        var pagado = Math.Round(compra.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto), 2);
        var deuda = Math.Max(0m, total - pagado);
        var saldoFavor = Math.Max(0m, Math.Round(descuento - deuda, 2));

        var numero = await _repository.SiguienteNumeroDevolucionAsync();
        var fecha = DateTime.UtcNow;

        DocumentoInventario? documento = null;
        if (recibidas.Count > 0)
        {
            documento = await _inventario.CrearDevolucionProveedorAsync(
                numero, compra, request.AlmacenId!.Value, recibidas, fecha, usuarioId);
        }

        var devolucion = new DevolucionProveedor
        {
            Numero = numero,
            CompraId = compra.Id,
            ProveedorId = compra.ProveedorId,
            Fecha = fecha,
            Estado = EstadoDevolucionProveedor.Confirmada,
            Motivo = request.Motivo.Trim(),
            Observacion = Limpiar(request.Observacion),
            AlmacenId = recibidas.Count > 0 ? request.AlmacenId : null,
            DocumentoInventarioId = documento?.Id,
            FechaReposicion = hayReposicion ? request.FechaReposicion : null,
            SerieNotaCredito = Limpiar(request.SerieNotaCredito),
            NumeroNotaCredito = Limpiar(request.NumeroNotaCredito),
            MontoDescuento = descuento,
            SaldoFavorGenerado = saldoFavor,
            UsuarioId = usuarioId,
        };

        foreach (var (detalle, linea) in lineas)
        {
            var presentacionDescontada = 0m;

            // Lo que había llegado y se devuelve deja de contar como recibido: si se repone, vuelve a quedar por
            // recibir; si se descuenta, la línea también baja y no queda nada pendiente por eso.
            if (linea.Origen == OrigenDevolucionProveedor.Recibido)
            {
                detalle.CantidadRecibida -= linea.Cantidad;
            }

            if (linea.Resolucion == ResolucionDevolucionProveedor.Descuento)
            {
                // La presentación baja en la misma proporción: "10 Saco" con 2 descontados pasa a "8 Saco".
                var factor = detalle.CantidadPresentacion > 0 ? detalle.Cantidad / detalle.CantidadPresentacion : 1m;
                presentacionDescontada = factor > 0
                    ? Math.Min(detalle.CantidadPresentacion, Math.Round(linea.Cantidad / factor, 4))
                    : 0m;

                detalle.Cantidad -= linea.Cantidad;
                detalle.CantidadPresentacion -= presentacionDescontada;
            }

            devolucion.Detalle.Add(new DevolucionProveedorDetalle
            {
                CompraDetalleId = detalle.Id,
                ProductoId = detalle.ProductoId,
                Cantidad = linea.Cantidad,
                CostoUnitario = detalle.CostoUnitario,
                Origen = linea.Origen,
                Resolucion = linea.Resolucion,
                CantidadPresentacionDescontada = presentacionDescontada,
            });
        }

        compra.Estado = EstadoCompra.SegunLoRecibido(compra.Detalle);

        // Guarda la devolución y, con ella, los cambios en las líneas de la compra (el mismo contexto las sigue).
        await _repository.AddDevolucionAsync(devolucion);

        if (saldoFavor > 0)
        {
            await _repository.AddMovimientoSaldoAsync(new MovimientoSaldoProveedor
            {
                ProveedorId = compra.ProveedorId,
                Tipo = TipoMovimientoSaldoProveedor.Generado,
                Monto = saldoFavor,
                Fecha = fecha,
                DevolucionProveedorId = devolucion.Id,
                UsuarioId = usuarioId,
            });
            await _notificador.AvisarAsync("saldosproveedor", "cambio", new { proveedorId = compra.ProveedorId });
        }

        var creada = await MapAsync(await BuscarAsync(devolucion.Id));
        await _notificador.AvisarAsync("devolucionesproveedor", "creada", creada);
        await _notificador.AvisarAsync("compras", "actualizado", new { compraId = compra.Id });
        return creada;
    }

    public async Task<DevolucionProveedorResponse> AnularAsync(int id, int? usuarioId)
    {
        var devolucion = await BuscarAsync(id);

        if (devolucion.Estado == EstadoDevolucionProveedor.Anulada)
        {
            throw new BadRequestException("Esta devolución ya está anulada.");
        }

        var compra = await _repository.GetCompraAsync(devolucion.CompraId)
            ?? throw new NotFoundException($"No existe la compra {devolucion.CompraId}");

        // El saldo a favor que dio tiene que seguir ahí entero: si ya se cobró o se usó, retirarlo dejaría el saldo
        // del proveedor en negativo.
        if (devolucion.SaldoFavorGenerado > 0
            && await _repository.SaldoFavorAsync(devolucion.ProveedorId) < devolucion.SaldoFavorGenerado - 0.005m)
        {
            throw new BadRequestException(
                "Ya se cobró o se usó parte del saldo a favor que dio esta devolución: anula primero ese cobro o ese pago.");
        }

        // Si lo repuesto ya llegó, volver a contar lo devuelto como recibido daría más de lo comprado.
        foreach (var linea in devolucion.Detalle.Where(l =>
                     l.Origen == OrigenDevolucionProveedor.Recibido
                     && l.Resolucion == ResolucionDevolucionProveedor.Reposicion))
        {
            var detalle = compra.Detalle.First(d => d.Id == linea.CompraDetalleId);
            if (detalle.CantidadRecibida + linea.Cantidad > detalle.Cantidad + 0.0001m)
            {
                throw new BadRequestException(
                    $"Ya se recibió la reposición de '{linea.Producto?.Nombre}': no se puede anular la devolución.");
            }
        }

        // El stock vuelve a las mismas capas de las que salió (se confirma en su propia transacción).
        if (devolucion.DocumentoInventarioId is int documentoId)
        {
            await _inventario.AnularAsync(documentoId, usuarioId);
        }

        foreach (var linea in devolucion.Detalle)
        {
            var detalle = compra.Detalle.First(d => d.Id == linea.CompraDetalleId);

            if (linea.Resolucion == ResolucionDevolucionProveedor.Descuento)
            {
                detalle.Cantidad += linea.Cantidad;
                detalle.CantidadPresentacion += linea.CantidadPresentacionDescontada;
            }

            if (linea.Origen == OrigenDevolucionProveedor.Recibido)
            {
                detalle.CantidadRecibida += linea.Cantidad;
            }
        }

        compra.Estado = EstadoCompra.SegunLoRecibido(compra.Detalle);
        devolucion.Estado = EstadoDevolucionProveedor.Anulada;

        if (await _repository.GetMovimientoSaldoDeDevolucionAsync(devolucion.Id) is { } generado)
        {
            generado.Anulado = true;
        }

        await _repository.GuardarAsync();

        var anulada = await MapAsync(await BuscarAsync(devolucion.Id));
        await _notificador.AvisarAsync("devolucionesproveedor", "anulada", anulada);
        await _notificador.AvisarAsync("compras", "actualizado", new { compraId = compra.Id });
        if (devolucion.SaldoFavorGenerado > 0)
        {
            await _notificador.AvisarAsync("saldosproveedor", "cambio", new { proveedorId = devolucion.ProveedorId });
        }
        return anulada;
    }

    // ------------------------------------------------------------ Saldo a favor

    public async Task<IEnumerable<SaldoFavorProveedorResponse>> GetSaldosAsync() =>
        await _repository.SaldosFavorAsync();

    public Task<decimal> GetSaldoAsync(int proveedorId) => _repository.SaldoFavorAsync(proveedorId);

    public async Task<IEnumerable<MovimientoSaldoProveedorResponse>> GetMovimientosSaldoAsync(int proveedorId) =>
        (await _repository.GetMovimientosSaldoAsync(proveedorId)).Select(MapMovimiento);

    public async Task<MovimientoSaldoProveedorResponse> CobrarSaldoAsync(
        int proveedorId, CobrarSaldoProveedorRequest request, int? usuarioId)
    {
        await _cobroValidator.ValidateAndThrowAsync(request);

        var saldo = await _repository.SaldoFavorAsync(proveedorId);
        if (saldo <= 0)
        {
            throw new BadRequestException("Este proveedor no tiene saldo a favor.");
        }

        if (request.Monto > saldo)
        {
            throw new BadRequestException(
                $"El proveedor debe S/ {saldo:0.00}: no se puede registrar que devolvió más que eso.");
        }

        // A dónde entra la plata: el efectivo, a la caja de quien lo recibe (o a la Bóveda); lo demás, a la cuenta
        // del método. Igual que un pago a proveedor, pero al revés.
        var metodo = await _finanzas.GetMetodoPagoAsync(request.MetodoPagoId);
        int cuentaId;
        if (metodo.Tipo == TipoMetodoPago.Efectivo && request.DesdeBoveda)
        {
            cuentaId = (await _cuentas.ExigirBovedaAsync()).Id;
        }
        else if (metodo.Tipo == TipoMetodoPago.Efectivo)
        {
            if (usuarioId is not int id || await _cuentas.ObtenerCajaUsuarioAsync(id) is not { } caja)
            {
                throw new BadRequestException(
                    "No tienes una caja asignada: no puedes recibir efectivo. Elige la Bóveda u otro método.");
            }
            cuentaId = caja.Id;
        }
        else
        {
            cuentaId = metodo.CuentaFinancieraId
                ?? throw new BadRequestException(
                    $"El método {metodo.Nombre} no tiene una cuenta asignada: elígela en Finanzas > Métodos de pago.");
        }

        var cobro = new MovimientoSaldoProveedor
        {
            ProveedorId = proveedorId,
            Tipo = TipoMovimientoSaldoProveedor.Cobrado,
            Monto = Math.Round(request.Monto, 2),
            Fecha = DateTime.UtcNow,
            MetodoPagoId = metodo.Id,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId,
        };
        await _repository.AddMovimientoSaldoAsync(cobro);

        var ingreso = await _cuentas.PostearAsync(
            cuentaId, TipoMovimientoCuenta.Ingreso, cobro.Monto,
            DocumentoOrigenMovimiento.CobroProveedor, cobro.Id, usuarioId, cobro.Fecha,
            "Saldo a favor devuelto por un proveedor");
        cobro.MovimientoCuentaId = ingreso.Id;
        await _repository.GuardarAsync();

        await _notificador.AvisarAsync("saldosproveedor", "cambio", new { proveedorId });

        var movimientos = await _repository.GetMovimientosSaldoAsync(proveedorId);
        return MapMovimiento(movimientos.First(m => m.Id == cobro.Id));
    }

    public async Task AnularCobroAsync(int movimientoId, int? usuarioId)
    {
        var cobro = await _repository.GetMovimientoSaldoAsync(movimientoId)
            ?? throw new NotFoundException($"No existe el movimiento {movimientoId}");

        if (cobro.Tipo != TipoMovimientoSaldoProveedor.Cobrado)
        {
            throw new BadRequestException(
                "Solo se anula aquí un cobro. Lo generado se anula con su devolución; lo usado, anulando ese pago.");
        }

        if (cobro.Anulado)
        {
            throw new BadRequestException("Este cobro ya está anulado.");
        }

        // La plata que entró sale de la cuenta, y el monto vuelve al saldo a favor.
        if (cobro.MovimientoCuentaId is int ingresoId)
        {
            await _cuentas.ReversarAsync(ingresoId, usuarioId);
            cobro.MovimientoCuentaId = null;
        }

        cobro.Anulado = true;
        await _repository.GuardarAsync();

        await _notificador.AvisarAsync("saldosproveedor", "cambio", new { proveedorId = cobro.ProveedorId });
    }

    public async Task<CompraResponse> AplicarSaldoAsync(
        int compraId, AplicarSaldoProveedorRequest request, int? usuarioId)
    {
        await _aplicarValidator.ValidateAndThrowAsync(request);

        var compra = await _repository.GetCompraAsync(compraId)
            ?? throw new NotFoundException($"No existe la compra {compraId}");

        if (compra.Estado == EstadoCompra.Anulada)
        {
            throw new BadRequestException("Esta compra está anulada: no se le pueden registrar pagos.");
        }

        var total = Math.Round(compra.Detalle.Sum(d => d.Cantidad * d.CostoUnitario), 2);
        var pagado = Math.Round(compra.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto), 2);
        var deuda = total - pagado;
        if (deuda <= 0)
        {
            throw new BadRequestException("Esta compra ya está pagada por completo.");
        }

        var monto = Math.Round(request.Monto, 2);
        if (monto > deuda)
        {
            throw new BadRequestException($"A esta compra le faltan S/ {deuda:0.00}: no se puede aplicar más que eso.");
        }

        var saldo = await _repository.SaldoFavorAsync(compra.ProveedorId);
        if (monto > saldo)
        {
            throw new BadRequestException($"El saldo a favor con este proveedor es de S/ {saldo:0.00}.");
        }

        var pago = new CompraPago
        {
            MetodoPagoId = null,
            SaldoFavor = true,
            Monto = monto,
            UsuarioId = usuarioId,
        };
        compra.Pagos.Add(pago);
        await _repository.UpdateCompraAsync(compra);

        await _repository.AddMovimientoSaldoAsync(new MovimientoSaldoProveedor
        {
            ProveedorId = compra.ProveedorId,
            Tipo = TipoMovimientoSaldoProveedor.Aplicado,
            Monto = monto,
            Fecha = pago.Fecha,
            CompraPagoId = pago.Id,
            UsuarioId = usuarioId,
        });

        var actualizada = await _compras.GetCompraAsync(compraId);
        await _notificador.AvisarAsync("compras", "pago", actualizada);
        await _notificador.AvisarAsync("saldosproveedor", "cambio", new { proveedorId = compra.ProveedorId });
        return actualizada;
    }

    // ------------------------------------------------------------- Auxiliares

    private async Task<DevolucionProveedor> BuscarAsync(int id) =>
        await _repository.GetDevolucionAsync(id)
        ?? throw new NotFoundException($"No existe la devolución {id}");

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    /// <summary>Una devolución con lo que le falta reponer, que depende de las demás devoluciones de su compra.</summary>
    private async Task<DevolucionProveedorResponse> MapAsync(DevolucionProveedor d) =>
        Map(d, PorReponer(await _repository.GetDevolucionesAsync(d.CompraId)));

    /// <summary>
    /// Por línea de devolución (su Id), cuánto de lo que se mandó a reponer todavía no llega.
    ///
    /// Lo repuesto llega con una recepción normal de la compra, así que no se sabe a qué devolución corresponde: se
    /// mira cuánto le falta recibir a la línea de la compra y, si hay varias reposiciones de esa línea, lo que llegó se
    /// cuenta primero contra la más antigua (lo que falta es de las más nuevas). Si la línea todavía espera mercadería
    /// de la compra original, eso también cuenta como pendiente: no hay forma de separarlo.
    /// </summary>
    private static Dictionary<int, decimal> PorReponer(IEnumerable<DevolucionProveedor> devoluciones)
    {
        var resultado = new Dictionary<int, decimal>();
        var porLinea = devoluciones
            .Where(d => d.Estado != EstadoDevolucionProveedor.Anulada)
            .SelectMany(d => d.Detalle
                .Where(l => l.Resolucion == ResolucionDevolucionProveedor.Reposicion)
                .Select(l => (Devolucion: d, Linea: l)))
            .GroupBy(x => x.Linea.CompraDetalleId);

        foreach (var grupo in porLinea)
        {
            var detalle = grupo.First().Linea.CompraDetalle;
            var falta = detalle is null ? 0m : Math.Max(0m, detalle.Cantidad - detalle.CantidadRecibida);

            foreach (var (_, linea) in grupo.OrderByDescending(x => x.Devolucion.Fecha).ThenByDescending(x => x.Devolucion.Id))
            {
                var queda = Math.Min(linea.Cantidad, falta);
                resultado[linea.Id] = queda;
                falta -= queda;
            }
        }

        return resultado;
    }

    private static DevolucionProveedorResponse Map(DevolucionProveedor d, IReadOnlyDictionary<int, decimal> porReponer) => new()
    {
        Id = d.Id,
        Numero = d.Numero,
        CompraId = d.CompraId,
        CompraNumero = d.Compra?.Numero ?? string.Empty,
        ProveedorId = d.ProveedorId,
        Proveedor = d.Proveedor?.Nombre ?? string.Empty,
        Fecha = d.Fecha,
        Estado = d.Estado,
        Motivo = d.Motivo,
        Observacion = d.Observacion,
        AlmacenId = d.AlmacenId,
        Almacen = d.Almacen?.Nombre,
        DocumentoInventario = d.DocumentoInventario?.Numero,
        FechaReposicion = d.FechaReposicion,
        SerieNotaCredito = d.SerieNotaCredito,
        NumeroNotaCredito = d.NumeroNotaCredito,
        MontoDescuento = d.MontoDescuento,
        SaldoFavorGenerado = d.SaldoFavorGenerado,
        MontoReposicion = Math.Round(d.Detalle
            .Where(l => l.Resolucion == ResolucionDevolucionProveedor.Reposicion)
            .Sum(l => l.Cantidad * l.CostoUnitario), 2),
        // Anulada, ya no se espera nada de ella.
        MontoPorReponer = d.Estado == EstadoDevolucionProveedor.Anulada
            ? 0
            : Math.Round(d.Detalle.Sum(l => porReponer.GetValueOrDefault(l.Id) * l.CostoUnitario), 2),
        Usuario = d.Usuario?.Nombre,
        Detalle = d.Detalle.Select(l => new DevolucionProveedorLineaResponse
        {
            Id = l.Id,
            CompraDetalleId = l.CompraDetalleId,
            ProductoId = l.ProductoId,
            Codigo = l.Producto?.Codigo ?? string.Empty,
            Producto = l.Producto?.Nombre ?? string.Empty,
            UnidadBase = l.Producto?.UnidadBase?.Codigo ?? string.Empty,
            Presentacion = l.CompraDetalle?.Presentacion?.Nombre,
            Cantidad = l.Cantidad,
            CostoUnitario = l.CostoUnitario,
            Importe = Math.Round(l.Cantidad * l.CostoUnitario, 2),
            Origen = l.Origen,
            Resolucion = l.Resolucion,
            CantidadPorReponer = d.Estado == EstadoDevolucionProveedor.Anulada ? 0 : porReponer.GetValueOrDefault(l.Id),
        }).ToList(),
    };

    private static MovimientoSaldoProveedorResponse MapMovimiento(MovimientoSaldoProveedor m) => new()
    {
        Id = m.Id,
        Tipo = m.Tipo,
        Monto = m.Monto,
        Fecha = m.Fecha,
        Documento = m.DevolucionProveedor?.Numero ?? m.CompraPago?.Compra?.Numero,
        MetodoPago = m.MetodoPago?.Nombre,
        Anulado = m.Anulado,
        Observacion = m.Observacion,
        Usuario = m.Usuario?.Nombre,
    };
}
