using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class AdelantoService : IAdelantoService
{
    private readonly AppDbContext _context;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IPlanillaService _planillas;
    private readonly IValidator<CrearAdelantoRequest> _crearValidator;
    private readonly IValidator<PlanAdelantoRequest> _planValidator;
    private readonly INotificador _notificador;

    public AdelantoService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IPlanillaService planillas,
        IValidator<CrearAdelantoRequest> crearValidator,
        IValidator<PlanAdelantoRequest> planValidator,
        INotificador notificador)
    {
        _context = context;
        _cuentas = cuentas;
        _planillas = planillas;
        _crearValidator = crearValidator;
        _planValidator = planValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<AdelantoFilaResponse>> ListarAsync() =>
        await _context.AdelantosEmpleado
            .AsNoTracking()
            .OrderByDescending(a => a.Fecha).ThenByDescending(a => a.Id)
            .Select(a => new AdelantoFilaResponse
            {
                Id = a.Id,
                EmpleadoId = a.EmpleadoId,
                Empleado = a.Empleado!.Nombres + " " + a.Empleado.Apellidos,
                Fecha = a.Fecha,
                Monto = a.Monto,
                Descontado = a.MontoDescontado,
                Saldo = a.Estado == EstadoAdelanto.Anulado ? 0 : a.Monto - a.MontoDescontado,
                DescontarDesde = a.DescontarDesde,
                CuotaSemanal = a.CuotaSemanal,
                Estado = a.Estado,
                CuentaFinanciera = a.CuentaFinanciera!.Nombre,
            })
            .ToListAsync();

    public async Task<ResumenAdelantosResponse> ResumenAsync()
    {
        var hoy = Zona.Hoy;
        var inicioMes = new DateTime(hoy.Year, hoy.Month, 1);
        var vigentes = _context.AdelantosEmpleado.Where(a => a.Estado == EstadoAdelanto.Pendiente);

        return new ResumenAdelantosResponse
        {
            SaldoPendiente = await vigentes.SumAsync(a => a.Monto - a.MontoDescontado),
            Vigentes = await vigentes.CountAsync(),
            Empleados = await vigentes.Select(a => a.EmpleadoId).Distinct().CountAsync(),
            EntregadoMes = await _context.AdelantosEmpleado
                .Where(a => a.Estado != EstadoAdelanto.Anulado && a.Fecha >= inicioMes && a.Fecha <= hoy)
                .SumAsync(a => a.Monto),
        };
    }

    public async Task<AdelantoResponse> GetAsync(int id)
    {
        var a = await _context.AdelantosEmpleado
            .AsNoTracking()
            .Include(x => x.Empleado)
            .Include(x => x.CuentaFinanciera)
            .Include(x => x.Usuario)
            .FirstOrDefaultAsync(x => x.Id == id)
            ?? throw new NotFoundException($"No existe el adelanto {id}");

        // Solo lo descontado en planillas pagadas: una anulada ya devolvió su parte.
        var descuentos = await _context.Set<PlanillaAdelanto>()
            .AsNoTracking()
            .Where(p => p.AdelantoEmpleadoId == id && p.PlanillaDetalle!.PlanillaSemanal!.Estado == EstadoPlanilla.Pagada)
            .OrderBy(p => p.PlanillaDetalle!.PlanillaSemanal!.Desde)
            .Select(p => new AdelantoDescuentoResponse
            {
                PlanillaId = p.PlanillaDetalle!.PlanillaSemanalId,
                Desde = p.PlanillaDetalle.PlanillaSemanal!.Desde,
                Hasta = p.PlanillaDetalle.PlanillaSemanal.Hasta,
                Monto = p.Monto,
                FechaPago = p.PlanillaDetalle.PlanillaSemanal.FechaPago,
            })
            .ToListAsync();

        return new AdelantoResponse
        {
            Id = a.Id,
            EmpleadoId = a.EmpleadoId,
            Empleado = a.Empleado?.NombreCompleto ?? string.Empty,
            Cargo = a.Empleado?.Cargo,
            Fecha = a.Fecha,
            Monto = a.Monto,
            Descontado = a.MontoDescontado,
            Saldo = a.Estado == EstadoAdelanto.Anulado ? 0 : a.Saldo,
            DescontarDesde = a.DescontarDesde,
            CuotaSemanal = a.CuotaSemanal,
            Estado = a.Estado,
            CuentaFinanciera = a.CuentaFinanciera?.Nombre,
            Observacion = a.Observacion,
            Usuario = a.Usuario?.Nombre,
            FechaCreacion = a.FechaCreacion,
            Descuentos = descuentos,
        };
    }

    public async Task<IEnumerable<EmpleadoAdelantoResponse>> EmpleadosAsync() =>
        await _context.Empleados
            .AsNoTracking()
            .Where(e => e.Activo)
            .OrderBy(e => e.Nombres).ThenBy(e => e.Apellidos)
            .Select(e => new EmpleadoAdelantoResponse
            {
                Id = e.Id,
                NombreCompleto = (e.Nombres + " " + e.Apellidos).Trim(),
                Cargo = e.Cargo,
                SueldoSemanal = e.SueldoSemanal,
                SaldoAdelantos = _context.AdelantosEmpleado
                    .Where(a => a.EmpleadoId == e.Id && a.Estado == EstadoAdelanto.Pendiente)
                    .Sum(a => (decimal?)(a.Monto - a.MontoDescontado)) ?? 0,
            })
            .ToListAsync();

    public Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync() => _planillas.CuentasAsync();

    public async Task<AdelantoResponse> CrearAsync(CrearAdelantoRequest request, int? usuarioId)
    {
        await _crearValidator.ValidateAndThrowAsync(request);

        var empleado = await _context.Empleados.AsNoTracking().FirstOrDefaultAsync(e => e.Id == request.EmpleadoId)
            ?? throw new BadRequestException("No existe ese empleado");
        if (!empleado.Activo)
        {
            throw new BadRequestException($"'{empleado.NombreCompleto}' está desactivado: no se le da un adelanto");
        }

        var cuenta = await _context.CuentasFinancieras.AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == request.CuentaFinancieraId)
            ?? throw new BadRequestException("No existe esa cuenta");
        if (!cuenta.Activo) throw new BadRequestException("Esa cuenta está desactivada");

        var hoy = Zona.Hoy;
        var fecha = (request.Fecha ?? hoy).Date;
        if (fecha > hoy) throw new BadRequestException("La fecha no puede ser futura: es el día en que se le dio la plata");

        var monto = Math.Round(request.Monto, 2);
        var desde = await ExigirSemanaAbiertaAsync(request.DescontarDesde ?? fecha, fecha);
        var cuota = Cuota(request.CuotaSemanal, monto);

        var id = await _planillas.CambiarAdelantosAsync(async () =>
        {
            var adelanto = new AdelantoEmpleado
            {
                EmpleadoId = empleado.Id,
                Fecha = fecha,
                Monto = monto,
                DescontarDesde = desde,
                CuotaSemanal = cuota,
                CuentaFinancieraId = cuenta.Id,
                Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
                UsuarioId = usuarioId,
            };
            _context.AdelantosEmpleado.Add(adelanto);
            await _context.SaveChangesAsync();

            // La plata sale ya: hoy, o al mediodía del día en que se dio si se registra después.
            var momento = fecha == hoy ? DateTime.UtcNow : Zona.AUtc(fecha.AddHours(12));
            var movimiento = await _cuentas.PostearAsync(
                cuenta.Id, TipoMovimientoCuenta.Egreso, monto,
                DocumentoOrigenMovimiento.AdelantoEmpleado, adelanto.Id, usuarioId, momento,
                $"Adelanto a {empleado.NombreCompleto}");
            adelanto.MovimientoCuentaId = movimiento.Id;
            await _context.SaveChangesAsync();
            return adelanto.Id;
        });

        var response = await GetAsync(id);
        await _notificador.AvisarAsync("adelantos", "creado", new { id });
        await _notificador.AvisarAsync("cuentasfinancieras", "movimiento", new { cuenta.Id });
        return response;
    }

    public async Task<AdelantoResponse> CambiarPlanAsync(int id, PlanAdelantoRequest request)
    {
        await _planValidator.ValidateAndThrowAsync(request);

        await _planillas.CambiarAdelantosAsync(async () =>
        {
            // Leído ya con las planillas bloqueadas: nadie lo está descontando mientras tanto.
            var adelanto = await _context.AdelantosEmpleado.FirstOrDefaultAsync(a => a.Id == id)
                ?? throw new NotFoundException($"No existe el adelanto {id}");
            if (adelanto.Estado != EstadoAdelanto.Pendiente)
            {
                throw new BadRequestException(adelanto.Estado == EstadoAdelanto.Anulado
                    ? "Este adelanto está anulado"
                    : "Este adelanto ya se descontó completo");
            }

            adelanto.DescontarDesde = await ExigirSemanaAbiertaAsync(request.DescontarDesde, adelanto.Fecha);
            adelanto.CuotaSemanal = Cuota(request.CuotaSemanal, adelanto.Saldo);
            await _context.SaveChangesAsync();
            return adelanto.Id;
        });

        var response = await GetAsync(id);
        await _notificador.AvisarAsync("adelantos", "actualizado", new { id });
        return response;
    }

    public async Task<AdelantoResponse> AnularAsync(int id, int? usuarioId)
    {
        var cuentaId = await _planillas.CambiarAdelantosAsync(async () =>
        {
            var adelanto = await _context.AdelantosEmpleado.FirstOrDefaultAsync(a => a.Id == id)
                ?? throw new NotFoundException($"No existe el adelanto {id}");
            if (adelanto.Estado == EstadoAdelanto.Anulado) throw new BadRequestException("Este adelanto ya está anulado");

            // Lo descontado ya se le pagó de menos: anular aquí lo dejaría cobrado dos veces.
            if (adelanto.MontoDescontado > 0)
            {
                throw new BadRequestException(
                    $"Ya se le descontó S/ {adelanto.MontoDescontado:0.00} en planilla: anula primero esas planillas, " +
                    "o cambia la cuota para no descontarle lo que falta");
            }

            if (adelanto.MovimientoCuentaId is int movimiento)
            {
                await _cuentas.ReversarAsync(movimiento, usuarioId);
            }

            adelanto.Estado = EstadoAdelanto.Anulado;
            await _context.SaveChangesAsync();
            return adelanto.CuentaFinancieraId;
        });

        var response = await GetAsync(id);
        await _notificador.AvisarAsync("adelantos", "anulado", new { id });
        await _notificador.AvisarAsync("cuentasfinancieras", "movimiento", new { Id = cuentaId });
        return response;
    }

    // ------------------------------------------------------------ Auxiliares

    private static DateTime Lunes(DateTime fecha)
    {
        var dia = fecha.Date;
        return dia.AddDays(-(((int)dia.DayOfWeek + 6) % 7));
    }

    /// <summary>
    /// El lunes de la semana desde la que se descuenta. No antes de la semana en que se le dio la
    /// plata, ni una semana cuya planilla ya está pagada (ahí ya no se le puede descontar nada).
    /// </summary>
    private async Task<DateTime> ExigirSemanaAbiertaAsync(DateTime descontarDesde, DateTime fecha)
    {
        var desde = Lunes(descontarDesde);
        if (desde < Lunes(fecha))
        {
            throw new BadRequestException("No se puede descontar antes de la semana en que se le dio la plata");
        }

        if (await _context.PlanillasSemanales.AnyAsync(p => p.Desde == desde && p.Estado == EstadoPlanilla.Pagada))
        {
            throw new BadRequestException(
                $"La planilla de la semana del {desde:dd/MM} ya está pagada: descuéntalo desde la semana siguiente");
        }

        return desde;
    }

    /// <summary>La cuota por semana. Si alcanza para todo lo que falta, es "todo de una vez".</summary>
    private static decimal? Cuota(decimal? cuota, decimal saldo) =>
        cuota is decimal c && Math.Round(c, 2) < saldo ? Math.Round(c, 2) : null;
}
