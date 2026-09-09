using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Cómo está un documento respecto a hoy.
/// </summary>
public static class EstadoVencimiento
{
    public const string Vencido = "vencido";
    public const string PorVencer = "porVencer";
    public const string AlDia = "alDia";
    public const string SinFecha = "sinFecha";
}

/// <summary>
/// Los vehículos, sus tipos y sus conductores.
///
/// El peso de esta pantalla no está en el alta, que es un formulario más, sino
/// en los vencimientos: SOAT, revisión técnica y licencia. Un camión que sale
/// con el SOAT vencido es una multa y la mercadería inmovilizada, así que el
/// estado de cada documento se calcula aquí —en un solo sitio— y de ahí lo
/// toman la lista, el detalle y las alertas.
/// </summary>
public class FlotaService : IFlotaService
{
    /// <summary>
    /// Desde cuándo se avisa. Treinta días es el mismo plazo que usan las
    /// alertas de lotes por vencer: da tiempo a sacar cita para la revisión
    /// sin llenar la bandeja de avisos que no corren prisa.
    /// </summary>
    public const int DiasAviso = 30;

    private readonly AppDbContext _context;
    private readonly INotificador _notificador;

    public FlotaService(AppDbContext context, INotificador notificador)
    {
        _context = context;
        _notificador = notificador;
    }

    /// <summary>
    /// En qué situación está una fecha de vencimiento.
    ///
    /// Se compara por día y no por instante: un SOAT que vence hoy vale hoy,
    /// y con horas de por medio saldría vencido desde la madrugada.
    /// </summary>
    public static VencimientoResponse Evaluar(string nombre, DateTime? vence, DateTime hoy)
    {
        if (vence is null)
        {
            return new VencimientoResponse
            {
                Nombre = nombre,
                Estado = EstadoVencimiento.SinFecha,
            };
        }

        var dias = (vence.Value.Date - hoy.Date).Days;

        return new VencimientoResponse
        {
            Nombre = nombre,
            Vence = vence,
            DiasRestantes = dias,
            Estado = dias < 0
                ? EstadoVencimiento.Vencido
                : dias <= DiasAviso
                    ? EstadoVencimiento.PorVencer
                    : EstadoVencimiento.AlDia,
        };
    }

    /// <summary>
    /// El peor de todos: lo que decide si la unidad puede salir.
    ///
    /// "Sin fecha" no cuenta como problema — hay vehículos sin permiso
    /// municipal porque no les aplica — pero tampoco como estar al día: si no
    /// hay ninguna fecha, no hay nada que afirmar.
    /// </summary>
    private static string Peor(IEnumerable<VencimientoResponse> vencimientos)
    {
        var conFecha = vencimientos.Where(v => v.Estado != EstadoVencimiento.SinFecha).ToList();
        if (conFecha.Count == 0) return EstadoVencimiento.SinFecha;

        if (conFecha.Any(v => v.Estado == EstadoVencimiento.Vencido)) return EstadoVencimiento.Vencido;
        if (conFecha.Any(v => v.Estado == EstadoVencimiento.PorVencer)) return EstadoVencimiento.PorVencer;
        return EstadoVencimiento.AlDia;
    }

    // ------------------------------------------------------------------
    // Tipos de vehículo
    // ------------------------------------------------------------------

    public async Task<IEnumerable<TipoVehiculoResponse>> GetTiposAsync()
    {
        var tipos = await _context.TiposVehiculo
            .AsNoTracking()
            .Select(t => new TipoVehiculoResponse
            {
                Id = t.Id,
                Nombre = t.Nombre,
                Descripcion = t.Descripcion,
                CapacidadKgReferencia = t.CapacidadKgReferencia,
                Activo = t.Activo,
                Vehiculos = t.Vehiculos.Count,
            })
            .OrderBy(t => t.Nombre)
            .ToListAsync();

        return tipos;
    }

    public async Task<TipoVehiculoResponse> GetTipoAsync(int id) =>
        (await GetTiposAsync()).FirstOrDefault(t => t.Id == id)
        ?? throw new NotFoundException("Tipo de vehículo no encontrado");

    public async Task<TipoVehiculoResponse> CrearTipoAsync(TipoVehiculoRequest request)
    {
        var nombre = request.Nombre.Trim();
        if (nombre.Length == 0) throw new BadRequestException("Ponle un nombre al tipo de vehículo");

        if (await _context.TiposVehiculo.AnyAsync(t => t.Nombre == nombre))
            throw new ConflictException("Ya existe un tipo de vehículo con ese nombre");

        var tipo = new TipoVehiculo
        {
            Nombre = nombre,
            Descripcion = request.Descripcion?.Trim(),
            CapacidadKgReferencia = request.CapacidadKgReferencia,
            Activo = request.Activo,
        };

        _context.TiposVehiculo.Add(tipo);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("flota", "tipoCreado", new { tipo.Id });

        return await GetTipoAsync(tipo.Id);
    }

    public async Task<TipoVehiculoResponse> ActualizarTipoAsync(int id, TipoVehiculoRequest request)
    {
        var tipo = await _context.TiposVehiculo.FirstOrDefaultAsync(t => t.Id == id)
            ?? throw new NotFoundException("Tipo de vehículo no encontrado");

        var nombre = request.Nombre.Trim();
        if (nombre.Length == 0) throw new BadRequestException("Ponle un nombre al tipo de vehículo");

        if (await _context.TiposVehiculo.AnyAsync(t => t.Nombre == nombre && t.Id != id))
            throw new ConflictException("Ya existe un tipo de vehículo con ese nombre");

        tipo.Nombre = nombre;
        tipo.Descripcion = request.Descripcion?.Trim();
        tipo.CapacidadKgReferencia = request.CapacidadKgReferencia;
        tipo.Activo = request.Activo;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("flota", "tipoActualizado", new { tipo.Id });

        return await GetTipoAsync(id);
    }

    public async Task EliminarTipoAsync(int id)
    {
        var tipo = await _context.TiposVehiculo.FirstOrDefaultAsync(t => t.Id == id)
            ?? throw new NotFoundException("Tipo de vehículo no encontrado");

        var enUso = await _context.Vehiculos.CountAsync(v => v.TipoVehiculoId == id);
        if (enUso > 0)
        {
            throw new ConflictException(
                $"Hay {enUso} vehículo(s) de este tipo. Desactívalo en lugar de eliminarlo");
        }

        _context.TiposVehiculo.Remove(tipo);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("flota", "tipoEliminado", new { id });
    }

    // ------------------------------------------------------------------
    // Vehículos
    // ------------------------------------------------------------------

    public async Task<IEnumerable<VehiculoResponse>> GetVehiculosAsync()
    {
        var hoy = DateTime.UtcNow;

        var vehiculos = await _context.Vehiculos
            .AsNoTracking()
            .Include(v => v.TipoVehiculo)
            .Include(v => v.Conductor)
            .OrderBy(v => v.Placa)
            .ToListAsync();

        return vehiculos.Select(v => Mapear(v, hoy)).ToList();
    }

    public async Task<VehiculoResponse> GetVehiculoAsync(int id)
    {
        var vehiculo = await _context.Vehiculos
            .AsNoTracking()
            .Include(v => v.TipoVehiculo)
            .Include(v => v.Conductor)
            .FirstOrDefaultAsync(v => v.Id == id)
            ?? throw new NotFoundException("Vehículo no encontrado");

        return Mapear(vehiculo, DateTime.UtcNow);
    }

    public async Task<VehiculoResponse> CrearVehiculoAsync(VehiculoRequest request)
    {
        var placa = NormalizarPlaca(request.Placa);

        if (await _context.Vehiculos.AnyAsync(v => v.Placa == placa))
            throw new ConflictException($"Ya hay un vehículo con la placa {placa}");

        await ValidarReferenciasAsync(request);

        var vehiculo = new Vehiculo { Placa = placa };
        Aplicar(vehiculo, request);

        _context.Vehiculos.Add(vehiculo);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("flota", "creado", new { vehiculo.Id });

        return await GetVehiculoAsync(vehiculo.Id);
    }

    public async Task<VehiculoResponse> ActualizarVehiculoAsync(int id, VehiculoRequest request)
    {
        var vehiculo = await _context.Vehiculos.FirstOrDefaultAsync(v => v.Id == id)
            ?? throw new NotFoundException("Vehículo no encontrado");

        var placa = NormalizarPlaca(request.Placa);
        if (await _context.Vehiculos.AnyAsync(v => v.Placa == placa && v.Id != id))
            throw new ConflictException($"Ya hay un vehículo con la placa {placa}");

        await ValidarReferenciasAsync(request);

        vehiculo.Placa = placa;
        Aplicar(vehiculo, request);

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("flota", "actualizado", new { vehiculo.Id });

        return await GetVehiculoAsync(id);
    }

    public async Task EliminarVehiculoAsync(int id)
    {
        var vehiculo = await _context.Vehiculos.FirstOrDefaultAsync(v => v.Id == id)
            ?? throw new NotFoundException("Vehículo no encontrado");

        _context.Vehiculos.Remove(vehiculo);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("flota", "eliminado", new { id });
    }

    public async Task<ResumenFlotaResponse> ResumenFlotaAsync()
    {
        var vehiculos = (await GetVehiculosAsync()).ToList();

        return new ResumenFlotaResponse
        {
            Vehiculos = vehiculos.Count,
            Activos = vehiculos.Count(v => v.Activo),
            ConDocumentoVencido = vehiculos.Count(v => v.EstadoDocumentos == EstadoVencimiento.Vencido),
            PorVencer = vehiculos.Count(v => v.EstadoDocumentos == EstadoVencimiento.PorVencer),
        };
    }

    // ------------------------------------------------------------------
    // Conductores
    // ------------------------------------------------------------------

    public async Task<IEnumerable<ConductorResponse>> GetConductoresAsync()
    {
        var hoy = DateTime.UtcNow;

        var conductores = await _context.Conductores
            .AsNoTracking()
            .Include(c => c.Vehiculos)
            .OrderBy(c => c.Nombre)
            .ToListAsync();

        return conductores.Select(c => Mapear(c, hoy)).ToList();
    }

    public async Task<ConductorResponse> GetConductorAsync(int id)
    {
        var conductor = await _context.Conductores
            .AsNoTracking()
            .Include(c => c.Vehiculos)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException("Conductor no encontrado");

        return Mapear(conductor, DateTime.UtcNow);
    }

    public async Task<ConductorResponse> CrearConductorAsync(ConductorRequest request)
    {
        var documento = request.Documento.Trim();
        var nombre = request.Nombre.Trim();

        if (nombre.Length == 0) throw new BadRequestException("Ponle el nombre del conductor");
        if (documento.Length == 0) throw new BadRequestException("El documento es obligatorio");

        if (await _context.Conductores.AnyAsync(c => c.Documento == documento))
            throw new ConflictException($"Ya hay un conductor con el documento {documento}");

        var conductor = new Conductor { Nombre = nombre, Documento = documento };
        Aplicar(conductor, request);

        _context.Conductores.Add(conductor);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("conductores", "creado", new { conductor.Id });

        return await GetConductorAsync(conductor.Id);
    }

    public async Task<ConductorResponse> ActualizarConductorAsync(int id, ConductorRequest request)
    {
        var conductor = await _context.Conductores.FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException("Conductor no encontrado");

        var documento = request.Documento.Trim();
        var nombre = request.Nombre.Trim();

        if (nombre.Length == 0) throw new BadRequestException("Ponle el nombre del conductor");
        if (documento.Length == 0) throw new BadRequestException("El documento es obligatorio");

        if (await _context.Conductores.AnyAsync(c => c.Documento == documento && c.Id != id))
            throw new ConflictException($"Ya hay un conductor con el documento {documento}");

        conductor.Nombre = nombre;
        conductor.Documento = documento;
        Aplicar(conductor, request);

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("conductores", "actualizado", new { conductor.Id });

        return await GetConductorAsync(id);
    }

    public async Task EliminarConductorAsync(int id)
    {
        var conductor = await _context.Conductores.FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException("Conductor no encontrado");

        // Los vehículos que tuviera asignados quedan sin conductor habitual, no
        // se van con él: la FK está en SetNull.
        _context.Conductores.Remove(conductor);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("conductores", "eliminado", new { id });
    }

    public async Task<ResumenConductoresResponse> ResumenConductoresAsync()
    {
        var conductores = (await GetConductoresAsync()).ToList();

        return new ResumenConductoresResponse
        {
            Conductores = conductores.Count,
            Activos = conductores.Count(c => c.Activo),
            ConLicenciaVencida = conductores.Count(c => c.EstadoDocumentos == EstadoVencimiento.Vencido),
            PorVencer = conductores.Count(c => c.EstadoDocumentos == EstadoVencimiento.PorVencer),
        };
    }

    // ------------------------------------------------------------------

    /// <summary>Sin espacios y en mayúsculas: "abc-123" y "ABC123" son la misma placa.</summary>
    private static string NormalizarPlaca(string placa)
    {
        var limpia = placa.Trim().ToUpperInvariant().Replace(" ", string.Empty);
        if (limpia.Length == 0) throw new BadRequestException("La placa es obligatoria");
        return limpia;
    }

    private async Task ValidarReferenciasAsync(VehiculoRequest request)
    {
        if (!await _context.TiposVehiculo.AnyAsync(t => t.Id == request.TipoVehiculoId))
            throw new BadRequestException("Elige el tipo de vehículo");

        if (request.ConductorId is int conductorId
            && !await _context.Conductores.AnyAsync(c => c.Id == conductorId))
        {
            throw new BadRequestException("El conductor elegido no existe");
        }
    }

    private static void Aplicar(Vehiculo vehiculo, VehiculoRequest request)
    {
        vehiculo.TipoVehiculoId = request.TipoVehiculoId;
        vehiculo.Marca = request.Marca?.Trim();
        vehiculo.Modelo = request.Modelo?.Trim();
        vehiculo.Anio = request.Anio;
        vehiculo.Color = request.Color?.Trim();
        vehiculo.CapacidadKg = request.CapacidadKg;
        vehiculo.SoatNumero = request.SoatNumero?.Trim();
        vehiculo.SoatVence = request.SoatVence;
        vehiculo.RevisionTecnicaVence = request.RevisionTecnicaVence;
        vehiculo.PermisoCirculacionVence = request.PermisoCirculacionVence;
        vehiculo.Foto = request.Foto;
        vehiculo.ConductorId = request.ConductorId;
        vehiculo.Observacion = request.Observacion?.Trim();
        vehiculo.Activo = request.Activo;
    }

    private static void Aplicar(Conductor conductor, ConductorRequest request)
    {
        conductor.Telefono = request.Telefono?.Trim();
        conductor.Direccion = request.Direccion?.Trim();
        conductor.LicenciaNumero = request.LicenciaNumero?.Trim();
        conductor.LicenciaCategoria = request.LicenciaCategoria?.Trim();
        conductor.LicenciaVence = request.LicenciaVence;
        conductor.Foto = request.Foto;
        conductor.FechaIngreso = request.FechaIngreso;
        conductor.Observacion = request.Observacion?.Trim();
        conductor.Activo = request.Activo;
    }

    private static VehiculoResponse Mapear(Vehiculo v, DateTime hoy)
    {
        var vencimientos = new List<VencimientoResponse>
        {
            Evaluar("SOAT", v.SoatVence, hoy),
            Evaluar("Revisión técnica", v.RevisionTecnicaVence, hoy),
            Evaluar("Permiso de circulación", v.PermisoCirculacionVence, hoy),
        };

        return new VehiculoResponse
        {
            Id = v.Id,
            Placa = v.Placa,
            TipoVehiculoId = v.TipoVehiculoId,
            TipoVehiculo = v.TipoVehiculo?.Nombre ?? string.Empty,
            Marca = v.Marca,
            Modelo = v.Modelo,
            Anio = v.Anio,
            Color = v.Color,
            CapacidadKg = v.CapacidadKg,
            SoatNumero = v.SoatNumero,
            SoatVence = v.SoatVence,
            RevisionTecnicaVence = v.RevisionTecnicaVence,
            PermisoCirculacionVence = v.PermisoCirculacionVence,
            Foto = v.Foto,
            ConductorId = v.ConductorId,
            Conductor = v.Conductor?.Nombre,
            Observacion = v.Observacion,
            Activo = v.Activo,
            FechaCreacion = v.FechaCreacion,
            Vencimientos = vencimientos,
            EstadoDocumentos = Peor(vencimientos),
        };
    }

    private static ConductorResponse Mapear(Conductor c, DateTime hoy)
    {
        var vencimientos = new List<VencimientoResponse> { Evaluar("Licencia", c.LicenciaVence, hoy) };

        return new ConductorResponse
        {
            Id = c.Id,
            Nombre = c.Nombre,
            Documento = c.Documento,
            Telefono = c.Telefono,
            Direccion = c.Direccion,
            LicenciaNumero = c.LicenciaNumero,
            LicenciaCategoria = c.LicenciaCategoria,
            LicenciaVence = c.LicenciaVence,
            Foto = c.Foto,
            FechaIngreso = c.FechaIngreso,
            Observacion = c.Observacion,
            Activo = c.Activo,
            FechaCreacion = c.FechaCreacion,
            Vehiculos = c.Vehiculos.Select(v => v.Placa).OrderBy(p => p).ToList(),
            Vencimientos = vencimientos,
            EstadoDocumentos = Peor(vencimientos),
        };
    }
}
