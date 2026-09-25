using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

public class EmpleadoService : IEmpleadoService
{
    private readonly IEmpleadoRepository _repository;
    private readonly IValidator<CreateEmpleadoRequest> _createValidator;
    private readonly IValidator<UpdateEmpleadoRequest> _updateValidator;
    private readonly INotificador _notificador;

    public EmpleadoService(
        IEmpleadoRepository repository,
        IValidator<CreateEmpleadoRequest> createValidator,
        IValidator<UpdateEmpleadoRequest> updateValidator,
        INotificador notificador)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<EmpleadoResponse>> GetAllAsync()
    {
        var empleados = await _repository.GetAllAsync();
        var usuarios = await _repository.UsuariosPorEmpleadoAsync();

        // Los inactivos también salen: si desaparecieran de la lista no habría cómo reactivarlos.
        return empleados
            .OrderByDescending(e => e.Activo)
            .ThenBy(e => e.Apellidos)
            .ThenBy(e => e.Nombres)
            .Select(e => Map(e, usuarios));
    }

    public async Task<EmpleadoResponse> GetByIdAsync(int id)
    {
        var empleado = await GetOrThrowAsync(id);
        return Map(empleado, await _repository.UsuariosPorEmpleadoAsync());
    }

    public async Task<IEnumerable<EmpleadoOpcionResponse>> OpcionesAsync()
    {
        var empleados = await _repository.GetAllAsync();
        var usuarios = await _repository.UsuariosPorEmpleadoAsync();

        /*
         * Solo los activos, y el que ya tiene cuenta NO se esconde.
         *
         * Al editar un usuario, su propio empleado tiene que seguir en la lista o el selector
         * saldría en blanco; y ver "ya tiene usuario" al costado explica por qué no se puede
         * elegir, que es mejor que no encontrarlo y no saber por qué.
         */
        return empleados
            .Where(e => e.Activo)
            .OrderBy(e => e.Apellidos)
            .ThenBy(e => e.Nombres)
            .Select(e => new EmpleadoOpcionResponse
            {
                Id = e.Id,
                Documento = e.Documento,
                TipoDoc = e.TipoDoc,
                NombreCompleto = e.NombreCompleto,
                Cargo = e.Cargo,
                Email = e.Email,
                UsuarioId = usuarios.TryGetValue(e.Id, out var u) ? u.Id : null,
            });
    }

    public async Task<EmpleadoResponse> CreateAsync(CreateEmpleadoRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        if (await _repository.ExistsByDocumentoAsync(request.Documento.Trim()))
        {
            throw new ConflictException("Ya existe un empleado con ese documento");
        }

        var empleado = new Empleado();
        Aplicar(empleado, request);

        await _repository.AddAsync(empleado);
        var response = Map(empleado, SinUsuarios);
        await _notificador.AvisarAsync("empleados", "creado", response);
        return response;
    }

    public async Task<EmpleadoResponse> UpdateAsync(int id, UpdateEmpleadoRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var empleado = await GetOrThrowAsync(id);

        if (await _repository.ExistsByDocumentoAsync(request.Documento.Trim(), id))
        {
            throw new ConflictException("Ya existe un empleado con ese documento");
        }

        Aplicar(empleado, request);
        empleado.Activo = request.Activo;

        await _repository.UpdateAsync(empleado);
        var response = Map(empleado, await _repository.UsuariosPorEmpleadoAsync());
        await _notificador.AvisarAsync("empleados", "actualizado", response);
        return response;
    }

    public async Task<EmpleadoResponse> CambiarEstadoAsync(int id, bool activo)
    {
        var empleado = await GetOrThrowAsync(id);

        if (empleado.Activo != activo)
        {
            empleado.Activo = activo;
            await _repository.UpdateAsync(empleado);
            await _notificador.AvisarAsync("empleados", "estado", Map(empleado, SinUsuarios));
        }

        return Map(empleado, await _repository.UsuariosPorEmpleadoAsync());
    }

    public async Task DeleteAsync(int id)
    {
        var empleado = await GetOrThrowAsync(id);

        // Borrarla dejaría al usuario apuntando a una ficha que ya no existe.
        if (await _repository.UsuarioDeAsync(id) is { } usuario)
        {
            throw new ConflictException(
                $"La cuenta de {usuario.Nombre} usa esta ficha. Quítale el empleado a ese usuario, " +
                "o desactiva la ficha en vez de eliminarla.");
        }

        await _repository.DeleteAsync(empleado);
        await _notificador.AvisarAsync("empleados", "eliminado", new { id });
    }

    /// <summary>Para el alta y el cambio de estado: una ficha recién creada no tiene cuenta todavía.</summary>
    private static readonly Dictionary<int, (int Id, string Nombre)> SinUsuarios = [];

    private static void Aplicar(Empleado empleado, EmpleadoRequestBase request)
    {
        empleado.Documento = request.Documento.Trim();
        // El tipo elegido manda; vacío se deduce del largo, igual que en clientes y proveedores.
        empleado.TipoDoc = string.IsNullOrWhiteSpace(request.TipoDoc)
            ? TipoDocumento.Deducir(empleado.Documento)
            : request.TipoDoc;
        empleado.Nombres = request.Nombres.Trim();
        empleado.Apellidos = request.Apellidos.Trim();
        empleado.Telefono = Limpiar(request.Telefono);
        empleado.Email = Limpiar(request.Email);
        empleado.Direccion = Limpiar(request.Direccion);
        empleado.Cargo = Limpiar(request.Cargo);
        empleado.Area = Limpiar(request.Area);
        empleado.FechaIngreso = request.FechaIngreso;
        empleado.FechaCese = request.FechaCese;
        empleado.SueldoSemanal = request.SueldoSemanal is decimal sueldo ? Math.Round(sueldo, 2) : null;
        empleado.Observacion = Limpiar(request.Observacion);
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static EmpleadoResponse Map(Empleado e, IReadOnlyDictionary<int, (int Id, string Nombre)> usuarios)
    {
        usuarios.TryGetValue(e.Id, out var usuario);

        return new EmpleadoResponse
        {
            Id = e.Id,
            Documento = e.Documento,
            TipoDoc = e.TipoDoc,
            Nombres = e.Nombres,
            Apellidos = e.Apellidos,
            NombreCompleto = e.NombreCompleto,
            Telefono = e.Telefono,
            Email = e.Email,
            Direccion = e.Direccion,
            Cargo = e.Cargo,
            Area = e.Area,
            FechaIngreso = e.FechaIngreso,
            FechaCese = e.FechaCese,
            SueldoSemanal = e.SueldoSemanal,
            Observacion = e.Observacion,
            Activo = e.Activo,
            FechaCreacion = e.FechaCreacion,
            UsuarioId = usuario.Id == 0 ? null : usuario.Id,
            Usuario = usuario.Nombre,
        };
    }

    private async Task<Empleado> GetOrThrowAsync(int id) =>
        await _repository.GetByIdAsync(id) ?? throw new NotFoundException($"No existe el empleado {id}");
}
