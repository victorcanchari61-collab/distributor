using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

public class ProveedorService : IProveedorService
{
    private readonly IProveedorRepository _repository;
    private readonly IValidator<CreateProveedorRequest> _createValidator;
    private readonly IValidator<UpdateProveedorRequest> _updateValidator;

    public ProveedorService(IProveedorRepository repository,
        IValidator<CreateProveedorRequest> createValidator,
        IValidator<UpdateProveedorRequest> updateValidator)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
    }

    public async Task<IEnumerable<ProveedorResponse>> GetAllAsync()
    {
        var proveedores = await _repository.GetAllAsync();
        return proveedores.Where(p => p.Activo).Select(MapToResponse);
    }

    public async Task<ProveedorResponse> GetByIdAsync(int id)
    {
        var proveedor = await GetActiveOrThrowAsync(id);
        return MapToResponse(proveedor);
    }

    public async Task<ProveedorResponse> CreateAsync(CreateProveedorRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        if (await _repository.ExistsByRucAsync(request.Ruc))
        {
            throw new ConflictException("Ya existe un proveedor con ese RUC");
        }

        var proveedor = new Proveedor
        {
            Nombre = request.Nombre,
            Ruc = request.Ruc,
            Direccion = request.Direccion,
            Telefono = request.Telefono,
            Email = request.Email
        };

        await _repository.AddAsync(proveedor);
        return MapToResponse(proveedor);
    }

    public async Task<ProveedorResponse> UpdateAsync(int id, UpdateProveedorRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var proveedor = await GetActiveOrThrowAsync(id);

        if (await _repository.ExistsByRucAsync(request.Ruc, id))
        {
            throw new ConflictException("Ya existe un proveedor con ese RUC");
        }

        proveedor.Nombre = request.Nombre;
        proveedor.Ruc = request.Ruc;
        proveedor.Direccion = request.Direccion;
        proveedor.Telefono = request.Telefono;
        proveedor.Email = request.Email;
        proveedor.Activo = request.Activo;

        await _repository.UpdateAsync(proveedor);
        return MapToResponse(proveedor);
    }

    public async Task DeleteAsync(int id)
    {
        var proveedor = await GetActiveOrThrowAsync(id);
        proveedor.Activo = false;
        await _repository.UpdateAsync(proveedor);
    }

    private async Task<Proveedor> GetActiveOrThrowAsync(int id)
    {
        var proveedor = await _repository.GetByIdAsync(id);
        if (proveedor is null || !proveedor.Activo)
        {
            throw new NotFoundException("Proveedor no encontrado");
        }

        return proveedor;
    }

    private static ProveedorResponse MapToResponse(Proveedor proveedor)
    {
        return new ProveedorResponse
        {
            Id = proveedor.Id,
            Nombre = proveedor.Nombre,
            Ruc = proveedor.Ruc,
            Direccion = proveedor.Direccion,
            Telefono = proveedor.Telefono,
            Email = proveedor.Email,
            Activo = proveedor.Activo,
            FechaCreacion = proveedor.FechaCreacion
        };
    }
}
