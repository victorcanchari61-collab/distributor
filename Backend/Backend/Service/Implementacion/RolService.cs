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
    private readonly INotificador _notificador;
    private readonly IPermisoService _permisos;

    public RolService(IRolRepository repository,
        IValidator<CreateRolRequest> createValidator,
        IValidator<UpdateRolRequest> updateValidator,
        INotificador notificador,
        IPermisoService permisos)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _notificador = notificador;
        _permisos = permisos;
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
        var response = MapToResponse(rol);
        await _notificador.AvisarAsync("roles", "creado", response);
        return response;
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
        var response = MapToResponse(rol, await _repository.ContarUsuariosAsync(id));
        await _notificador.AvisarAsync("roles", "actualizado", response);
        return response;
    }

    public async Task<RolResponse> UpdatePermisosAsync(int id, UpdatePermisosRequest request)
    {
        await GetOrThrowAsync(id);

        // Solo entra lo que el catalogo reconoce: un submodulo mal escrito o
        // una accion que ese submodulo no admite no deben llegar a la base.
        var pedidos = request.Permisos
            .Where(p => CatalogoPermisos.EsValido(p.Submodulo, p.Accion))
            .Select(p => (p.Submodulo, p.Accion))
            .ToHashSet();

        // Cualquier accion implica poder ver: sin Ver, la pantalla no se abre
        // y el permiso quedaria concedido pero inalcanzable.
        foreach (var (submodulo, _) in pedidos.ToList())
        {
            pedidos.Add((submodulo, Accion.Ver));
        }

        var permisos = pedidos
            .Select(p => new RolPermiso { RolId = id, Submodulo = p.Item1, Accion = p.Item2 })
            .ToList();

        await _repository.ReemplazarPermisosAsync(id, permisos);

        // Sin esto el cambio no se notaria hasta que venciera la caché, y quien
        // acaba de configurar el rol creeria que no se guardo.
        _permisos.OlvidarRol(id);

        var actualizado = await _repository.GetConPermisosAsync(id);
        var response = MapToResponse(actualizado!, await _repository.ContarUsuariosAsync(id));
        await _notificador.AvisarAsync("roles", "permisos", response);

        // Tambien por "permisos": es lo que escuchan las sesiones abiertas para
        // rehacer su menu. Sin esto, a quien acaban de darle una pantalla le
        // sigue sin aparecer hasta que recargue.
        await _notificador.AvisarAsync("permisos", "rol", new { rolId = id });
        return response;
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
        await _notificador.AvisarAsync("roles", "eliminado", new { id });
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
                Submodulo = p.Submodulo,
                Accion = p.Accion,
            }).ToList()
        };
    }
}
