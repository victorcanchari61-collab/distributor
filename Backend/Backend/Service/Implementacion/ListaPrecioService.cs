using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Reglas de las listas de precios:
///
///   - El nombre no se repite.
///   - Siempre hay UNA predeterminada: es la que se aplica al cliente que no
///     tiene lista propia. Marcar otra desmarca la anterior.
///   - La predeterminada no se elimina ni se desactiva sin nombrar otra antes.
///   - En una lista, una presentacion no repite cantidad minima: guardar sobre
///     la misma clave actualiza el precio en vez de duplicarlo.
///   - Una lista con precios cargados no se elimina.
/// </summary>
public class ListaPrecioService : IListaPrecioService
{
    private readonly IListaPrecioRepository _repository;
    private readonly IProductoRepository _productos;
    private readonly IValidator<CreateListaPrecioRequest> _createValidator;
    private readonly IValidator<UpdateListaPrecioRequest> _updateValidator;
    private readonly IValidator<GuardarPreciosRequest> _preciosValidator;
    private readonly INotificador _notificador;

    public ListaPrecioService(
        IListaPrecioRepository repository,
        IProductoRepository productos,
        IValidator<CreateListaPrecioRequest> createValidator,
        IValidator<UpdateListaPrecioRequest> updateValidator,
        IValidator<GuardarPreciosRequest> preciosValidator,
        INotificador notificador)
    {
        _repository = repository;
        _productos = productos;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _preciosValidator = preciosValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<ListaPrecioResponse>> GetAllAsync()
    {
        var listas = await _repository.GetAllAsync();

        var respuesta = new List<ListaPrecioResponse>();
        foreach (var lista in listas)
        {
            respuesta.Add(MapLista(lista, await _repository.ContarPreciosAsync(lista.Id)));
        }

        return respuesta;
    }

    public async Task<ListaPrecioResponse> GetByIdAsync(int id)
    {
        var lista = await GetOrThrowAsync(id);
        return MapLista(lista, await _repository.ContarPreciosAsync(id));
    }

    public async Task<ListaPrecioResponse> CreateAsync(CreateListaPrecioRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        var nombre = request.Nombre.Trim();
        if (await _repository.ExisteNombreAsync(nombre))
        {
            throw new ConflictException("Ya existe una lista con ese nombre");
        }

        // La primera lista es la predeterminada aunque no lo pidan: sin una
        // marcada, un cliente sin lista propia se quedaria sin precios.
        var esPrimera = !(await _repository.GetAllAsync()).Any();

        var lista = new ListaPrecio
        {
            Nombre = nombre,
            Descripcion = Limpiar(request.Descripcion),
            EsPredeterminada = request.EsPredeterminada || esPrimera,
            Activo = true
        };

        await _repository.AddAsync(lista);

        if (lista.EsPredeterminada)
        {
            await _repository.MarcarPredeterminadaAsync(lista.Id);
        }

        var creada = MapLista(lista, 0);
        await _notificador.AvisarAsync("listasprecio", "creado", creada);
        return creada;
    }

    public async Task<ListaPrecioResponse> UpdateAsync(int id, UpdateListaPrecioRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var lista = await GetOrThrowAsync(id);
        var nombre = request.Nombre.Trim();

        if (await _repository.ExisteNombreAsync(nombre, id))
        {
            throw new ConflictException("Ya existe una lista con ese nombre");
        }

        if (lista.EsPredeterminada && !request.Activo)
        {
            throw new BadRequestException(
                "Es la lista predeterminada. Marca otra como predeterminada antes de desactivarla.");
        }

        lista.Nombre = nombre;
        lista.Descripcion = Limpiar(request.Descripcion);
        lista.Activo = request.Activo;

        await _repository.UpdateAsync(lista);
        var response = MapLista(lista, await _repository.ContarPreciosAsync(id));
        await _notificador.AvisarAsync("listasprecio", "actualizado", response);
        return response;
    }

    public async Task<ListaPrecioResponse> MarcarPredeterminadaAsync(int id)
    {
        var lista = await GetOrThrowAsync(id);

        if (!lista.Activo)
        {
            throw new BadRequestException("Una lista desactivada no puede ser la predeterminada");
        }

        await _repository.MarcarPredeterminadaAsync(id);

        lista.EsPredeterminada = true;
        var response = MapLista(lista, await _repository.ContarPreciosAsync(id));
        await _notificador.AvisarAsync("listasprecio", "predeterminada", response);
        return response;
    }

    public async Task DeleteAsync(int id)
    {
        var lista = await GetOrThrowAsync(id);

        if (lista.EsPredeterminada)
        {
            throw new BadRequestException(
                "Es la lista predeterminada. Marca otra antes de eliminarla.");
        }

        var precios = await _repository.ContarPreciosAsync(id);
        if (precios > 0)
        {
            throw new BadRequestException(
                $"La lista tiene {precios} precio(s) cargado(s). Desactívala en vez de eliminarla.");
        }

        await _repository.DeleteAsync(lista);
        await _notificador.AvisarAsync("listasprecio", "eliminado", new { id });
    }

    // ---------------------------------------------------------------- Precios

    public async Task<IEnumerable<PrecioResponse>> GetPreciosAsync(int listaId)
    {
        await GetOrThrowAsync(listaId);

        var precios = await _repository.GetPreciosAsync(listaId);
        return precios.Select(MapPrecio);
    }

    public async Task<IEnumerable<PrecioResponse>> GuardarPreciosAsync(
        int listaId, GuardarPreciosRequest request)
    {
        await _preciosValidator.ValidateAndThrowAsync(request);
        await GetOrThrowAsync(listaId);

        foreach (var item in request.Precios)
        {
            var presentacion = await _productos.GetPresentacionAsync(item.PresentacionId)
                ?? throw new BadRequestException(
                    $"No existe la presentación {item.PresentacionId}");

            if (!presentacion.Activo)
            {
                throw new BadRequestException(
                    $"La presentación '{presentacion.Nombre}' está desactivada");
            }

            var existente = await _repository.BuscarPrecioAsync(
                listaId, item.PresentacionId, item.CantidadMinima);

            if (existente is null)
            {
                await _repository.AddPrecioAsync(new PrecioProducto
                {
                    ListaPrecioId = listaId,
                    PresentacionId = item.PresentacionId,
                    Precio = item.Precio,
                    CantidadMinima = item.CantidadMinima,
                    Activo = true,
                    FechaActualizacion = DateTime.UtcNow
                });
            }
            else
            {
                // Misma lista, misma presentacion y misma cantidad minima: es
                // el mismo precio, se actualiza en vez de duplicarse.
                existente.Precio = item.Precio;
                existente.Activo = true;
                existente.FechaActualizacion = DateTime.UtcNow;
                await _repository.UpdatePrecioAsync(existente);
            }
        }

        var precios = await GetPreciosAsync(listaId);
        await _notificador.AvisarAsync("listasprecio", "precios", new { listaId });
        return precios;
    }

    public async Task EliminarPrecioAsync(int precioId)
    {
        var precio = await _repository.GetPrecioAsync(precioId)
            ?? throw new NotFoundException($"No existe el precio {precioId}");

        await _repository.DeletePrecioAsync(precio);
        await _notificador.AvisarAsync("listasprecio", "precios", new { listaId = precio.ListaPrecioId });
    }

    public async Task<PrecioResponse?> ResolverPrecioAsync(
        int listaId, int presentacionId, decimal cantidad)
    {
        var precios = await _repository.GetPreciosAsync(listaId);

        // De los escalones que ya alcanzo, el mas alto: comprar 12 sacos toma
        // el precio "desde 10", no el "desde 1".
        var elegido = precios
            .Where(p => p.PresentacionId == presentacionId
                        && p.Activo
                        && p.CantidadMinima <= cantidad)
            .OrderByDescending(p => p.CantidadMinima)
            .FirstOrDefault();

        return elegido is null ? null : MapPrecio(elegido);
    }

    // ------------------------------------------------------------ Auxiliares

    private async Task<ListaPrecio> GetOrThrowAsync(int id) =>
        await _repository.GetAsync(id)
        ?? throw new NotFoundException($"No existe la lista de precios {id}");

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static ListaPrecioResponse MapLista(ListaPrecio l, int precios) => new()
    {
        Id = l.Id,
        Nombre = l.Nombre,
        Descripcion = l.Descripcion,
        EsPredeterminada = l.EsPredeterminada,
        Activo = l.Activo,
        Precios = precios
    };

    private static PrecioResponse MapPrecio(PrecioProducto p)
    {
        var presentacion = p.Presentacion;
        var producto = presentacion?.Producto;
        var factor = presentacion?.Factor ?? 1m;

        return new PrecioResponse
        {
            Id = p.Id,
            ListaPrecioId = p.ListaPrecioId,
            ListaPrecio = p.ListaPrecio?.Nombre ?? string.Empty,
            PresentacionId = p.PresentacionId,
            Presentacion = presentacion?.Nombre ?? string.Empty,
            ProductoId = producto?.Id ?? 0,
            Producto = producto?.Nombre ?? string.Empty,
            Precio = p.Precio,
            CantidadMinima = p.CantidadMinima,
            // Lo que deja comparar el saco contra el kilo suelto.
            PrecioUnidadBase = factor == 0 ? p.Precio : Math.Round(p.Precio / factor, 4),
            UnidadBase = producto?.UnidadBase?.Codigo ?? string.Empty,
            Activo = p.Activo,
            FechaActualizacion = p.FechaActualizacion
        };
    }
}
