using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using MySqlConnector;

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
    private readonly IPlanillaService _planillas;

    public AsistenciaService(
        AppDbContext context,
        IAsistenciaRepository repository,
        IEmpleadoRepository empleados,
        IValidator<CrearAsistenciaRequest> crearValidator,
        IValidator<EditarAsistenciaRequest> editarValidator,
        IValidator<MarcarDiaAsistenciaRequest> diaValidator,
        INotificador notificador,
        IPlanillaService planillas)
    {
        _context = context;
        _repository = repository;
        _empleados = empleados;
        _crearValidator = crearValidator;
        _editarValidator = editarValidator;
        _diaValidator = diaValidator;
        _notificador = notificador;
        _planillas = planillas;
    }

    public async Task<IEnumerable<AsistenciaResponse>> ListarAsync(DateTime desde, DateTime hasta, int? empleadoId) =>
        (await _repository.ListarAsync(desde.Date, hasta.Date, empleadoId)).Select(Map);

    public async Task<IEnumerable<EmpleadoAsistenciaResponse>> EmpleadosAsync() =>
        await _context.Empleados
            .AsNoTracking()
            .OrderByDescending(e => e.Activo).ThenBy(e => e.Nombres).ThenBy(e => e.Apellidos)
            .Select(e => new EmpleadoAsistenciaResponse
            {
                Id = e.Id,
                NombreCompleto = (e.Nombres + " " + e.Apellidos).Trim(),
                Cargo = e.Cargo,
                Activo = e.Activo,
                FechaIngreso = e.FechaIngreso,
                FechaCese = e.FechaCese,
            })
            .ToListAsync();

    public async Task<ResumenAsistenciaResponse> ResumenAsync(DateTime desde, DateTime hasta, int? empleadoId)
    {
        // Contado en la base: antes se volvía a traer la lista entera, con
        // empleado y usuario, solo para contarla.
        var d = desde.Date;
        var h = hasta.Date;
        var porEstado = await _context.Asistencias
            .Where(a => !a.Anulado && a.Fecha >= d && a.Fecha <= h
                        && (empleadoId == null || a.EmpleadoId == empleadoId))
            .GroupBy(a => a.Estado)
            .Select(g => new { Estado = g.Key, Cantidad = g.Count() })
            .ToDictionaryAsync(x => x.Estado, x => x.Cantidad);

        return new ResumenAsistenciaResponse
        {
            Presentes = porEstado.GetValueOrDefault(EstadoAsistencia.Presente),
            Tardanzas = porEstado.GetValueOrDefault(EstadoAsistencia.Tardanza),
            Faltas = porEstado.GetValueOrDefault(EstadoAsistencia.Falta),
            Permisos = porEstado.GetValueOrDefault(EstadoAsistencia.Permiso),
        };
    }

    public async Task<AsistenciaResponse> CrearAsync(CrearAsistenciaRequest request, int? usuarioId)
    {
        await _crearValidator.ValidateAndThrowAsync(request);

        var empleado = await _empleados.GetByIdAsync(request.EmpleadoId)
            ?? throw new BadRequestException("No existe ese empleado");

        var fecha = request.Fecha.Date;
        ExigirEnContrato(empleado, fecha);

        var asistencia = await SinDuplicarAsync(() => _planillas.CambiarDiasAsync([fecha], async () =>
        {
            if (await _repository.ExisteActivaAsync(request.EmpleadoId, fecha))
            {
                throw new ConflictException(
                    $"Ya hay una marca de {empleado.NombreCompleto} para el {fecha:dd/MM/yyyy}. Anúlala primero si está mal.");
            }

            var nueva = new Asistencia
            {
                EmpleadoId = request.EmpleadoId,
                Fecha = fecha,
                Estado = request.Estado,
                Observacion = Limpiar(request.Observacion),
                UsuarioId = usuarioId,
            };
            await _repository.AddAsync(nueva);
            return nueva;
        }));

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

        await _planillas.CambiarDiasAsync([asistencia.Fecha], async () =>
        {
            asistencia.Estado = request.Estado;
            asistencia.Observacion = Limpiar(request.Observacion);
            await _repository.UpdateAsync(asistencia);
            return asistencia;
        });

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

        var (creadas, corregidas) = await SinDuplicarAsync(() => _planillas.CambiarDiasAsync([fecha], async () =>
        {
            var empleados = await _context.Empleados
                .Where(e => ids.Contains(e.Id))
                .ToDictionaryAsync(e => e.Id);

            var existentes = (await _context.Asistencias
                    .Where(a => ids.Contains(a.EmpleadoId) && a.Fecha == fecha && !a.Anulado)
                    .ToListAsync())
                .GroupBy(a => a.EmpleadoId)
                .ToDictionary(g => g.Key, g => g.First());

            int nuevas = 0, cambiadas = 0;

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
                    cambiadas++;
                    continue;
                }

                ExigirEnContrato(empleado, fecha);

                _context.Asistencias.Add(new Asistencia
                {
                    EmpleadoId = empleado.Id,
                    Fecha = fecha,
                    Estado = marca.Estado,
                    Observacion = observacion,
                    UsuarioId = usuarioId,
                });
                nuevas++;
            }

            await _context.SaveChangesAsync();
            return (nuevas, cambiadas);
        }));

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

        await _planillas.CambiarDiasAsync([asistencia.Fecha], async () =>
        {
            asistencia.Anulado = true;
            await _repository.UpdateAsync(asistencia);
            return asistencia;
        });

        var response = Map(asistencia);
        await _notificador.AvisarAsync("asistencia", "anulado", response);
        return response;
    }

    /// <summary>
    /// Solo se marca un día en que trabajaba aquí: ya había entrado y todavía no cesaba. Quien está
    /// desactivado sin fecha de cese no se marca: no se sabe hasta cuándo trabajó.
    /// </summary>
    private static void ExigirEnContrato(Empleado empleado, DateTime fecha)
    {
        if (empleado.FechaIngreso is DateTime ingreso && fecha < ingreso.Date)
        {
            throw new BadRequestException(
                $"{empleado.NombreCompleto} entró el {ingreso:dd/MM/yyyy}: el {fecha:dd/MM/yyyy} todavía no trabajaba");
        }

        if (empleado.FechaCese is DateTime cese && fecha > cese.Date)
        {
            throw new BadRequestException(
                $"{empleado.NombreCompleto} cesó el {cese:dd/MM/yyyy}: el {fecha:dd/MM/yyyy} ya no trabajaba");
        }

        if (!empleado.Activo && empleado.FechaCese is null)
        {
            throw new BadRequestException(
                $"'{empleado.NombreCompleto}' está desactivado: ponle su fecha de cese para marcarle los días que trabajó");
        }
    }

    /// <summary>
    /// Dos personas marcando al mismo empleado el mismo día a la vez: la base deja pasar una sola
    /// marca y a la otra se le explica.
    /// </summary>
    private static async Task<T> SinDuplicarAsync<T>(Func<Task<T>> guardar)
    {
        try
        {
            return await guardar();
        }
        catch (DbUpdateException e) when (e.InnerException is MySqlException { ErrorCode: MySqlErrorCode.DuplicateKeyEntry })
        {
            throw new ConflictException("Alguien acaba de marcar a ese empleado ese mismo día: vuelve a cargar la lista");
        }
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
