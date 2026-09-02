using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Categorias, marcas y unidades de medida.
///
/// Reglas comunes a las tres:
///
///   - El nombre (o el codigo, en unidades) no se repite.
///   - Lo que esta en uso NO se elimina: se desactiva. Borrar una categoria
///     con productos dejaria fichas apuntando a la nada.
///   - Las unidades del sistema (KG, UND, LT...) no se eliminan nunca: son las
///     que dan sentido a las conversiones ya guardadas.
/// </summary>
public class CatalogoService : ICatalogoService
{
    private readonly ICatalogoRepository _repository;
    private readonly IValidator<CreateCategoriaRequest> _createCategoria;
    private readonly IValidator<UpdateCategoriaRequest> _updateCategoria;
    private readonly IValidator<CreateMarcaRequest> _createMarca;
    private readonly IValidator<UpdateMarcaRequest> _updateMarca;
    private readonly IValidator<CreateUnidadMedidaRequest> _createUnidad;
    private readonly IValidator<UpdateUnidadMedidaRequest> _updateUnidad;
    private readonly INotificador _notificador;

    public CatalogoService(
        ICatalogoRepository repository,
        IValidator<CreateCategoriaRequest> createCategoria,
        IValidator<UpdateCategoriaRequest> updateCategoria,
        IValidator<CreateMarcaRequest> createMarca,
        IValidator<UpdateMarcaRequest> updateMarca,
        IValidator<CreateUnidadMedidaRequest> createUnidad,
        IValidator<UpdateUnidadMedidaRequest> updateUnidad,
        INotificador notificador)
    {
        _repository = repository;
        _createCategoria = createCategoria;
        _updateCategoria = updateCategoria;
        _createMarca = createMarca;
        _updateMarca = updateMarca;
        _createUnidad = createUnidad;
        _updateUnidad = updateUnidad;
        _notificador = notificador;
    }

    // ------------------------------------------------------------ Categorias

    public async Task<IEnumerable<CategoriaResponse>> GetCategoriasAsync()
    {
        var categorias = await _repository.GetCategoriasAsync();

        var respuesta = new List<CategoriaResponse>();
        foreach (var categoria in categorias)
        {
            respuesta.Add(MapCategoria(
                categoria,
                await _repository.ContarProductosPorCategoriaAsync(categoria.Id)));
        }

        return respuesta;
    }

    public async Task<CategoriaResponse> GetCategoriaAsync(int id)
    {
        var categoria = await GetCategoriaOrThrowAsync(id);
        return MapCategoria(categoria, await _repository.ContarProductosPorCategoriaAsync(id));
    }

    public async Task<CategoriaResponse> CreateCategoriaAsync(CreateCategoriaRequest request)
    {
        await _createCategoria.ValidateAndThrowAsync(request);

        var nombre = request.Nombre.Trim();
        if (await _repository.ExisteCategoriaAsync(nombre))
        {
            throw new ConflictException("Ya existe una categoría con ese nombre");
        }

        var categoria = new Categoria
        {
            Nombre = nombre,
            Descripcion = Limpiar(request.Descripcion),
            Activo = true
        };

        await _repository.AddCategoriaAsync(categoria);
        var response = MapCategoria(categoria, 0);
        await _notificador.AvisarAsync("categorias", "creado", response);
        return response;
    }

    public async Task<CategoriaResponse> UpdateCategoriaAsync(int id, UpdateCategoriaRequest request)
    {
        await _updateCategoria.ValidateAndThrowAsync(request);

        var categoria = await GetCategoriaOrThrowAsync(id);
        var nombre = request.Nombre.Trim();

        if (await _repository.ExisteCategoriaAsync(nombre, id))
        {
            throw new ConflictException("Ya existe una categoría con ese nombre");
        }

        categoria.Nombre = nombre;
        categoria.Descripcion = Limpiar(request.Descripcion);
        categoria.Activo = request.Activo;

        await _repository.UpdateCategoriaAsync(categoria);
        var response = MapCategoria(categoria, await _repository.ContarProductosPorCategoriaAsync(id));
        await _notificador.AvisarAsync("categorias", "actualizado", response);
        return response;
    }

    public async Task DeleteCategoriaAsync(int id)
    {
        var categoria = await GetCategoriaOrThrowAsync(id);
        var productos = await _repository.ContarProductosPorCategoriaAsync(id);

        if (productos > 0)
        {
            throw new BadRequestException(
                $"La categoría tiene {productos} producto(s). Desactívala en vez de eliminarla.");
        }

        await _repository.DeleteCategoriaAsync(categoria);
        await _notificador.AvisarAsync("categorias", "eliminado", new { id });
    }

    // ---------------------------------------------------------------- Marcas

    public async Task<IEnumerable<MarcaResponse>> GetMarcasAsync()
    {
        var marcas = await _repository.GetMarcasAsync();

        var respuesta = new List<MarcaResponse>();
        foreach (var marca in marcas)
        {
            respuesta.Add(MapMarca(
                marca,
                await _repository.ContarProductosPorMarcaAsync(marca.Id)));
        }

        return respuesta;
    }

    public async Task<MarcaResponse> GetMarcaAsync(int id)
    {
        var marca = await GetMarcaOrThrowAsync(id);
        return MapMarca(marca, await _repository.ContarProductosPorMarcaAsync(id));
    }

    public async Task<MarcaResponse> CreateMarcaAsync(CreateMarcaRequest request)
    {
        await _createMarca.ValidateAndThrowAsync(request);

        var nombre = request.Nombre.Trim();
        if (await _repository.ExisteMarcaAsync(nombre))
        {
            throw new ConflictException("Ya existe una marca con ese nombre");
        }

        var marca = new Marca { Nombre = nombre, Activo = true };

        await _repository.AddMarcaAsync(marca);
        var response = MapMarca(marca, 0);
        await _notificador.AvisarAsync("marcas", "creado", response);
        return response;
    }

    public async Task<MarcaResponse> UpdateMarcaAsync(int id, UpdateMarcaRequest request)
    {
        await _updateMarca.ValidateAndThrowAsync(request);

        var marca = await GetMarcaOrThrowAsync(id);
        var nombre = request.Nombre.Trim();

        if (await _repository.ExisteMarcaAsync(nombre, id))
        {
            throw new ConflictException("Ya existe una marca con ese nombre");
        }

        marca.Nombre = nombre;
        marca.Activo = request.Activo;

        await _repository.UpdateMarcaAsync(marca);
        var response = MapMarca(marca, await _repository.ContarProductosPorMarcaAsync(id));
        await _notificador.AvisarAsync("marcas", "actualizado", response);
        return response;
    }

    public async Task DeleteMarcaAsync(int id)
    {
        var marca = await GetMarcaOrThrowAsync(id);
        var productos = await _repository.ContarProductosPorMarcaAsync(id);

        if (productos > 0)
        {
            throw new BadRequestException(
                $"La marca tiene {productos} producto(s). Desactívala en vez de eliminarla.");
        }

        await _repository.DeleteMarcaAsync(marca);
        await _notificador.AvisarAsync("marcas", "eliminado", new { id });
    }

    // -------------------------------------------------------------- Unidades

    public async Task<IEnumerable<UnidadMedidaResponse>> GetUnidadesAsync()
    {
        var unidades = await _repository.GetUnidadesAsync();

        var respuesta = new List<UnidadMedidaResponse>();
        foreach (var unidad in unidades)
        {
            respuesta.Add(MapUnidad(
                unidad,
                await _repository.ContarUsosUnidadAsync(unidad.Id)));
        }

        return respuesta;
    }

    public async Task<UnidadMedidaResponse> GetUnidadAsync(int id)
    {
        var unidad = await GetUnidadOrThrowAsync(id);
        return MapUnidad(unidad, await _repository.ContarUsosUnidadAsync(id));
    }

    public async Task<UnidadMedidaResponse> CreateUnidadAsync(CreateUnidadMedidaRequest request)
    {
        await _createUnidad.ValidateAndThrowAsync(request);

        // El codigo se guarda en mayusculas: es el que sale impreso y no tiene
        // sentido tener "kg" y "KG" como unidades distintas.
        var codigo = request.Codigo.Trim().ToUpperInvariant();

        if (await _repository.ExisteUnidadAsync(codigo))
        {
            throw new ConflictException("Ya existe una unidad con ese código");
        }

        var unidad = new UnidadMedida
        {
            Codigo = codigo,
            Nombre = request.Nombre.Trim(),
            Tipo = request.Tipo,
            Fraccionable = request.Fraccionable,
            Activo = true,
            DelSistema = false
        };

        await _repository.AddUnidadAsync(unidad);
        var response = MapUnidad(unidad, 0);
        await _notificador.AvisarAsync("unidades", "creado", response);
        return response;
    }

    public async Task<UnidadMedidaResponse> UpdateUnidadAsync(
        int id, UpdateUnidadMedidaRequest request)
    {
        await _updateUnidad.ValidateAndThrowAsync(request);

        var unidad = await GetUnidadOrThrowAsync(id);
        var codigo = request.Codigo.Trim().ToUpperInvariant();

        if (await _repository.ExisteUnidadAsync(codigo, id))
        {
            throw new ConflictException("Ya existe una unidad con ese código");
        }

        unidad.Codigo = codigo;
        unidad.Nombre = request.Nombre.Trim();
        unidad.Tipo = request.Tipo;
        unidad.Fraccionable = request.Fraccionable;
        unidad.Activo = request.Activo;

        await _repository.UpdateUnidadAsync(unidad);
        var response = MapUnidad(unidad, await _repository.ContarUsosUnidadAsync(id));
        await _notificador.AvisarAsync("unidades", "actualizado", response);
        return response;
    }

    public async Task DeleteUnidadAsync(int id)
    {
        var unidad = await GetUnidadOrThrowAsync(id);

        if (unidad.DelSistema)
        {
            throw new BadRequestException(
                "Las unidades del sistema no se eliminan. Puedes desactivarla.");
        }

        var usos = await _repository.ContarUsosUnidadAsync(id);
        if (usos > 0)
        {
            throw new BadRequestException(
                $"La unidad se usa en {usos} producto(s) o presentación(es). Desactívala en vez de eliminarla.");
        }

        await _repository.DeleteUnidadAsync(unidad);
        await _notificador.AvisarAsync("unidades", "eliminado", new { id });
    }

    // ------------------------------------------------------------- Auxiliares

    private async Task<Categoria> GetCategoriaOrThrowAsync(int id) =>
        await _repository.GetCategoriaAsync(id)
        ?? throw new NotFoundException($"No existe la categoría {id}");

    private async Task<Marca> GetMarcaOrThrowAsync(int id) =>
        await _repository.GetMarcaAsync(id)
        ?? throw new NotFoundException($"No existe la marca {id}");

    private async Task<UnidadMedida> GetUnidadOrThrowAsync(int id) =>
        await _repository.GetUnidadAsync(id)
        ?? throw new NotFoundException($"No existe la unidad {id}");

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static CategoriaResponse MapCategoria(Categoria c, int productos) => new()
    {
        Id = c.Id,
        Nombre = c.Nombre,
        Descripcion = c.Descripcion,
        Activo = c.Activo,
        Productos = productos
    };

    private static MarcaResponse MapMarca(Marca m, int productos) => new()
    {
        Id = m.Id,
        Nombre = m.Nombre,
        Activo = m.Activo,
        Productos = productos
    };

    private static UnidadMedidaResponse MapUnidad(UnidadMedida u, int usos) => new()
    {
        Id = u.Id,
        Codigo = u.Codigo,
        Nombre = u.Nombre,
        Tipo = u.Tipo,
        Fraccionable = u.Fraccionable,
        Activo = u.Activo,
        DelSistema = u.DelSistema,
        Usos = usos
    };
}
