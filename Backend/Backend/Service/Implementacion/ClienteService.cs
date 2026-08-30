using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

public class ClienteService : IClienteService
{
    private readonly IClienteRepository _repository;
    private readonly IValidator<CreateClienteRequest> _createValidator;
    private readonly IValidator<UpdateClienteRequest> _updateValidator;

    public ClienteService(IClienteRepository repository,
        IValidator<CreateClienteRequest> createValidator,
        IValidator<UpdateClienteRequest> updateValidator)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
    }

    public async Task<IEnumerable<ClienteResponse>> GetAllAsync()
    {
        var clientes = await _repository.GetAllAsync();
        return clientes.Where(c => c.Activo).Select(MapToResponse);
    }

    public async Task<ClienteResponse> GetByIdAsync(int id)
    {
        var cliente = await GetActiveOrThrowAsync(id);
        return MapToResponse(cliente);
    }

    public async Task<ClienteResponse> CreateAsync(CreateClienteRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        if (await _repository.ExistsByRucAsync(request.Ruc))
        {
            throw new ConflictException("Ya existe un cliente con ese RUC");
        }

        var cliente = new Cliente
        {
            Nombre = request.Nombre,
            Ruc = request.Ruc,
            Direccion = request.Direccion,
            Telefono = request.Telefono,
            Email = request.Email
        };

        await _repository.AddAsync(cliente);
        return MapToResponse(cliente);
    }

    public async Task<ClienteResponse> UpdateAsync(int id, UpdateClienteRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var cliente = await GetActiveOrThrowAsync(id);

        if (await _repository.ExistsByRucAsync(request.Ruc, id))
        {
            throw new ConflictException("Ya existe un cliente con ese RUC");
        }

        cliente.Nombre = request.Nombre;
        cliente.Ruc = request.Ruc;
        cliente.Direccion = request.Direccion;
        cliente.Telefono = request.Telefono;
        cliente.Email = request.Email;
        cliente.Activo = request.Activo;

        await _repository.UpdateAsync(cliente);
        return MapToResponse(cliente);
    }

    public async Task DeleteAsync(int id)
    {
        var cliente = await GetActiveOrThrowAsync(id);
        cliente.Activo = false;
        await _repository.UpdateAsync(cliente);
    }

    private async Task<Cliente> GetActiveOrThrowAsync(int id)
    {
        var cliente = await _repository.GetByIdAsync(id);
        if (cliente is null || !cliente.Activo)
        {
            throw new NotFoundException("Cliente no encontrado");
        }

        return cliente;
    }

    private static ClienteResponse MapToResponse(Cliente cliente)
    {
        return new ClienteResponse
        {
            Id = cliente.Id,
            Nombre = cliente.Nombre,
            Ruc = cliente.Ruc,
            Direccion = cliente.Direccion,
            Telefono = cliente.Telefono,
            Email = cliente.Email,
            Activo = cliente.Activo,
            FechaCreacion = cliente.FechaCreacion
        };
    }
}
