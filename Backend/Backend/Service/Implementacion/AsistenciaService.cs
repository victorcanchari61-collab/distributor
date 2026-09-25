using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class AsistenciaService : IAsistenciaService
{
    private readonly AppDbContext _context;
    private readonly IAsistenciaRepository _repository;
    private readonly IEmpleadoRepository _empleados;
    private readonly IValidator<CrearAsistenciaRequest> _crearValidator;
    private readonly IValidator<EditarAsistenciaRequest> _editarValidator;
    private readonly IValidator<MarcarDiaAsistenciaRequest> _diaValidator;
    private readonly INotificador _notificador;

    public AsistenciaService(
        AppDbContext context,
        IAsistenciaRepository repository,
        IEmpleadoRepository empleados,
        IValidator<CrearAsistenciaRequest> crearValidator,
        IValidator<EditarAsistenciaRequest> editarValidator,
        IValidator<MarcarDiaAsistenciaRequest> diaValidator,
        INotificador notificador)
    {
        _context = context;
        _repository = repository;
        _empleados = empleados;
        _crearValidator = crearValidator;
        _editarValidator = editarValidator;
        _diaValidator = diaValidator;
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

    public async Task<MarcarDiaAsistenciaResponse> MarcarDiaAsync(
        MarcarDiaAsistenciaRequest request, int? usuarioId, bool puedeCorregir)
    {
        await _diaValidator.ValidateAndThrowAsync(request);

        var fecha = request.Fecha.Date;
        var ids = request.Marcas.Select(m => m.EmpleadoId).ToList();

        var empleados = await _context.Empleados
            .Where(e => ids.Contains(e.Id))
            .ToDictionaryAsync(e => e.Id);

        var existentes = (await _context.Asistencias
                .Where(a => ids.Contains(a.EmpleadoId) && a.Fecha == fecha && !a.Anulado)
                .ToListAsync())
            .GroupBy(a => a.EmpleadoId)
            .ToDictionary(g => g.Key, g => g.First());

        int creadas = 0, corregidas = 0;

        // Todo se valida antes de guardar: o se guarda la lista entera o nada.
        foreach (var marca in request.Marcas)
        {
            if (!empleados.TryGetValue(marca.EmpleadoId, out var empleado))
            {
                throw new BadRequestException("Uno de los empleados de la lista no existe");
            }

            var observacion = Limpiar(marca.Observacion);

            if (existentes.TryGetValue(marca.EmpleadoId, out var actual))
            {
                if (actual.Estado == marca.Estado && actual.Observacion == observacion) continue;

                if (!puedeCorregir)
                {
                    throw new ForbiddenException(
                        $"No tienes permiso para corregir la marca de {empleado.NombreCompleto}");
                }

                actual.Estado = marca.Estado;
                actual.Observacion = observacion;
                corregidas++;
                continue;
            }

            if (!empleado.Activo)
            {
                throw new BadRequestException($"'{empleado.NombreCompleto}' está cesado: no se le puede marcar asistencia");
            }

            _context.Asistencias.Add(new Asistencia
            {
                EmpleadoId = empleado.Id,
                Fecha = fecha,
                Estado = marca.Estado,
                Observacion = observacion,
                UsuarioId = usuarioId,
            });
            creadas++;
        }

        await _context.SaveChangesAsync();

        if (creadas + corregidas > 0)
        {
            await _notificador.AvisarAsync("asistencia", "dia", new { fecha, creadas, corregidas });
        }

        return new MarcarDiaAsistenciaResponse { Creadas = creadas, Corregidas = corregidas };
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
