using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

public class AsistenciaService : IAsistenciaService
{
    private readonly IAsistenciaRepository _repository;
    private readonly IEmpleadoRepository _empleados;
    private readonly IValidator<CrearAsistenciaRequest> _crearValidator;
    private readonly IValidator<EditarAsistenciaRequest> _editarValidator;
    private readonly INotificador _notificador;

    public AsistenciaService(
        IAsistenciaRepository repository,
        IEmpleadoRepository empleados,
        IValidator<CrearAsistenciaRequest> crearValidator,
        IValidator<EditarAsistenciaRequest> editarValidator,
        INotificador notificador)
    {
        _repository = repository;
        _empleados = empleados;
        _crearValidator = crearValidator;
        _editarValidator = editarValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<AsistenciaResponse>> ListarAsync(DateTime desde, DateTime hasta, int? empleadoId) =>
        (await _repository.ListarAsync(desde.Date, hasta.Date, empleadoId)).Select(Map);

    public async Task<ResumenAsistenciaResponse> ResumenAsync(DateTime desde, DateTime hasta, int? empleadoId)
    {
        var activas = (await _repository.ListarAsync(desde.Date, hasta.Date, empleadoId))
            .Where(a => !a.Anulado)
            .ToList();

        return new ResumenAsistenciaResponse
        {
            Presentes = activas.Count(a => a.Estado == EstadoAsistencia.Presente),
            Tardanzas = activas.Count(a => a.Estado == EstadoAsistencia.Tardanza),
            Faltas = activas.Count(a => a.Estado == EstadoAsistencia.Falta),
            Permisos = activas.Count(a => a.Estado == EstadoAsistencia.Permiso),
        };
    }

    public async Task<AsistenciaResponse> CrearAsync(CrearAsistenciaRequest request, int? usuarioId)
    {
        await _crearValidator.ValidateAndThrowAsync(request);

        var empleado = await _empleados.GetByIdAsync(request.EmpleadoId)
            ?? throw new BadRequestException("No existe ese empleado");
        if (!empleado.Activo)
        {
            throw new BadRequestException($"'{empleado.NombreCompleto}' está cesado: no se le puede marcar asistencia");
        }

        var fecha = request.Fecha.Date;
        if (await _repository.ExisteActivaAsync(request.EmpleadoId, fecha))
        {
            throw new ConflictException(
                $"Ya hay una marca de {empleado.NombreCompleto} para el {fecha:dd/MM/yyyy}. Anúlala primero si está mal.");
        }

        var asistencia = new Asistencia
        {
            EmpleadoId = request.EmpleadoId,
            Fecha = fecha,
            Estado = request.Estado,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId,
        };

        await _repository.AddAsync(asistencia);
        var response = Map((await _repository.GetConDetalleAsync(asistencia.Id))!);
        await _notificador.AvisarAsync("asistencia", "creado", response);
        return response;
    }

    public async Task<AsistenciaResponse> EditarAsync(int id, EditarAsistenciaRequest request)
    {
        await _editarValidator.ValidateAndThrowAsync(request);

        var asistencia = await GetOrThrowAsync(id);
        if (asistencia.Anulado)
        {
            throw new BadRequestException("Esta marca está anulada: no se puede editar");
        }

        asistencia.Estado = request.Estado;
        asistencia.Observacion = Limpiar(request.Observacion);

        await _repository.UpdateAsync(asistencia);
        var response = Map(asistencia);
        await _notificador.AvisarAsync("asistencia", "actualizado", response);
        return response;
    }

    public async Task<AsistenciaResponse> AnularAsync(int id)
    {
        var asistencia = await GetOrThrowAsync(id);
        if (asistencia.Anulado)
        {
            throw new BadRequestException("Esta marca ya está anulada");
        }

        asistencia.Anulado = true;
        await _repository.UpdateAsync(asistencia);
        var response = Map(asistencia);
        await _notificador.AvisarAsync("asistencia", "anulado", response);
        return response;
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static AsistenciaResponse Map(Asistencia a) => new()
    {
        Id = a.Id,
        EmpleadoId = a.EmpleadoId,
        Empleado = a.Empleado?.NombreCompleto ?? string.Empty,
        Cargo = a.Empleado?.Cargo,
        Fecha = a.Fecha,
        Estado = a.Estado,
        Observacion = a.Observacion,
        Usuario = a.Usuario?.Nombre,
        FechaRegistro = a.FechaRegistro,
        Anulado = a.Anulado,
    };

    private async Task<Asistencia> GetOrThrowAsync(int id) =>
        await _repository.GetConDetalleAsync(id) ?? throw new NotFoundException($"No existe la asistencia {id}");
}
