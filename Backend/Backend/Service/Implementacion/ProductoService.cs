using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Reglas de los productos:
///
///   - El codigo no se repite.
///   - Todo producto nace con una presentacion base de factor 1 en su unidad
///     base. Sin ella no habria forma de vender ni de convertir stock.
///   - La presentacion base no se elimina ni cambia de factor.
///   - La unidad base NO se cambia despues de crear: los factores existentes
///     dejarian de significar lo mismo y el stock guardado quedaria mal.
///   - Un factor siempre es mayor que cero.
///   - Solo una presentacion puede ser la predeterminada de venta, y una la de
///     compra.
///   - No se elimina una presentacion con precios cargados.
///   - Categoria, marca y unidades deben existir y estar activas al asignarse.
/// </summary>
public class ProductoService : IProductoService
{
    private readonly IProductoRepository _repository;
    private readonly ICatalogoRepository _catalogo;
    private readonly IInventarioRepository _inventario;
    private readonly IValidator<CreateProductoRequest> _createValidator;
    private readonly IValidator<UpdateProductoRequest> _updateValidator;
    private readonly IValidator<PresentacionRequest> _presentacionValidator;

    public ProductoService(
        IProductoRepository repository,
        ICatalogoRepository catalogo,
        IInventarioRepository inventario,
        IValidator<CreateProductoRequest> createValidator,
        IValidator<UpdateProductoRequest> updateValidator,
        IValidator<PresentacionRequest> presentacionValidator)
    {
        _repository = repository;
        _catalogo = catalogo;
        _inventario = inventario;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _presentacionValidator = presentacionValidator;
    }

    public async Task<IEnumerable<ProductoResponse>> GetAllAsync()
    {
        var productos = (await _repository.GetAllConDetalleAsync()).ToList();

        // Stock y costos en UNA consulta para toda la lista, en vez de una por
        // producto: son dos mil registros en el peor caso.
        var resumen = await _inventario.GetResumenAsync(productos.Select(p => p.Id));

        return productos.Select(p => MapToResponse(p, resumen.GetValueOrDefault(p.Id)));
    }

    public async Task<ProductoResponse> GetByIdAsync(int id)
    {
        var producto = await GetOrThrowAsync(id);
        var resumen = await _inventario.GetResumenAsync([id]);
        return MapToResponse(producto, resumen.GetValueOrDefault(id));
    }

    public async Task<ProductoResponse> CreateAsync(CreateProductoRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        var codigo = request.Codigo.Trim().ToUpperInvariant();
        if (await _repository.ExisteCodigoAsync(codigo))
        {
            throw new ConflictException("Ya existe un producto con ese código");
        }

        await ValidarReferenciasAsync(request);

        var unidadBase = await _catalogo.GetUnidadAsync(request.UnidadBaseId)
            ?? throw new BadRequestException("La unidad base indicada no existe");

        var producto = new Producto
        {
            Codigo = codigo,
            Nombre = request.Nombre.Trim(),
            Descripcion = Limpiar(request.Descripcion),
            CategoriaId = request.CategoriaId,
            MarcaId = request.MarcaId,
            UnidadBaseId = request.UnidadBaseId,
            Contenido = request.Contenido,
            ContenidoUnidadId = request.ContenidoUnidadId,
            ControlaStock = request.ControlaStock,
            StockMinimo = request.StockMinimo,
            Activo = true
        };

        // La presentacion base va primero y siempre: es la que da sentido a
        // los factores del resto.
        producto.Presentaciones.Add(new ProductoPresentacion
        {
            UnidadId = unidadBase.Id,
            Nombre = unidadBase.Nombre,
            Factor = 1m,
            EsCompra = true,
            EsVenta = true,
            PredeterminadaVenta = true,
            PredeterminadaCompra = true,
            Activo = true
        });

        foreach (var extra in request.Presentaciones)
        {
            await ValidarUnidadAsync(extra.UnidadId);

            // Una segunda presentacion de factor 1 seria un duplicado de la
            // base con otro nombre.
            if (extra.Factor == 1m)
            {
                throw new BadRequestException(
                    $"La presentación '{extra.Nombre}' tiene factor 1: esa ya es la presentación base ({unidadBase.Nombre}).");
            }

            producto.Presentaciones.Add(new ProductoPresentacion
            {
                UnidadId = extra.UnidadId,
                Nombre = extra.Nombre.Trim(),
                Factor = extra.Factor,
                EsCompra = extra.EsCompra,
                EsVenta = extra.EsVenta,
                CodigoBarras = Limpiar(extra.CodigoBarras),
                Activo = extra.Activo
            });
        }

        AjustarPredeterminadas(producto, request.Presentaciones);

        await _repository.AddAsync(producto);
        return MapToResponse(await GetOrThrowAsync(producto.Id));
    }

    public async Task<ProductoResponse> UpdateAsync(int id, UpdateProductoRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var producto = await GetOrThrowAsync(id);
        var codigo = request.Codigo.Trim().ToUpperInvariant();

        if (await _repository.ExisteCodigoAsync(codigo, id))
        {
            throw new ConflictException("Ya existe un producto con ese código");
        }

        // Cambiar la unidad base volveria mentira todo factor ya guardado: un
        // saco de 50 dejaria de ser 50 kilos.
        if (request.UnidadBaseId != producto.UnidadBaseId)
        {
            throw new BadRequestException(
                "La unidad base no se puede cambiar. Crea un producto nuevo si la medida es distinta.");
        }

        await ValidarReferenciasAsync(request);

        producto.Codigo = codigo;
        producto.Nombre = request.Nombre.Trim();
        producto.Descripcion = Limpiar(request.Descripcion);
        producto.CategoriaId = request.CategoriaId;
        producto.MarcaId = request.MarcaId;
        producto.Contenido = request.Contenido;
        producto.ContenidoUnidadId = request.ContenidoUnidadId;
        producto.ControlaStock = request.ControlaStock;
        producto.StockMinimo = request.StockMinimo;
        producto.Activo = request.Activo;

        await _repository.UpdateAsync(producto);
        return MapToResponse(await GetOrThrowAsync(id));
    }

    public async Task<ProductoResponse> CambiarEstadoAsync(int id, bool activo)
    {
        var producto = await GetOrThrowAsync(id);
        producto.Activo = activo;

        await _repository.UpdateAsync(producto);
        return MapToResponse(producto);
    }

    public async Task DeleteAsync(int id)
    {
        var producto = await GetOrThrowAsync(id);

        foreach (var presentacion in producto.Presentaciones)
        {
            if (await _repository.ContarPreciosAsync(presentacion.Id) > 0)
            {
                throw new BadRequestException(
                    "El producto tiene precios cargados. Desactívalo en vez de eliminarlo.");
            }
        }

        await _repository.DeleteAsync(producto);
    }

    // -------------------------------------------------------- Presentaciones

    public async Task<PresentacionResponse> AgregarPresentacionAsync(
        int productoId, PresentacionRequest request)
    {
        await _presentacionValidator.ValidateAndThrowAsync(request);

        var producto = await GetOrThrowAsync(productoId);
        await ValidarUnidadAsync(request.UnidadId);

        if (request.Factor == 1m)
        {
            throw new BadRequestException(
                "El factor 1 ya lo tiene la presentación base del producto.");
        }

        if (producto.Presentaciones.Any(p => p.Factor == request.Factor))
        {
            throw new ConflictException(
                $"El producto ya tiene una presentación de factor {request.Factor}.");
        }

        var presentacion = new ProductoPresentacion
        {
            ProductoId = productoId,
            UnidadId = request.UnidadId,
            Nombre = request.Nombre.Trim(),
            Factor = request.Factor,
            EsCompra = request.EsCompra,
            EsVenta = request.EsVenta,
            PredeterminadaVenta = request.PredeterminadaVenta,
            PredeterminadaCompra = request.PredeterminadaCompra,
            CodigoBarras = Limpiar(request.CodigoBarras),
            Activo = request.Activo
        };

        await _repository.AddPresentacionAsync(presentacion);
        await AplicarPredeterminadasAsync(presentacion);

        return MapPresentacion(
            await _repository.GetPresentacionAsync(presentacion.Id) ?? presentacion);
    }

    public async Task<PresentacionResponse> ActualizarPresentacionAsync(
        int id, PresentacionRequest request)
    {
        await _presentacionValidator.ValidateAndThrowAsync(request);

        var presentacion = await _repository.GetPresentacionAsync(id)
            ?? throw new NotFoundException($"No existe la presentación {id}");

        var esBase = presentacion.Factor == 1m;

        // Cambiar el factor de la base equivale a cambiar la unidad base.
        if (esBase && request.Factor != 1m)
        {
            throw new BadRequestException(
                "La presentación base es la referencia del producto: su factor siempre es 1.");
        }

        if (!esBase)
        {
            await ValidarUnidadAsync(request.UnidadId);
            presentacion.UnidadId = request.UnidadId;
            presentacion.Factor = request.Factor;
        }

        presentacion.Nombre = request.Nombre.Trim();
        presentacion.EsCompra = request.EsCompra;
        presentacion.EsVenta = request.EsVenta;
        presentacion.PredeterminadaVenta = request.PredeterminadaVenta;
        presentacion.PredeterminadaCompra = request.PredeterminadaCompra;
        presentacion.CodigoBarras = Limpiar(request.CodigoBarras);
        presentacion.Activo = esBase || request.Activo;

        await _repository.UpdatePresentacionAsync(presentacion);
        await AplicarPredeterminadasAsync(presentacion);

        return MapPresentacion(presentacion);
    }

    public async Task EliminarPresentacionAsync(int id)
    {
        var presentacion = await _repository.GetPresentacionAsync(id)
            ?? throw new NotFoundException($"No existe la presentación {id}");

        if (presentacion.Factor == 1m)
        {
            throw new BadRequestException(
                "La presentación base no se elimina: es la unidad en la que se lleva el stock.");
        }

        var precios = await _repository.ContarPreciosAsync(id);
        if (precios > 0)
        {
            throw new BadRequestException(
                $"La presentación tiene {precios} precio(s) cargado(s). Desactívala en vez de eliminarla.");
        }

        await _repository.DeletePresentacionAsync(presentacion);
    }

    public async Task<decimal> AUnidadBaseAsync(int presentacionId, decimal cantidad)
    {
        var presentacion = await _repository.GetPresentacionAsync(presentacionId)
            ?? throw new NotFoundException($"No existe la presentación {presentacionId}");

        // 2 sacos de 50 kg -> 100 kg. 3 kilos -> 3 kg.
        return cantidad * presentacion.Factor;
    }

    // ------------------------------------------------------------ Auxiliares

    private async Task<Producto> GetOrThrowAsync(int id) =>
        await _repository.GetConDetalleAsync(id)
        ?? throw new NotFoundException($"No existe el producto {id}");

    private async Task ValidarReferenciasAsync(ProductoRequestBase request)
    {
        if (request.CategoriaId is int categoriaId)
        {
            var categoria = await _catalogo.GetCategoriaAsync(categoriaId)
                ?? throw new BadRequestException("La categoría indicada no existe");

            if (!categoria.Activo)
            {
                throw new BadRequestException("La categoría indicada está desactivada");
            }
        }

        if (request.MarcaId is int marcaId)
        {
            var marca = await _catalogo.GetMarcaAsync(marcaId)
                ?? throw new BadRequestException("La marca indicada no existe");

            if (!marca.Activo)
            {
                throw new BadRequestException("La marca indicada está desactivada");
            }
        }

        await ValidarUnidadAsync(request.UnidadBaseId);

        if (request.ContenidoUnidadId is int contenidoId)
        {
            await ValidarUnidadAsync(contenidoId);
        }
    }

    private async Task ValidarUnidadAsync(int unidadId)
    {
        var unidad = await _catalogo.GetUnidadAsync(unidadId)
            ?? throw new BadRequestException("La unidad indicada no existe");

        if (!unidad.Activo)
        {
            throw new BadRequestException($"La unidad {unidad.Codigo} está desactivada");
        }
    }

    /// <summary>
    /// Pasa las marcas de predeterminada que vengan en la peticion a la
    /// presentacion correspondiente, dejando la base como respaldo.
    /// </summary>
    private static void AjustarPredeterminadas(
        Producto producto, List<PresentacionRequest> pedidas)
    {
        var venta = pedidas.FirstOrDefault(p => p.PredeterminadaVenta);
        var compra = pedidas.FirstOrDefault(p => p.PredeterminadaCompra);

        if (venta is not null)
        {
            foreach (var p in producto.Presentaciones)
            {
                p.PredeterminadaVenta = p.Factor == venta.Factor;
            }
        }

        if (compra is not null)
        {
            foreach (var p in producto.Presentaciones)
            {
                p.PredeterminadaCompra = p.Factor == compra.Factor;
            }
        }
    }

    /// <summary>Deja una sola predeterminada de venta y una de compra.</summary>
    private async Task AplicarPredeterminadasAsync(ProductoPresentacion presentacion)
    {
        if (presentacion.PredeterminadaVenta)
        {
            await _repository.LimpiarPredeterminadaAsync(
                presentacion.ProductoId, presentacion.Id, venta: true);
        }

        if (presentacion.PredeterminadaCompra)
        {
            await _repository.LimpiarPredeterminadaAsync(
                presentacion.ProductoId, presentacion.Id, venta: false);
        }
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static ProductoResponse MapToResponse(Producto p, ResumenStock? stock = null) => new()
    {
        Id = p.Id,
        Codigo = p.Codigo,
        Nombre = p.Nombre,
        Descripcion = p.Descripcion,
        CategoriaId = p.CategoriaId,
        Categoria = p.Categoria?.Nombre,
        MarcaId = p.MarcaId,
        Marca = p.Marca?.Nombre,
        UnidadBaseId = p.UnidadBaseId,
        UnidadBase = p.UnidadBase?.Codigo ?? string.Empty,
        Contenido = p.Contenido,
        ContenidoUnidadId = p.ContenidoUnidadId,
        ContenidoUnidad = p.ContenidoUnidad?.Codigo,
        ControlaStock = p.ControlaStock,
        StockMinimo = p.StockMinimo,
        Activo = p.Activo,
        FechaCreacion = p.FechaCreacion,
        Stock = stock?.Stock ?? 0,
        Valorizado = stock?.Valorizado ?? 0,
        CostoMin = stock?.CostoMin,
        CostoMax = stock?.CostoMax,
        Presentaciones = p.Presentaciones
            .OrderBy(pr => pr.Factor)
            .Select(MapPresentacion)
            .ToList()
    };

    private static PresentacionResponse MapPresentacion(ProductoPresentacion p) => new()
    {
        Id = p.Id,
        ProductoId = p.ProductoId,
        UnidadId = p.UnidadId,
        Unidad = p.Unidad?.Codigo ?? string.Empty,
        Nombre = p.Nombre,
        Factor = p.Factor,
        EsBase = p.Factor == 1m,
        EsCompra = p.EsCompra,
        EsVenta = p.EsVenta,
        PredeterminadaVenta = p.PredeterminadaVenta,
        PredeterminadaCompra = p.PredeterminadaCompra,
        CodigoBarras = p.CodigoBarras,
        Activo = p.Activo
    };
}
