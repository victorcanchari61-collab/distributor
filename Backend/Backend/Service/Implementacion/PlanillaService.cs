using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class PlanillaService : IPlanillaService
{
    /// <summary>Lunes a sábado: el sueldo semanal paga estos días, así que uno vale un sexto.</summary>
    private const int DiasLaborables = 6;

    /// <summary>La categoría sembrada "Planilla" (egreso operativo) con la que se registra el pago.</summary>
    private const int CategoriaPlanilla = 6;

    private readonly AppDbContext _context;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IGastoOperativoService _gastos;
    private readonly IValidator<AjustePlanillaRequest> _ajusteValidator;
    private readonly IValidator<PagarPlanillaRequest> _pagoValidator;
    private readonly INotificador _notificador;

    public PlanillaService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IGastoOperativoService gastos,
        IValidator<AjustePlanillaRequest> ajusteValidator,
        IValidator<PagarPlanillaRequest> pagoValidator,
        INotificador notificador)
    {
        _context = context;
        _cuentas = cuentas;
        _gastos = gastos;
        _ajusteValidator = ajusteValidator;
        _pagoValidator = pagoValidator;
        _notificador = notificador;
    }

    public async Task<PlanillaResponse?> GetSemanaAsync(DateTime semana)
    {
        var lunes = Lunes(semana);
        var planilla = await Consulta().FirstOrDefaultAsync(p => p.Desde == lunes && p.Estado != EstadoPlanilla.Anulada);
        return planilla is null ? null : Map(planilla);
    }

    public async Task<IEnumerable<PlanillaResumenResponse>> HistorialAsync()
    {
        var planillas = await _context.PlanillasSemanales
            .AsNoTracking()
            .Include(p => p.Detalle)
            .OrderByDescending(p => p.Desde).ThenByDescending(p => p.Id)
            .ToListAsync();

        return planillas.Select(p => new PlanillaResumenResponse
        {
            Id = p.Id,
            Desde = p.Desde,
            Hasta = p.Hasta,
            Estado = p.Estado,
            Empleados = p.Detalle.Count,
            TotalNeto = p.Detalle.Sum(d => d.Neto),
            FechaPago = p.FechaPago,
        });
    }

    public async Task<PlanillaResponse> GenerarAsync(DateTime semana, int? usuarioId)
    {
        var lunes = Lunes(semana);
        var domingo = lunes.AddDays(6);

        var planilla = await _context.PlanillasSemanales
            .Include(p => p.Detalle)
            .FirstOrDefaultAsync(p => p.Desde == lunes && p.Estado != EstadoPlanilla.Anulada);

        if (planilla?.Estado == EstadoPlanilla.Pagada)
        {
            throw new BadRequestException("Esa semana ya está pagada: anúlala si hay que volver a calcularla");
        }

        if (planilla is null)
        {
            planilla = new PlanillaSemanal { Desde = lunes, Hasta = domingo, UsuarioId = usuarioId };
            _context.PlanillasSemanales.Add(planilla);
        }

        var empleados = await _context.Empleados
            .Where(e => e.Activo && e.SueldoSemanal > 0
                        && (e.FechaIngreso == null || e.FechaIngreso <= domingo)
                        && (e.FechaCese == null || e.FechaCese >= lunes))
            .ToListAsync();
        var ids = empleados.Select(e => e.Id).ToList();

        var asistencias = await _context.Asistencias
            .AsNoTracking()
            .Where(a => !a.Anulado && ids.Contains(a.EmpleadoId) && a.Fecha >= lunes && a.Fecha < domingo.AddDays(1))
            .ToListAsync();
        var feriados = await _context.Feriados
            .AsNoTracking()
            .Where(f => f.Fecha >= lunes && f.Fecha < domingo.AddDays(1))
            .ToListAsync();
        var pendientes = await PendientesPorEmpleadoAsync(ids);

        // Quien ya no entra (se le quitó el sueldo, cesó) sale de la planilla.
        foreach (var sobra in planilla.Detalle.Where(d => !ids.Contains(d.EmpleadoId)).ToList())
        {
            planilla.Detalle.Remove(sobra);
            _context.PlanillaDetalles.Remove(sobra);
        }

        foreach (var empleado in empleados)
        {
            var detalle = planilla.Detalle.FirstOrDefault(d => d.EmpleadoId == empleado.Id);
            if (detalle is null)
            {
                detalle = new PlanillaDetalle { EmpleadoId = empleado.Id };
                planilla.Detalle.Add(detalle);
            }

            Calcular(detalle, empleado, lunes, asistencias.Where(a => a.EmpleadoId == empleado.Id).ToList(), feriados);
            detalle.DescuentoFaltantes = Math.Min(pendientes.GetValueOrDefault(empleado.Id), detalle.CostoLaboral);
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("planillas", "generada", new { planilla.Id });
        return await GetAsync(planilla.Id);
    }

    public async Task<PlanillaResponse> AjustarAsync(int detalleId, AjustePlanillaRequest request)
    {
        await _ajusteValidator.ValidateAndThrowAsync(request);

        var detalle = await _context.PlanillaDetalles
            .Include(d => d.PlanillaSemanal)
            .FirstOrDefaultAsync(d => d.Id == detalleId)
            ?? throw new NotFoundException($"No existe la línea de planilla {detalleId}");

        if (detalle.PlanillaSemanal!.Estado != EstadoPlanilla.Borrador)
        {
            throw new BadRequestException("Solo se ajusta una planilla que todavía no se pagó");
        }

        detalle.Bonos = Math.Round(request.Bonos, 2);
        detalle.OtrosDescuentos = Math.Round(request.OtrosDescuentos, 2);
        detalle.NotaAjuste = string.IsNullOrWhiteSpace(request.Nota) ? null : request.Nota.Trim();

        var pendiente = (await PendientesPorEmpleadoAsync([detalle.EmpleadoId])).GetValueOrDefault(detalle.EmpleadoId);
        detalle.DescuentoFaltantes = Math.Min(pendiente, detalle.CostoLaboral);

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("planillas", "ajustada", new { detalle.PlanillaSemanalId });
        return await GetAsync(detalle.PlanillaSemanalId);
    }

    public async Task<PlanillaResponse> PagarAsync(int id, PagarPlanillaRequest request, int? usuarioId)
    {
        await _pagoValidator.ValidateAndThrowAsync(request);

        var planilla = await _context.PlanillasSemanales
            .Include(p => p.Detalle).ThenInclude(d => d.Empleado)
            .FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new NotFoundException($"No existe la planilla {id}");

        if (planilla.Estado != EstadoPlanilla.Borrador)
        {
            throw new BadRequestException(planilla.Estado == EstadoPlanilla.Pagada
                ? "Esta planilla ya está pagada"
                : "Esta planilla está anulada");
        }

        if (planilla.Detalle.Count == 0)
        {
            throw new BadRequestException("La planilla no tiene a nadie a quien pagar");
        }

        var cuenta = await _cuentas.GetOrThrowAsync(request.CuentaFinancieraId);
        if (!cuenta.Activo) throw new BadRequestException("Esa cuenta está desactivada");

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        var ahora = DateTime.UtcNow;
        var semana = $"{planilla.Desde:dd/MM} al {planilla.Hasta:dd/MM}";

        // Los faltantes se vuelven a leer al pagar: un cierre pudo anularse
        // mientras la planilla estaba en borrador.
        var descuentos = await DescuentosPendientesAsync(planilla.Detalle.Select(d => d.EmpleadoId));

        foreach (var detalle in planilla.Detalle)
        {
            var empleado = detalle.Empleado!.NombreCompleto;

            if (detalle.CostoLaboral > 0)
            {
                var movimiento = await _gastos.CrearAsync(new MovimientoOperativoRequest
                {
                    CuentaFinancieraId = cuenta.Id,
                    Tipo = TipoMovimientoOperativo.Egreso,
                    MotivoGastoId = CategoriaPlanilla,
                    Monto = detalle.CostoLaboral,
                    Fecha = ahora,
                    Descripcion = $"Planilla del {semana}: {empleado}",
                }, usuarioId);
                detalle.MovimientoOperativoId = movimiento.Id;
            }

            // Se descuenta hasta lo que le toca cobrar: lo que no alcance queda
            // pendiente para la semana siguiente. Primero los faltantes más viejos.
            var porAplicar = Math.Min(
                descuentos.Where(d => d.EmpleadoId == detalle.EmpleadoId).Sum(d => d.Descuento.Saldo),
                detalle.CostoLaboral);
            var aplicado = 0m;

            foreach (var (_, descuento) in descuentos.Where(d => d.EmpleadoId == detalle.EmpleadoId))
            {
                if (aplicado >= porAplicar) break;
                var monto = Math.Min(descuento.Saldo, porAplicar - aplicado);
                if (monto <= 0) continue;

                descuento.MontoAplicado += monto;
                if (descuento.Saldo <= 0) descuento.Estado = EstadoDescuentoFaltante.Descontado;
                detalle.Descuentos.Add(new PlanillaDescuento { DescuentoFaltanteId = descuento.Id, Monto = monto });
                aplicado += monto;
            }

            detalle.DescuentoFaltantes = aplicado;

            if (aplicado > 0)
            {
                // El pago sale por el costo laboral completo y lo descontado
                // vuelve a la misma cuenta: lo que baja de verdad es el neto.
                var recupero = await _cuentas.PostearAsync(
                    cuenta.Id, TipoMovimientoCuenta.Ingreso, aplicado,
                    DocumentoOrigenMovimiento.RecuperoFaltante, detalle.Id, usuarioId, ahora,
                    $"Faltante de caja descontado a {empleado}");
                detalle.MovimientoRecuperoId = recupero.Id;
            }
        }

        planilla.Estado = EstadoPlanilla.Pagada;
        planilla.CuentaFinancieraId = cuenta.Id;
        planilla.FechaPago = ahora;

        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("planillas", "pagada", new { planilla.Id });
        await _notificador.AvisarAsync("cierrescaja", "descontado", new { planilla.Id });
        await _notificador.AvisarAsync("cuentasfinancieras", "movimiento", new { cuenta.Id });
        return await GetAsync(planilla.Id);
    }

    public async Task<PlanillaResponse> AnularAsync(int id, int? usuarioId)
    {
        var planilla = await _context.PlanillasSemanales
            .Include(p => p.Detalle).ThenInclude(d => d.Descuentos).ThenInclude(a => a.DescuentoFaltante)
            .FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new NotFoundException($"No existe la planilla {id}");

        if (planilla.Estado == EstadoPlanilla.Anulada) throw new BadRequestException("Esta planilla ya está anulada");

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        if (planilla.Estado == EstadoPlanilla.Pagada)
        {
            foreach (var detalle in planilla.Detalle)
            {
                if (detalle.MovimientoOperativoId is int movimiento)
                {
                    await _gastos.AnularAsync(movimiento, usuarioId);
                }

                if (detalle.MovimientoRecuperoId is int recupero)
                {
                    await _cuentas.ReversarAsync(recupero, usuarioId);
                }

                foreach (var aplicacion in detalle.Descuentos)
                {
                    var descuento = aplicacion.DescuentoFaltante!;
                    descuento.MontoAplicado -= aplicacion.Monto;
                    if (descuento.Estado == EstadoDescuentoFaltante.Descontado)
                    {
                        descuento.Estado = EstadoDescuentoFaltante.Pendiente;
                    }
                }

                _context.PlanillaDescuentos.RemoveRange(detalle.Descuentos);
            }
        }

        planilla.Estado = EstadoPlanilla.Anulada;
        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("planillas", "anulada", new { planilla.Id });
        await _notificador.AvisarAsync("cierrescaja", "descuentoRevertido", new { planilla.Id });
        return await GetAsync(planilla.Id);
    }

    public async Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync() =>
        await _context.CuentasFinancieras
            .AsNoTracking()
            .Where(c => c.Activo)
            .OrderBy(c => c.Naturaleza).ThenBy(c => c.Nombre)
            .Select(c => new CuentaDestinoResponse { Id = c.Id, Nombre = c.Nombre, Naturaleza = c.Naturaleza })
            .ToListAsync();

    // ------------------------------------------------------------ Auxiliares

    private static DateTime Lunes(DateTime fecha)
    {
        var dia = fecha.Date;
        return dia.AddDays(-(((int)dia.DayOfWeek + 6) % 7));
    }

    /// <summary>
    /// Sueldo menos los días de lunes a sábado que no se pagan (falta, permiso,
    /// o fuera de su contrato), más lo extra por feriados trabajados (se pagan
    /// doble). Un feriado no descuenta: es no laborable pero pagado.
    /// </summary>
    private static void Calcular(
        PlanillaDetalle detalle, Empleado empleado, DateTime lunes,
        List<Asistencia> asistencias, List<Feriado> feriados)
    {
        var sueldo = empleado.SueldoSemanal ?? 0;
        var valorDia = sueldo / DiasLaborables;

        string? EstadoDel(DateTime dia) => asistencias.FirstOrDefault(a => a.Fecha.Date == dia)?.Estado;

        var noPagados = 0;
        for (var i = 0; i < DiasLaborables; i++)
        {
            var dia = lunes.AddDays(i);
            if (feriados.Any(f => f.Fecha.Date == dia)) continue;

            var fueraDeContrato = (empleado.FechaIngreso is DateTime ingreso && dia < ingreso.Date)
                                  || (empleado.FechaCese is DateTime cese && dia > cese.Date);
            var estado = EstadoDel(dia);

            if (fueraDeContrato || estado is EstadoAsistencia.Falta or EstadoAsistencia.Permiso) noPagados++;
        }

        // Un feriado trabajado se paga doble. Si cae de lunes a sábado, el
        // sueldo ya incluye ese día y se suma uno más; si cae domingo, que no
        // está en el sueldo, se suman los dos.
        var extra = 0m;
        foreach (var feriado in feriados)
        {
            if (EstadoDel(feriado.Fecha.Date) is EstadoAsistencia.Presente or EstadoAsistencia.Tardanza)
            {
                var laborable = (feriado.Fecha.Date - lunes).Days < DiasLaborables;
                extra += valorDia * (laborable ? 1 : 2);
            }
        }

        detalle.SueldoSemanal = sueldo;
        detalle.DiasNoPagados = noPagados;
        detalle.DescuentoInasistencias = Math.Round(valorDia * noPagados, 2);
        detalle.ExtraFeriados = Math.Round(extra, 2);
    }

    /// <summary>Los usuarios de cada empleado: un faltante es de un usuario, la planilla es de un empleado.</summary>
    private async Task<Dictionary<int, int>> EmpleadoDeUsuariosAsync(IEnumerable<int> empleadoIds)
    {
        var ids = empleadoIds.Distinct().ToList();
        return await _context.Usuarios
            .Where(u => u.EmpleadoId != null && ids.Contains(u.EmpleadoId.Value))
            .ToDictionaryAsync(u => u.Id, u => u.EmpleadoId!.Value);
    }

    private async Task<Dictionary<int, decimal>> PendientesPorEmpleadoAsync(IEnumerable<int> empleadoIds)
    {
        var descuentos = await DescuentosPendientesAsync(empleadoIds);
        return descuentos
            .GroupBy(d => d.EmpleadoId)
            .ToDictionary(g => g.Key, g => g.Sum(d => d.Descuento.Saldo));
    }

    /// <summary>Los faltantes pendientes de esos empleados, del más viejo al más nuevo.</summary>
    private async Task<List<(int EmpleadoId, DescuentoFaltante Descuento)>> DescuentosPendientesAsync(IEnumerable<int> empleadoIds)
    {
        var empleadoDe = await EmpleadoDeUsuariosAsync(empleadoIds);
        var usuarioIds = empleadoDe.Keys.ToList();

        var descuentos = await _context.DescuentosFaltante
            .Where(d => d.Estado == EstadoDescuentoFaltante.Pendiente && usuarioIds.Contains(d.UsuarioId))
            .OrderBy(d => d.Id)
            .ToListAsync();

        return descuentos.Select(d => (empleadoDe[d.UsuarioId], d)).ToList();
    }

    private IQueryable<PlanillaSemanal> Consulta() => _context.PlanillasSemanales
        .AsNoTracking()
        .Include(p => p.CuentaFinanciera)
        .Include(p => p.Detalle).ThenInclude(d => d.Empleado);

    private async Task<PlanillaResponse> GetAsync(int id) =>
        Map(await Consulta().FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new NotFoundException($"No existe la planilla {id}"));

    private static PlanillaResponse Map(PlanillaSemanal p)
    {
        var detalle = p.Detalle
            .OrderBy(d => d.Empleado?.Apellidos).ThenBy(d => d.Empleado?.Nombres)
            .Select(d => new PlanillaDetalleResponse
            {
                Id = d.Id,
                EmpleadoId = d.EmpleadoId,
                Empleado = d.Empleado?.NombreCompleto ?? string.Empty,
                Cargo = d.Empleado?.Cargo,
                SueldoSemanal = d.SueldoSemanal,
                DiasNoPagados = d.DiasNoPagados,
                DescuentoInasistencias = d.DescuentoInasistencias,
                ExtraFeriados = d.ExtraFeriados,
                Bonos = d.Bonos,
                OtrosDescuentos = d.OtrosDescuentos,
                NotaAjuste = d.NotaAjuste,
                DescuentoFaltantes = d.DescuentoFaltantes,
                CostoLaboral = d.CostoLaboral,
                Neto = d.Neto,
            })
            .ToList();

        return new PlanillaResponse
        {
            Id = p.Id,
            Desde = p.Desde,
            Hasta = p.Hasta,
            Estado = p.Estado,
            CuentaFinancieraId = p.CuentaFinancieraId,
            CuentaFinanciera = p.CuentaFinanciera?.Nombre,
            FechaPago = p.FechaPago,
            TotalCostoLaboral = detalle.Sum(d => d.CostoLaboral),
            TotalFaltantes = detalle.Sum(d => d.DescuentoFaltantes),
            TotalNeto = detalle.Sum(d => d.Neto),
            Detalle = detalle,
        };
    }
}
