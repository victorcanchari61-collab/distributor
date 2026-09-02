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

    public InventarioService(
        IInventarioRepository repository,
        IProductoRepository productos,
        IValidator<CreateAlmacenRequest> createAlmacen,
        IValidator<UpdateAlmacenRequest> updateAlmacen,
        IValidator<CreateMotivoRequest> createMotivo,
        IValidator<UpdateMotivoRequest> updateMotivo,
        IValidator<CrearAjusteRequest> ajusteValidator)
    {
        _repository = repository;
        _productos = productos;
        _createAlmacen = createAlmacen;
        _updateAlmacen = updateAlmacen;
        _createMotivo = createMotivo;
        _updateMotivo = updateMotivo;
        _ajusteValidator = ajusteValidator;
    }

    // ------------------------------------------------------------- Almacenes

    public async Task<IEnumerable<AlmacenResponse>> GetAlmacenesAsync()
    {
        var almacenes = (await _repository.GetAlmacenesAsync()).ToList();
        var respuesta = new List<AlmacenResponse>();

        foreach (var almacen in almacenes)
        {
            var capas = await _repository.GetCapasDisponiblesAsync(0, almacen.Id);
            respuesta.Add(MapAlmacen(almacen, capas));
        }

        return respuesta;
    }

    public async Task<AlmacenResponse> GetAlmacenAsync(int id)
    {
        var almacen = await GetAlmacenOrThrowAsync(id);
        return MapAlmacen(almacen, await _repository.GetCapasDisponiblesAsync(0, id));
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
            EsPrincipal = esPrimero,
            Activo = true
        };

        await _repository.AddAlmacenAsync(almacen);
        return MapAlmacen(almacen, []);
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

        if (almacen.EsPrincipal && !request.Activo)
        {
            throw new BadRequestException("El almacén principal no se puede desactivar");
        }

        almacen.Codigo = codigo;
        almacen.Nombre = request.Nombre.Trim();
        almacen.Direccion = Limpiar(request.Direccion);
        almacen.Activo = request.Activo;

        await _repository.UpdateAlmacenAsync(almacen);
        return MapAlmacen(almacen, await _repository.GetCapasDisponiblesAsync(0, id));
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
        return MapMotivo(motivo, 0);
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
        return MapMotivo(motivo, movimientos);
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
    }

    // ------------------------------------------------------------------ Stock

    public async Task<IEnumerable<StockResponse>> GetStockAsync(int? almacenId)
    {
        var productos = (await _productos.GetAllConDetalleAsync())
            .Where(p => p.ControlaStock)
            .ToList();

        var resumen = await _repository.GetResumenAsync(productos.Select(p => p.Id), almacenId);
        var almacen = almacenId is int id ? await _repository.GetAlmacenAsync(id) : null;

        return productos.Select(p =>
        {
            var r = resumen.GetValueOrDefault(p.Id);
            return new StockResponse
            {
                ProductoId = p.Id,
                Codigo = p.Codigo,
                Producto = p.Nombre,
                Categoria = p.Categoria?.Nombre,
                Marca = p.Marca?.Nombre,
                UnidadBase = p.UnidadBase?.Codigo ?? string.Empty,
                AlmacenId = almacenId ?? 0,
                Almacen = almacen?.Nombre ?? "Todos",
                Stock = r?.Stock ?? 0,
                StockMinimo = p.StockMinimo,
                BajoMinimo = p.StockMinimo > 0 && (r?.Stock ?? 0) <= p.StockMinimo,
                CostoActual = r?.CostoMin,
                CostoUltimo = r?.CostoMax,
                Valorizado = r?.Valorizado ?? 0
            };
        });
    }

    public async Task<StockResponse> GetStockProductoAsync(int productoId, int? almacenId)
    {
        var producto = await _productos.GetConDetalleAsync(productoId)
            ?? throw new NotFoundException($"No existe el producto {productoId}");

        var capas = await _repository.GetCapasDisponiblesAsync(productoId, almacenId);
        var ultima = await _repository.GetUltimaCapaAsync(productoId, almacenId);
        var almacen = almacenId is int id ? await _repository.GetAlmacenAsync(id) : null;

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
            Stock = capas.Sum(c => c.CantidadDisponible),
            StockMinimo = producto.StockMinimo,
            BajoMinimo = producto.StockMinimo > 0
                         && capas.Sum(c => c.CantidadDisponible) <= producto.StockMinimo,
            // La mas antigua con mercaderia: es la que se consume ahora.
            CostoActual = capas.FirstOrDefault()?.CostoUnitario,
            CostoUltimo = ultima?.CostoUnitario,
            Valorizado = capas.Sum(c => c.CantidadDisponible * c.CostoUnitario),
            Capas = capas.Select(MapCapa).ToList()
        };
    }

    // ----------------------------------------------------------------- Kardex

    public async Task<IEnumerable<KardexResponse>> GetKardexAsync(
        int? productoId, int? almacenId, DateTime? desde, DateTime? hasta)
    {
        var movimientos = await _repository.GetKardexAsync(productoId, almacenId, desde, hasta);

        // El saldo se acumula por producto y almacen: mezclar dos productos en
        // una sola columna daria un numero sin sentido.
        var saldos = new Dictionary<(int, int), decimal>();
        var respuesta = new List<KardexResponse>();

        foreach (var m in movimientos)
        {
            var clave = (m.ProductoId, m.AlmacenId);
            var saldo = saldos.GetValueOrDefault(clave);
            saldo += m.Tipo == TipoMovimiento.Entrada ? m.Cantidad : -m.Cantidad;
            saldos[clave] = saldo;

            respuesta.Add(new KardexResponse
            {
                Id = m.Id,
                Fecha = m.Fecha,
                Documento = m.Documento?.Numero ?? string.Empty,
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
                Saldo = saldo,
                Anulado = m.Documento?.Estado == EstadoDocumento.Anulado
            });
        }

        // Se devuelve del mas nuevo al mas viejo, que es como se lee, pero el
        // saldo ya viene calculado en el orden correcto.
        respuesta.Reverse();
        return respuesta;
    }

    // ---------------------------------------------------------------- Ajustes

    public async Task<IEnumerable<DocumentoInventarioResponse>> GetDocumentosAsync()
    {
        var documentos = (await _repository.GetDocumentosAsync()).ToList();
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

        return await GetDocumentoAsync(documento.Id);
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

        var eraEntrada = original.Motivo?.Tipo == TipoMovimiento.Entrada;

        await using var transaccion = await _repository.IniciarTransaccionAsync();

        var anulacion = new DocumentoInventario
        {
            Numero = await _repository.SiguienteNumeroAsync(TipoDocumentoInventario.Anulacion),
            Tipo = TipoDocumentoInventario.Anulacion,
            AlmacenId = original.AlmacenId,
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
            var espejo = new MovimientoInventario
            {
                DocumentoId = anulacion.Id,
                ProductoId = m.ProductoId,
                AlmacenId = m.AlmacenId,
                MotivoId = m.MotivoId,
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
                // Se retira la capa que creo. Si ya se vendio algo de ella, no
                // hay nada que retirar sin descuadrar el costo de esas ventas.
                var capa = await _repository.GetCapaDeMovimientoAsync(m.Id)
                    ?? throw new BadRequestException(
                        "No se encontró la mercadería de este documento.");

                if (capa.CantidadDisponible < capa.CantidadInicial)
                {
                    throw new BadRequestException(
                        "No se puede anular: ya se vendió o se usó parte de esta mercadería. "
                        + "Registra un ajuste de salida por la diferencia.");
                }

                capa.CantidadDisponible = 0;
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

            await _repository.GuardarAsync();
        }

        original.Estado = EstadoDocumento.Anulado;
        await _repository.UpdateDocumentoAsync(original);

        await transaccion.CommitAsync();

        return await GetDocumentoAsync(anulacion.Id);
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

    private static AlmacenResponse MapAlmacen(Almacen a, List<CapaCosto> capas) => new()
    {
        Id = a.Id,
        Codigo = a.Codigo,
        Nombre = a.Nombre,
        Direccion = a.Direccion,
        EsPrincipal = a.EsPrincipal,
        Activo = a.Activo,
        Productos = capas.Select(c => c.ProductoId).Distinct().Count(),
        Valorizado = Math.Round(capas.Sum(c => c.CantidadDisponible * c.CostoUnitario), 2)
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
                Cantidad = m.Cantidad,
                CostoUnitario = m.CostoUnitario,
                CostoTotal = m.CostoTotal
            }).ToList()
            : []
    };
}
