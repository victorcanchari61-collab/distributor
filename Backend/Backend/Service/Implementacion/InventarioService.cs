using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Stock y costos.
///
/// El costo no vive en el producto sino en capas: cada entrada guarda SU costo
/// y cuanto le queda. Las salidas consumen primero la capa mas antigua (PEPS),
/// que es como sale la mercaderia del almacen, y devuelven cuanto costo lo que
/// salio. Asi la ganancia es exacta aunque convivan tres precios de compra del
/// mismo producto.
///
/// Reglas:
///
///   - El costo se guarda SIEMPRE por unidad base. Entra un saco de 50 kg a
///     170 y se guarda 3.40 el kilo.
///   - El flete se suma al costo antes de dividir: es plata que costo traer
///     esa mercaderia.
///   - No se puede sacar mas de lo que hay: el stock no queda negativo.
///   - Sin almacen indicado, todo va al principal.
/// </summary>
public class InventarioService : IInventarioService
{
    private readonly IInventarioRepository _repository;
    private readonly IProductoRepository _productos;
    private readonly IValidator<CreateAlmacenRequest> _createAlmacen;
    private readonly IValidator<UpdateAlmacenRequest> _updateAlmacen;
    private readonly IValidator<EntradaRequest> _entradaValidator;
    private readonly IValidator<SalidaRequest> _salidaValidator;

    public InventarioService(
        IInventarioRepository repository,
        IProductoRepository productos,
        IValidator<CreateAlmacenRequest> createAlmacen,
        IValidator<UpdateAlmacenRequest> updateAlmacen,
        IValidator<EntradaRequest> entradaValidator,
        IValidator<SalidaRequest> salidaValidator)
    {
        _repository = repository;
        _productos = productos;
        _createAlmacen = createAlmacen;
        _updateAlmacen = updateAlmacen;
        _entradaValidator = entradaValidator;
        _salidaValidator = salidaValidator;
    }

    // ------------------------------------------------------------- Almacenes

    public async Task<IEnumerable<AlmacenResponse>> GetAlmacenesAsync()
    {
        var almacenes = await _repository.GetAlmacenesAsync();
        return almacenes.Select(MapAlmacen);
    }

    public async Task<AlmacenResponse> GetAlmacenAsync(int id) =>
        MapAlmacen(await GetAlmacenOrThrowAsync(id));

    public async Task<AlmacenResponse> CreateAlmacenAsync(CreateAlmacenRequest request)
    {
        await _createAlmacen.ValidateAndThrowAsync(request);

        var codigo = request.Codigo.Trim().ToUpperInvariant();
        if (await _repository.ExisteCodigoAlmacenAsync(codigo))
        {
            throw new ConflictException("Ya existe un almacén con ese código");
        }

        var almacen = new Almacen
        {
            Codigo = codigo,
            Nombre = request.Nombre.Trim(),
            Direccion = Limpiar(request.Direccion),
            EsPrincipal = false,
            Activo = true
        };

        await _repository.AddAlmacenAsync(almacen);
        return MapAlmacen(almacen);
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

        // Sin principal activo, una entrada sin almacen no sabria donde ir.
        if (almacen.EsPrincipal && !request.Activo)
        {
            throw new BadRequestException("El almacén principal no se puede desactivar");
        }

        almacen.Codigo = codigo;
        almacen.Nombre = request.Nombre.Trim();
        almacen.Direccion = Limpiar(request.Direccion);
        almacen.Activo = request.Activo;

        await _repository.UpdateAlmacenAsync(almacen);
        return MapAlmacen(almacen);
    }

    public async Task DeleteAlmacenAsync(int id)
    {
        var almacen = await GetAlmacenOrThrowAsync(id);

        if (almacen.EsPrincipal)
        {
            throw new BadRequestException("El almacén principal no se elimina");
        }

        var capas = await _repository.ContarCapasAlmacenAsync(id);
        if (capas > 0)
        {
            throw new BadRequestException(
                "El almacén tiene movimientos registrados. Desactívalo en vez de eliminarlo.");
        }

        await _repository.DeleteAlmacenAsync(almacen);
    }

    // -------------------------------------------------------- Stock y costos

    public async Task<StockProductoResponse> GetStockAsync(int productoId, int? almacenId = null)
    {
        var producto = await _productos.GetConDetalleAsync(productoId)
            ?? throw new NotFoundException($"No existe el producto {productoId}");

        var disponibles = await _repository.GetCapasDisponiblesAsync(productoId, almacenId);
        var ultima = await _repository.GetUltimaCapaAsync(productoId, almacenId);

        return new StockProductoResponse
        {
            ProductoId = producto.Id,
            Producto = producto.Nombre,
            UnidadBase = producto.UnidadBase?.Codigo ?? string.Empty,
            Stock = disponibles.Sum(c => c.CantidadDisponible),
            // La mas antigua con mercaderia: es la que se va a consumir ahora.
            CostoAntiguo = disponibles.FirstOrDefault()?.CostoUnitario,
            CostoUltimo = ultima?.CostoUnitario,
            Valorizado = disponibles.Sum(c => c.CantidadDisponible * c.CostoUnitario),
            Capas = disponibles.Select(MapCapa).ToList()
        };
    }

    public async Task<CapaCostoResponse> RegistrarEntradaAsync(EntradaRequest request)
    {
        await _entradaValidator.ValidateAndThrowAsync(request);

        var producto = await _productos.GetConDetalleAsync(request.ProductoId)
            ?? throw new BadRequestException("El producto indicado no existe");

        var almacen = await ResolverAlmacenAsync(request.AlmacenId);
        var factor = await ResolverFactorAsync(request.PresentacionId, request.ProductoId);

        // La cantidad viene en presentaciones: 2 sacos de 50 son 100 kilos.
        var enUnidadBase = request.Cantidad * factor;

        // El costo llega por presentacion completa; el flete es de toda la
        // entrada. Los dos se reparten entre las unidades base que entraron.
        var costoTotal = request.CostoTotal * request.Cantidad + request.Flete;
        var costoUnitario = enUnidadBase == 0 ? 0 : Math.Round(costoTotal / enUnidadBase, 4);

        var capa = new CapaCosto
        {
            ProductoId = producto.Id,
            AlmacenId = almacen.Id,
            CantidadInicial = enUnidadBase,
            CantidadDisponible = enUnidadBase,
            CostoUnitario = costoUnitario,
            Origen = request.Origen,
            Referencia = Limpiar(request.Referencia),
            Fecha = request.Fecha ?? DateTime.UtcNow
        };

        await _repository.AddCapaAsync(capa);
        capa.Almacen = almacen;

        return MapCapa(capa);
    }

    public async Task<CostoSalidaResponse> RegistrarSalidaAsync(SalidaRequest request) =>
        await ProcesarSalidaAsync(request, aplicar: true);

    public async Task<CostoSalidaResponse> SimularSalidaAsync(SalidaRequest request) =>
        await ProcesarSalidaAsync(request, aplicar: false);

    /// <summary>
    /// Recorre las capas de la mas antigua a la mas nueva tomando de cada una
    /// lo que alcance, hasta cubrir la cantidad pedida.
    ///
    /// Vender 60 kg con capas de 50 a 3.40 y 50 a 3.60 toma los 50 primeros y
    /// 10 de la segunda: 50x3.40 + 10x3.60 = 206.
    /// </summary>
    private async Task<CostoSalidaResponse> ProcesarSalidaAsync(SalidaRequest request, bool aplicar)
    {
        await _salidaValidator.ValidateAndThrowAsync(request);

        var producto = await _productos.GetConDetalleAsync(request.ProductoId)
            ?? throw new BadRequestException("El producto indicado no existe");

        var almacen = await ResolverAlmacenAsync(request.AlmacenId);
        var factor = await ResolverFactorAsync(request.PresentacionId, request.ProductoId);
        var pedido = request.Cantidad * factor;

        var capas = await _repository.GetCapasDisponiblesAsync(producto.Id, almacen.Id);
        var disponible = capas.Sum(c => c.CantidadDisponible);

        if (disponible < pedido)
        {
            var unidad = producto.UnidadBase?.Codigo ?? "unidades";
            throw new BadRequestException(
                $"No hay stock suficiente: se pidieron {pedido} {unidad} y quedan {disponible}.");
        }

        var consumos = new List<ConsumoCapaResponse>();
        var restante = pedido;

        foreach (var capa in capas)
        {
            if (restante <= 0) break;

            var tomado = Math.Min(capa.CantidadDisponible, restante);
            restante -= tomado;

            if (aplicar)
            {
                capa.CantidadDisponible -= tomado;
            }

            consumos.Add(new ConsumoCapaResponse
            {
                CapaId = capa.Id,
                Cantidad = tomado,
                CostoUnitario = capa.CostoUnitario,
                Subtotal = Math.Round(tomado * capa.CostoUnitario, 4),
                Fecha = capa.Fecha
            });
        }

        if (aplicar)
        {
            await _repository.GuardarCambiosAsync();
        }

        var costo = consumos.Sum(c => c.Subtotal);

        return new CostoSalidaResponse
        {
            ProductoId = producto.Id,
            Cantidad = pedido,
            Costo = costo,
            CostoUnitarioPromedio = pedido == 0 ? 0 : Math.Round(costo / pedido, 4),
            Consumos = consumos
        };
    }

    // ------------------------------------------------------------ Auxiliares

    private async Task<Almacen> GetAlmacenOrThrowAsync(int id) =>
        await _repository.GetAlmacenAsync(id)
        ?? throw new NotFoundException($"No existe el almacén {id}");

    private async Task<Almacen> ResolverAlmacenAsync(int? almacenId)
    {
        if (almacenId is int id)
        {
            var almacen = await GetAlmacenOrThrowAsync(id);
            if (!almacen.Activo)
            {
                throw new BadRequestException("El almacén indicado está desactivado");
            }
            return almacen;
        }

        return await _repository.GetAlmacenPrincipalAsync()
            ?? throw new BadRequestException("No hay ningún almacén activo");
    }

    /// <summary>
    /// Cuantas unidades base mueve una presentacion. Sin presentacion, la
    /// cantidad ya viene en unidad base y el factor es 1.
    /// </summary>
    private async Task<decimal> ResolverFactorAsync(int? presentacionId, int productoId)
    {
        if (presentacionId is not int id) return 1m;

        var presentacion = await _productos.GetPresentacionAsync(id)
            ?? throw new BadRequestException("La presentación indicada no existe");

        if (presentacion.ProductoId != productoId)
        {
            throw new BadRequestException("La presentación no pertenece a ese producto");
        }

        return presentacion.Factor;
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static AlmacenResponse MapAlmacen(Almacen a) => new()
    {
        Id = a.Id,
        Codigo = a.Codigo,
        Nombre = a.Nombre,
        Direccion = a.Direccion,
        EsPrincipal = a.EsPrincipal,
        Activo = a.Activo
    };

    private static CapaCostoResponse MapCapa(CapaCosto c) => new()
    {
        Id = c.Id,
        ProductoId = c.ProductoId,
        AlmacenId = c.AlmacenId,
        Almacen = c.Almacen?.Nombre ?? string.Empty,
        CantidadInicial = c.CantidadInicial,
        CantidadDisponible = c.CantidadDisponible,
        CostoUnitario = c.CostoUnitario,
        Valor = Math.Round(c.CantidadDisponible * c.CostoUnitario, 4),
        Origen = c.Origen,
        Referencia = c.Referencia,
        Fecha = c.Fecha
    };
}
