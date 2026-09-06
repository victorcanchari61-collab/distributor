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
    private readonly IListaPrecioRepository _listasPrecio;
    private readonly IValidator<CreateProductoRequest> _createValidator;
    private readonly IValidator<UpdateProductoRequest> _updateValidator;
    private readonly IValidator<PresentacionRequest> _presentacionValidator;
    private readonly INotificador _notificador;

    public ProductoService(
        IProductoRepository repository,
        ICatalogoRepository catalogo,
        IListaPrecioRepository listasPrecio,
        IValidator<CreateProductoRequest> createValidator,
        IValidator<UpdateProductoRequest> updateValidator,
        IValidator<PresentacionRequest> presentacionValidator,
        INotificador notificador)
    {
        _repository = repository;
        _catalogo = catalogo;
        _listasPrecio = listasPrecio;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _presentacionValidator = presentacionValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<ProductoResponse>> GetAllAsync()
    {
        var productos = await _repository.GetAllConDetalleAsync();
        return productos.Select(MapToResponse);
    }

    public async Task<PaginaResponse<ProductoResponse>> ListarAsync(ConsultaTablaRequest consulta)
    {
        var (items, total) = await _repository.ListarAsync(consulta);

        return new PaginaResponse<ProductoResponse>
        {
            Items = items.Select(MapToResponse).ToList(),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public Task<ResumenProductosResponse> GetResumenAsync() => _repository.ResumenAsync();

    public async Task<ProductoResponse> GetByIdAsync(int id) =>
        MapToResponse(await GetOrThrowAsync(id));

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
            CostoReferencia = request.CostoReferencia,
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
        var response = MapToResponse(await GetOrThrowAsync(producto.Id));
        await _notificador.AvisarAsync("productos", "creado", response);
        return response;
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
        producto.CostoReferencia = request.CostoReferencia;
        producto.ControlaStock = request.ControlaStock;
        producto.StockMinimo = request.StockMinimo;
        producto.Activo = request.Activo;

        await _repository.UpdateAsync(producto);
        var response = MapToResponse(await GetOrThrowAsync(id));
        await _notificador.AvisarAsync("productos", "actualizado", response);
        return response;
    }

    public async Task<ProductoResponse> CambiarEstadoAsync(int id, bool activo)
    {
        var producto = await GetOrThrowAsync(id);
        producto.Activo = activo;

        await _repository.UpdateAsync(producto);
        var response = MapToResponse(producto);
        await _notificador.AvisarAsync("productos", "estado", response);
        return response;
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
        await _notificador.AvisarAsync("productos", "eliminado", new { id });
    }

    /// <summary>
    /// Alta masiva desde un catálogo externo (Excel de un sistema viejo, por
    /// ejemplo). Cada fila va por su cuenta: una mala no tumba a las buenas.
    ///
    /// La lista "predeterminada" recibe PrecioContado; "Por saco" y
    /// "Mayorista" se crean solas la primera vez que una fila trae ese
    /// precio. Si el producto ya existe y se pide actualizar, se refresca su
    /// nombre, costo y los precios que traiga — nunca sus presentaciones, para
    /// no pisar lo que ya se ajustó a mano.
    /// </summary>
    public async Task<ImportarResponse> ImportarAsync(ImportarProductosRequest request)
    {
        var resultado = new ImportarResponse();
        var unidades = (await _catalogo.GetUnidadesAsync()).ToList();
        var vistos = new HashSet<string>();

        var listas = (await _listasPrecio.GetAllAsync()).ToList();
        var listaContado = listas.FirstOrDefault(l => l.EsPredeterminada)
            ?? await ObtenerOCrearListaAsync(listas, "Contado");
        var listaPorSaco = await ObtenerOCrearListaAsync(listas, "Por saco");
        var listaMayorista = await ObtenerOCrearListaAsync(listas, "Mayorista");

        for (var i = 0; i < request.Filas.Count; i++)
        {
            var fila = request.Filas[i];
            var numero = i + 1;
            var codigo = fila.Codigo?.Trim().ToUpperInvariant() ?? string.Empty;

            try
            {
                if (string.IsNullOrWhiteSpace(codigo))
                {
                    throw new BadRequestException("Falta el código");
                }

                if (string.IsNullOrWhiteSpace(fila.Nombre))
                {
                    throw new BadRequestException("Falta el nombre");
                }

                var unidad = unidades.FirstOrDefault(u =>
                    string.Equals(u.Codigo, fila.UnidadBaseCodigo?.Trim(), StringComparison.OrdinalIgnoreCase));
                if (unidad is null)
                {
                    throw new BadRequestException($"No existe la unidad '{fila.UnidadBaseCodigo}'");
                }

                if (!vistos.Add(codigo))
                {
                    resultado.Omitidos++;
                    resultado.Errores.Add(new ImportarFilaError
                    {
                        Fila = numero,
                        Documento = codigo,
                        Motivo = "El código se repite dentro del archivo"
                    });
                    continue;
                }

                var existente = await _repository.GetByCodigoAsync(codigo);

                if (existente is not null)
                {
                    if (!request.ActualizarExistentes)
                    {
                        resultado.Omitidos++;
                        resultado.Errores.Add(new ImportarFilaError
                        {
                            Fila = numero,
                            Documento = codigo,
                            Motivo = "Ya existe un producto con ese código"
                        });
                        continue;
                    }

                    existente.Nombre = fila.Nombre.Trim();
                    if (fila.CostoReferencia is decimal costo)
                    {
                        existente.CostoReferencia = costo;
                    }

                    await _repository.UpdateAsync(existente);

                    var basePresentacion = existente.Presentaciones.FirstOrDefault(p => p.Factor == 1m);
                    if (basePresentacion is not null)
                    {
                        await AsignarPreciosAsync(basePresentacion.Id, listaContado, listaPorSaco, listaMayorista, fila);
                    }

                    resultado.Actualizados++;
                    continue;
                }

                var producto = new Producto
                {
                    Codigo = codigo,
                    Nombre = fila.Nombre.Trim(),
                    UnidadBaseId = unidad.Id,
                    CostoReferencia = fila.CostoReferencia,
                    ControlaStock = true,
                    Activo = true
                };

                producto.Presentaciones.Add(new ProductoPresentacion
                {
                    UnidadId = unidad.Id,
                    Nombre = unidad.Nombre,
                    Factor = 1m,
                    EsCompra = true,
                    EsVenta = true,
                    PredeterminadaVenta = true,
                    PredeterminadaCompra = true,
                    Activo = true
                });

                foreach (var factor in fila.Presentaciones.Where(f => f > 0 && f != 1m).Distinct())
                {
                    producto.Presentaciones.Add(new ProductoPresentacion
                    {
                        UnidadId = unidad.Id,
                        Nombre = $"{factor:0.####} {unidad.Codigo}",
                        Factor = factor,
                        EsCompra = true,
                        EsVenta = true,
                        Activo = true
                    });
                }

                await _repository.AddAsync(producto);

                var nuevaBase = producto.Presentaciones.First(p => p.Factor == 1m);
                await AsignarPreciosAsync(nuevaBase.Id, listaContado, listaPorSaco, listaMayorista, fila);

                resultado.Creados++;
            }
            catch (Exception ex) when (ex is BadRequestException or ConflictException)
            {
                resultado.Omitidos++;
                resultado.Errores.Add(new ImportarFilaError
                {
                    Fila = numero,
                    Documento = codigo,
                    Motivo = ex.Message
                });
            }
        }

        await _notificador.AvisarAsync("productos", "importado", new { resultado.Creados, resultado.Actualizados });
        if (resultado.Creados > 0 || resultado.Actualizados > 0)
        {
            await _notificador.AvisarAsync("listasprecio", "precios", new { });
        }

        return resultado;
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

        var response = MapPresentacion(
            await _repository.GetPresentacionAsync(presentacion.Id) ?? presentacion);
        await _notificador.AvisarAsync("productos", "presentacion", response);
        return response;
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

        var response = MapPresentacion(presentacion);
        await _notificador.AvisarAsync("productos", "presentacion", response);
        return response;
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
        await _notificador.AvisarAsync("productos", "presentacion", new { id });
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

    /// <summary>Busca una lista por nombre entre las ya cargadas, o la crea si falta.</summary>
    private async Task<ListaPrecio> ObtenerOCrearListaAsync(List<ListaPrecio> listas, string nombre)
    {
        var existente = listas.FirstOrDefault(l => l.Nombre == nombre);
        if (existente is not null) return existente;

        var lista = new ListaPrecio { Nombre = nombre, Activo = true };
        await _listasPrecio.AddAsync(lista);
        listas.Add(lista);
        return lista;
    }

    /// <summary>
    /// Deja el precio de cada columna que traiga la fila en su lista, sobre la
    /// presentación base. Una columna vacía o en cero no toca nada.
    /// </summary>
    private async Task AsignarPreciosAsync(
        int presentacionBaseId,
        ListaPrecio contado,
        ListaPrecio porSaco,
        ListaPrecio mayorista,
        CreateProductoImportRequest fila)
    {
        async Task Asignar(ListaPrecio lista, decimal? precio)
        {
            if (precio is not decimal valor || valor <= 0) return;

            var existente = await _listasPrecio.BuscarPrecioAsync(lista.Id, presentacionBaseId, 1m);
            if (existente is null)
            {
                await _listasPrecio.AddPrecioAsync(new PrecioProducto
                {
                    ListaPrecioId = lista.Id,
                    PresentacionId = presentacionBaseId,
                    Precio = valor,
                    CantidadMinima = 1m,
                    Activo = true,
                    FechaActualizacion = DateTime.UtcNow
                });
            }
            else
            {
                existente.Precio = valor;
                existente.Activo = true;
                existente.FechaActualizacion = DateTime.UtcNow;
                await _listasPrecio.UpdatePrecioAsync(existente);
            }
        }

        await Asignar(contado, fila.PrecioContado);
        await Asignar(porSaco, fila.PrecioPorSaco);
        await Asignar(mayorista, fila.PrecioMayorista);
    }

    private static ProductoResponse MapToResponse(Producto p) => new()
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
        CostoReferencia = p.CostoReferencia,
        ControlaStock = p.ControlaStock,
        StockMinimo = p.StockMinimo,
        Activo = p.Activo,
        FechaCreacion = p.FechaCreacion,
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
