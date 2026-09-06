using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Mercados: dónde se entrega. El nombre no se repite, y lo que ya está en
/// uso no se elimina — se desactiva, para no dejar clientes apuntando a la
/// nada.
/// </summary>
public class MercadoService : IMercadoService
{
    private readonly IMercadoRepository _repository;
    private readonly IValidator<CreateMercadoRequest> _createValidator;
    private readonly IValidator<UpdateMercadoRequest> _updateValidator;
    private readonly INotificador _notificador;

    public MercadoService(
        IMercadoRepository repository,
        IValidator<CreateMercadoRequest> createValidator,
        IValidator<UpdateMercadoRequest> updateValidator,
        INotificador notificador)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<MercadoResponse>> GetAllAsync()
    {
        var mercados = await _repository.GetAllAsync();
        var respuesta = new List<MercadoResponse>();
        foreach (var mercado in mercados)
        {
            respuesta.Add(MapToResponse(mercado, await _repository.ContarClientesAsync(mercado.Id)));
        }
        return respuesta;
    }

    public async Task<MercadoResponse> GetByIdAsync(int id)
    {
        var mercado = await GetOrThrowAsync(id);
        return MapToResponse(mercado, await _repository.ContarClientesAsync(id));
    }

    public async Task<MercadoResponse> CreateAsync(CreateMercadoRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        var nombre = request.Nombre.Trim();
        if (await _repository.ExisteNombreAsync(nombre))
        {
            throw new ConflictException("Ya existe un mercado con ese nombre");
        }

        var mercado = new Mercado { Nombre = nombre, Activo = true };
        await _repository.AddAsync(mercado);

        var response = MapToResponse(mercado, 0);
        await _notificador.AvisarAsync("mercados", "creado", response);
        return response;
    }

    public async Task<MercadoResponse> UpdateAsync(int id, UpdateMercadoRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var mercado = await GetOrThrowAsync(id);
        var nombre = request.Nombre.Trim();

        if (await _repository.ExisteNombreAsync(nombre, id))
        {
            throw new ConflictException("Ya existe un mercado con ese nombre");
        }

        mercado.Nombre = nombre;
        mercado.Activo = request.Activo;
        await _repository.UpdateAsync(mercado);

        var response = MapToResponse(mercado, await _repository.ContarClientesAsync(id));
        await _notificador.AvisarAsync("mercados", "actualizado", response);
        return response;
    }

    public async Task DeleteAsync(int id)
    {
        var mercado = await GetOrThrowAsync(id);
        var usos = await _repository.ContarClientesAsync(id);

        if (usos > 0)
        {
            throw new BadRequestException($"El mercado tiene {usos} cliente(s). Desactívalo en vez de eliminarlo.");
        }

        await _repository.DeleteAsync(mercado);
        await _notificador.AvisarAsync("mercados", "eliminado", new { id });
    }

    private async Task<Mercado> GetOrThrowAsync(int id) =>
        await _repository.GetByIdAsync(id)
        ?? throw new NotFoundException($"No existe el mercado {id}");

    private static MercadoResponse MapToResponse(Mercado m, int clientes) => new()
    {
        Id = m.Id,
        Nombre = m.Nombre,
        Activo = m.Activo,
        Clientes = clientes
    };
}
