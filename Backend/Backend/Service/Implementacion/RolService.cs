using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Reglas de los roles:
///
///   - El nombre no se repite.
///   - Los roles del sistema (Administrador, Vendedor, Almacenero) no se
///     eliminan, pero SI se pueden desactivar, salvo Administrador.
///   - Administrador esta protegido: sin el activo nadie podria volver a
///     configurar el sistema.
///   - Un rol con usuarios asignados no se elimina; primero hay que moverlos.
///   - Guardar permisos reemplaza la matriz completa del rol.
/// </summary>
public class RolService : IRolService
{
    /// <summary>Id sembrado del rol Administrador.</summary>
    private const int RolAdministradorId = 1;

    private readonly IRolRepository _repository;
    private readonly IValidator<CreateRolRequest> _createValidator;
    private readonly IValidator<UpdateRolRequest> _updateValidator;

    public RolService(IRolRepository repository,
        IValidator<CreateRolRequest> createValidator,
        IValidator<UpdateRolRequest> updateValidator)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
    }

    public async Task<IEnumerable<RolResponse>> GetAllAsync()
    {
        var roles = await _repository.GetAllConDetalleAsync();
        return roles.Select(r => MapToResponse(r));
    }

    public async Task<RolResponse> GetByIdAsync(int id)
    {
        var rol = await GetOrThrowAsync(id);
        return MapToResponse(rol, await _repository.ContarUsuariosAsync(id));
    }

    public async Task<RolResponse> CreateAsync(CreateRolRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        if (await _repository.ExistsByNombreAsync(request.Nombre))
        {
            throw new ConflictException("Ya existe un rol con ese nombre");
        }

        var rol = new Rol
        {
            Nombre = request.Nombre,
            Descripcion = request.Descripcion,
            Activo = true,
            DelSistema = false
        };

        await _repository.AddAsync(rol);
        return MapToResponse(rol);
    }

    public async Task<RolResponse> UpdateAsync(int id, UpdateRolRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var rol = await GetOrThrowAsync(id);

        if (await _repository.ExistsByNombreAsync(request.Nombre, id))
        {
            throw new ConflictException("Ya existe un rol con ese nombre");
        }

        if (EsProtegido(rol) && !request.Activo)
        {
            throw new BadRequestException(
                "El rol Administrador no se puede desactivar: sin él nadie podría configurar el sistema");
        }

        rol.Nombre = request.Nombre;
        rol.Descripcion = request.Descripcion;
        rol.Activo = request.Activo;

        await _repository.UpdateAsync(rol);
        return MapToResponse(rol, await _repository.ContarUsuariosAsync(id));
    }

    public async Task<RolResponse> UpdatePermisosAsync(int id, UpdatePermisosRequest request)
    {
        await GetOrThrowAsync(id);

        var permisos = request.Permisos.Select(p => new RolPermiso
        {
            RolId = id,
            Modulo = p.Modulo,
            Ver = p.Ver,
            // Cualquier permiso implica poder ver: sin Ver el modulo no se abre.
            Crear = p.Crear,
            Editar = p.Editar,
            Eliminar = p.Eliminar
        }).ToList();

        foreach (var permiso in permisos.Where(p => p.Crear || p.Editar || p.Eliminar))
        {
            permiso.Ver = true;
        }

        await _repository.ReemplazarPermisosAsync(id, permisos);

        var actualizado = await _repository.GetConPermisosAsync(id);
        return MapToResponse(actualizado!, await _repository.ContarUsuariosAsync(id));
    }

    public async Task DeleteAsync(int id)
    {
        var rol = await GetOrThrowAsync(id);

        if (rol.DelSistema)
        {
            throw new ConflictException("Los roles del sistema no se pueden eliminar");
        }

        var usuarios = await _repository.ContarUsuariosAsync(id);
        if (usuarios > 0)
        {
            throw new ConflictException(
                $"El rol tiene {usuarios} usuario(s) asignado(s). Cámbialos de rol antes de eliminarlo");
        }

        await _repository.DeleteAsync(rol);
    }

    private static bool EsProtegido(Rol rol) => rol.Id == RolAdministradorId;

    private async Task<Rol> GetOrThrowAsync(int id)
    {
        return await _repository.GetConPermisosAsync(id)
            ?? throw new NotFoundException("Rol no encontrado");
    }

    private static RolResponse MapToResponse(Rol rol, int? usuarios = null)
    {
        return new RolResponse
        {
            Id = rol.Id,
            Nombre = rol.Nombre,
            Descripcion = rol.Descripcion,
            Activo = rol.Activo,
            DelSistema = rol.DelSistema,
            Protegido = EsProtegido(rol),
            FechaCreacion = rol.FechaCreacion,
            Usuarios = usuarios ?? rol.Usuarios.Count,
            Permisos = rol.Permisos.Select(p => new RolPermisoResponse
            {
                Modulo = p.Modulo,
                Ver = p.Ver,
                Crear = p.Crear,
                Editar = p.Editar,
                Eliminar = p.Eliminar
            }).ToList()
        };
    }
}
