using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Rutas de reparto. El nombre no se repite, y lo que ya está en uso no se
/// elimina — se desactiva, para no dejar clientes apuntando a la nada.
/// </summary>
public class RutaService : IRutaService
{
    private readonly IRutaRepository _repository;
    private readonly IValidator<CreateRutaRequest> _createValidator;
    private readonly IValidator<UpdateRutaRequest> _updateValidator;
    private readonly INotificador _notificador;

    public RutaService(
        IRutaRepository repository,
        IValidator<CreateRutaRequest> createValidator,
        IValidator<UpdateRutaRequest> updateValidator,
        INotificador notificador)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<RutaResponse>> GetAllAsync()
    {
        var rutas = await _repository.GetAllAsync();
        var respuesta = new List<RutaResponse>();
        foreach (var ruta in rutas)
        {
            respuesta.Add(MapToResponse(ruta, await _repository.ContarClientesAsync(ruta.Id)));
        }
        return respuesta;
    }

    public async Task<RutaResponse> GetByIdAsync(int id)
    {
        var ruta = await GetOrThrowAsync(id);
        return MapToResponse(ruta, await _repository.ContarClientesAsync(id));
    }

    public async Task<RutaResponse> CreateAsync(CreateRutaRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        var nombre = request.Nombre.Trim();
        if (await _repository.ExisteNombreAsync(nombre))
        {
            throw new ConflictException("Ya existe una ruta con ese nombre");
        }

        var ruta = new Ruta { Nombre = nombre, Activo = true };
        await _repository.AddAsync(ruta);

        var response = MapToResponse(ruta, 0);
        await _notificador.AvisarAsync("rutas", "creado", response);
        return response;
    }

    public async Task<RutaResponse> UpdateAsync(int id, UpdateRutaRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var ruta = await GetOrThrowAsync(id);
        var nombre = request.Nombre.Trim();

        if (await _repository.ExisteNombreAsync(nombre, id))
        {
            throw new ConflictException("Ya existe una ruta con ese nombre");
        }

        ruta.Nombre = nombre;
        ruta.Activo = request.Activo;
        await _repository.UpdateAsync(ruta);

        var response = MapToResponse(ruta, await _repository.ContarClientesAsync(id));
        await _notificador.AvisarAsync("rutas", "actualizado", response);
        return response;
    }

    public async Task DeleteAsync(int id)
    {
        var ruta = await GetOrThrowAsync(id);
        var usos = await _repository.ContarClientesAsync(id);

        if (usos > 0)
        {
            throw new BadRequestException($"La ruta tiene {usos} cliente(s). Desactívala en vez de eliminarla.");
        }

        await _repository.DeleteAsync(ruta);
        await _notificador.AvisarAsync("rutas", "eliminado", new { id });
    }

    private async Task<Ruta> GetOrThrowAsync(int id) =>
        await _repository.GetByIdAsync(id)
        ?? throw new NotFoundException($"No existe la ruta {id}");

    private static RutaResponse MapToResponse(Ruta r, int clientes) => new()
    {
        Id = r.Id,
        Nombre = r.Nombre,
        Activo = r.Activo,
        Clientes = clientes
    };
}
