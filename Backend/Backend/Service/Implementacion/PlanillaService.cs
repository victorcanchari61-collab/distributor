using System.Data;
using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using MySqlConnector;

namespace Backend.Service.Implementacion;

public class PlanillaService : IPlanillaService
{
    /// <summary>Lunes a sábado: el sueldo semanal paga estos días, así que uno vale un sexto.</summary>
    private const int DiasLaborables = 6;

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
        return planilla is null ? null : await MapAsync(planilla);
    }

    public async Task<IEnumerable<PlanillaResumenResponse>> HistorialAsync()
    {
        // Contado y sumado en la base: antes se cargaba cada planilla con todo
        // su detalle solo para esto. El neto va con la misma cuenta que
        // PlanillaDetalle.Neto (costo laboral sin bajar de cero, menos faltantes).
        return await _context.PlanillasSemanales
            .AsNoTracking()
            .OrderByDescending(p => p.Desde).ThenByDescending(p => p.Id)
            .Select(p => new PlanillaResumenResponse
            {
                Id = p.Id,
                Desde = p.Desde,
                Hasta = p.Hasta,
                Estado = p.Estado,
                Empleados = p.Detalle.Count(),
                TotalNeto = p.Detalle.Sum(d =>
                    (d.SueldoSemanal - d.DescuentoInasistencias + d.ExtraFeriados + d.Bonos - d.OtrosDescuentos > 0
                        ? d.SueldoSemanal - d.DescuentoInasistencias + d.ExtraFeriados + d.Bonos - d.OtrosDescuentos
                        : 0)
                    - d.DescuentoFaltantes - d.DescuentoAdelantos),
                FechaPago = p.FechaPago,
            })
            .ToListAsync();
    }

    public async Task<PlanillaResponse> GenerarAsync(DateTime semana, int? usuarioId)
    {
        if (semana == default) throw new BadRequestException("Indica la semana");

        var lunes = Lunes(semana);
        // Una semana que no empezó no tiene asistencia: se pagaría completa sin que nadie haya trabajado.
        if (lunes > Zona.Hoy)
        {
            throw new BadRequestException($"Esa semana todavía no empieza: su planilla se arma desde el lunes {lunes:dd/MM}");
        }

        await using var transaccion = await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);

        var planilla = await BloquearSemanaAsync(lunes);
        if (planilla?.Estado == EstadoPlanilla.Pagada)
        {
            throw new BadRequestException("Esa semana ya está pagada: anúlala si hay que volver a calcularla");
        }

        if (planilla is null)
        {
            planilla = new PlanillaSemanal { Desde = lunes, Hasta = lunes.AddDays(6), UsuarioId = usuarioId };
            _context.PlanillasSemanales.Add(planilla);
        }

        await RecalcularAsync(planilla);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException e) when (EsDuplicado(e))
        {
            throw new ConflictException("Otra persona acaba de armar la planilla de esta semana: vuelve a cargarla");
        }

        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("planillas", "generada", new { planilla.Id });
        return await GetAsync(planilla.Id);
    }

    public async Task<PlanillaResponse> AjustarAsync(int detalleId, AjustePlanillaRequest request)
    {
        await _ajusteValidator.ValidateAndThrowAsync(request);

        var planillaId = await _context.PlanillaDetalles
            .Where(d => d.Id == detalleId)
            .Select(d => (int?)d.PlanillaSemanalId)
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException($"No existe la línea de planilla {detalleId}");

        await using var transaccion = await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);
        await BloquearAsync(planillaId);

        // Se lee después de bloquear: un recálculo pudo sacarlo de la planilla mientras tanto.
        var planilla = await _context.PlanillasSemanales
            .Include(p => p.Detalle)
            .FirstAsync(p => p.Id == planillaId);
        var detalle = planilla.Detalle.FirstOrDefault(d => d.Id == detalleId)
            ?? throw new NotFoundException("Ese empleado ya no está en la planilla: vuelve a cargarla");

        if (planilla.Estado != EstadoPlanilla.Borrador)
        {
            throw new BadRequestException("Solo se ajusta una planilla que todavía no se pagó");
        }

        detalle.Bonos = Math.Round(request.Bonos, 2);
        detalle.OtrosDescuentos = Math.Round(request.OtrosDescuentos, 2);
        detalle.NotaAjuste = string.IsNullOrWhiteSpace(request.Nota) ? null : request.Nota.Trim();
        detalle.AdelantosManual = request.Adelantos is decimal adelantos ? Math.Round(adelantos, 2) : null;

        // Los faltantes y adelantos dependen de lo que cobra: se rehace con los ajustes nuevos.
        await RecalcularAsync(planilla);
        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("planillas", "ajustada", new { detalle.PlanillaSemanalId });
        return await GetAsync(detalle.PlanillaSemanalId);
    }

    public async Task<PlanillaResponse> PagarAsync(int id, PagarPlanillaRequest request, int? usuarioId)
    {
        await _pagoValidator.ValidateAndThrowAsync(request);

        // Sin seguimiento: el saldo de la cuenta lo lee y lo mueve el posteo, ya dentro de la transacción.
        var cuenta = await _context.CuentasFinancieras.AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == request.CuentaFinancieraId)
            ?? throw new NotFoundException($"No existe la cuenta {request.CuentaFinancieraId}");
        if (!cuenta.Activo) throw new BadRequestException("Esa cuenta está desactivada");

        await using var transaccion = await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);

        /*
         * Bloqueada hasta terminar: si la pagan a la vez desde la web y el celular (o se reintenta
         * por un corte), la segunda espera aquí y después la encuentra ya pagada, en vez de pagar
         * otra vez a todos.
         */
        await BloquearAsync(id);
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

        /*
         * Se paga con lo que hay ahora, no con lo de cuando se armó: si desde entonces cambió la
         * asistencia, un feriado, un sueldo o un faltante, se recalcula y NO se paga — quien paga
         * tiene que ver primero los montos nuevos.
         */
        if (await RecalcularAsync(planilla))
        {
            await _context.SaveChangesAsync();
            await transaccion.CommitAsync();
            await _notificador.AvisarAsync("planillas", "recalculada", new { planilla.Id });
            throw new BadRequestException(
                "La planilla cambió desde que la armaste (asistencia, feriados, sueldos, faltantes o adelantos). " +
                "Ya está recalculada: revisa los montos y vuelve a pagar.");
        }

        if (planilla.Detalle.Count == 0)
        {
            throw new BadRequestException("La planilla no tiene a nadie a quien pagar");
        }

        var sinMarcar = planilla.Detalle.Sum(d => d.DiasSinMarcar);
        if (sinMarcar > 0 && !request.ConDiasSinMarcar)
        {
            throw new BadRequestException(
                $"Falta marcar {sinMarcar} día(s) de asistencia en esta semana y se pagarían como trabajados. " +
                "Pasa lista primero, o confirma que quieres pagar igual.");
        }

        var ahora = DateTime.UtcNow;
        var semana = $"{planilla.Desde:dd/MM} al {planilla.Hasta:dd/MM}";

        // Los faltantes se vuelven a leer al pagar: un cierre pudo anularse
        // mientras la planilla estaba en borrador.
        var descuentos = await DescuentosPendientesAsync(planilla.Detalle.Select(d => d.EmpleadoId));
        var adelantos = await AdelantosPendientesAsync(planilla.Detalle.Select(d => d.EmpleadoId), seguir: true);

        foreach (var detalle in planilla.Detalle)
        {
            var empleado = detalle.Empleado!.NombreCompleto;

            if (detalle.CostoLaboral > 0)
            {
                var movimiento = await _gastos.CrearAsync(new MovimientoOperativoRequest
                {
                    CuentaFinancieraId = cuenta.Id,
                    Tipo = TipoMovimientoOperativo.Egreso,
                    MotivoGastoId = CategoriaSistema.Planilla,
                    Monto = detalle.CostoLaboral,
                    Fecha = ahora,
                    Descripcion = $"Planilla del {semana}: {empleado}",
                }, usuarioId, delSistema: true);
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

            var adelantado = AplicarAdelantos(
                detalle, adelantos.Where(a => a.EmpleadoId == detalle.EmpleadoId).ToList(), planilla.Desde);
            if (adelantado > 0)
            {
                // Igual que el faltante: el pago sale completo y lo descontado vuelve a la cuenta.
                var recuperoAdelanto = await _cuentas.PostearAsync(
                    cuenta.Id, TipoMovimientoCuenta.Ingreso, adelantado,
                    DocumentoOrigenMovimiento.RecuperoAdelanto, detalle.Id, usuarioId, ahora,
                    $"Adelanto descontado a {empleado}");
                detalle.MovimientoAdelantoId = recuperoAdelanto.Id;
            }
        }

        planilla.Estado = EstadoPlanilla.Pagada;
        planilla.CuentaFinancieraId = cuenta.Id;
        planilla.FechaPago = ahora;

        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("planillas", "pagada", new { planilla.Id });
        await _notificador.AvisarAsync("cierrescaja", "descontado", new { planilla.Id });
        await _notificador.AvisarAsync("adelantos", "descontado", new { planilla.Id });
        await _notificador.AvisarAsync("cuentasfinancieras", "movimiento", new { cuenta.Id });
        return await GetAsync(planilla.Id);
    }

    public async Task<PlanillaResponse> AnularAsync(int id, int? usuarioId)
    {
        await using var transaccion = await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);

        // Bloqueada: no se anula mientras otro la está pagando, ni dos veces a la vez.
        await BloquearAsync(id);
        var planilla = await _context.PlanillasSemanales
            .Include(p => p.Detalle).ThenInclude(d => d.Descuentos).ThenInclude(a => a.DescuentoFaltante)
            .Include(p => p.Detalle).ThenInclude(d => d.Adelantos).ThenInclude(a => a.AdelantoEmpleado)
            .AsSplitQuery()
            .FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new NotFoundException($"No existe la planilla {id}");

        if (planilla.Estado == EstadoPlanilla.Anulada) throw new BadRequestException("Esta planilla ya está anulada");

        if (planilla.Estado == EstadoPlanilla.Pagada)
        {
            foreach (var detalle in planilla.Detalle)
            {
                if (detalle.MovimientoOperativoId is int movimiento)
                {
                    await _gastos.AnularAsync(movimiento, usuarioId, delSistema: true);
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

                if (detalle.MovimientoAdelantoId is int recuperoAdelanto)
                {
                    await _cuentas.ReversarAsync(recuperoAdelanto, usuarioId);
                }

                // Lo descontado vuelve a deberse: se le pagó de más al anular.
                foreach (var aplicacion in detalle.Adelantos)
                {
                    var adelanto = aplicacion.AdelantoEmpleado!;
                    adelanto.MontoDescontado -= aplicacion.Monto;
                    if (adelanto.Estado == EstadoAdelanto.Descontado) adelanto.Estado = EstadoAdelanto.Pendiente;
                }

                _context.PlanillaAdelantos.RemoveRange(detalle.Adelantos);
            }
        }

        planilla.Estado = EstadoPlanilla.Anulada;
        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("planillas", "anulada", new { planilla.Id });
        await _notificador.AvisarAsync("cierrescaja", "descuentoRevertido", new { planilla.Id });
        await _notificador.AvisarAsync("adelantos", "descuentoRevertido", new { planilla.Id });
        return await GetAsync(planilla.Id);
    }

    public async Task<T> CambiarDiasAsync<T>(IEnumerable<DateTime> dias, Func<Task<T>> cambio)
    {
        var semanas = dias.Select(Lunes).Distinct().ToList();

        var propia = _context.Database.CurrentTransaction is null;
        await using var transaccion = propia
            ? await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted)
            : null;

        // Las planillas vigentes de esas semanas, bloqueadas en orden (así dos cambios no se traban
        // entre sí): mientras tanto nadie las paga, y quien estaba pagando termina primero.
        var ids = await _context.PlanillasSemanales
            .Where(p => semanas.Contains(p.Desde) && p.Estado != EstadoPlanilla.Anulada)
            .Select(p => p.Id)
            .ToListAsync();
        foreach (var id in ids.Order()) await BloquearAsync(id);

        var planillas = await _context.PlanillasSemanales
            .Include(p => p.Detalle)
            .Where(p => ids.Contains(p.Id))
            .ToListAsync();

        // Lo pagado no se toca: la planilla dejaría de cuadrar con la asistencia que pagó.
        if (planillas.FirstOrDefault(p => p.Estado == EstadoPlanilla.Pagada) is { } pagada)
        {
            throw new BadRequestException(
                $"La semana del {pagada.Desde:dd/MM} al {pagada.Hasta:dd/MM} ya está pagada: " +
                "anula su planilla si hay que corregir la asistencia o los feriados de esos días");
        }

        var resultado = await cambio();

        // El borrador se pone al día solo: quien lo mira ve los montos nuevos sin tener que recalcular.
        foreach (var planilla in planillas) await RecalcularAsync(planilla);
        await _context.SaveChangesAsync();
        if (transaccion is not null) await transaccion.CommitAsync();

        foreach (var planilla in planillas)
        {
            await _notificador.AvisarAsync("planillas", "recalculada", new { planilla.Id });
        }

        return resultado;
    }

    public async Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync() =>
        await _context.CuentasFinancieras
            .AsNoTracking()
            .Where(c => c.Activo)
            .OrderBy(c => c.Naturaleza).ThenBy(c => c.Nombre)
            .Select(c => new CuentaDestinoResponse
            {
                Id = c.Id,
                Nombre = c.Nombre,
                Naturaleza = c.Naturaleza,
                EsBoveda = c.Naturaleza == NaturalezaCuenta.Caja && c.UsuarioResponsableId == null,
            })
            .ToListAsync();

    public async Task<T> CambiarAdelantosAsync<T>(Func<Task<T>> cambio)
    {
        var propia = _context.Database.CurrentTransaction is null;
        await using var transaccion = propia
            ? await _context.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted)
            : null;

        // Los borradores, bloqueados en orden: mientras tanto nadie paga uno con el adelanto a medias.
        var ids = await _context.PlanillasSemanales
            .Where(p => p.Estado == EstadoPlanilla.Borrador)
            .Select(p => p.Id)
            .ToListAsync();
        foreach (var id in ids.Order()) await BloquearAsync(id);

        var resultado = await cambio();

        // Releídos tras el bloqueo: uno pudo pagarse mientras se esperaba, y ese ya no se toca.
        var borradores = await _context.PlanillasSemanales
            .Include(p => p.Detalle)
            .Where(p => ids.Contains(p.Id) && p.Estado == EstadoPlanilla.Borrador)
            .ToListAsync();
        foreach (var planilla in borradores) await RecalcularAsync(planilla);
        await _context.SaveChangesAsync();
        if (transaccion is not null) await transaccion.CommitAsync();

        foreach (var planilla in borradores)
        {
            await _notificador.AvisarAsync("planillas", "recalculada", new { planilla.Id });
        }

        return resultado;
    }

    // ------------------------------------------------------------ Auxiliares

    private static DateTime Lunes(DateTime fecha)
    {
        var dia = fecha.Date;
        return dia.AddDays(-(((int)dia.DayOfWeek + 6) % 7));
    }

    /// <summary>
    /// Toma la fila de la planilla hasta que termine la transacción. Quien llegue después espera
    /// aquí, y como la transacción lee lo ya confirmado, al seguir ve lo que el otro guardó.
    /// </summary>
    private async Task BloquearAsync(int planillaId)
    {
        await _context.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT Id FROM PlanillasSemanales WHERE Id = {planillaId} FOR UPDATE");

        // Lo que ya estuviera cargado de esa planilla puede ser de antes del bloqueo: se suelta para
        // que la lectura que sigue traiga lo que guardó quien la tenía tomada, y no lo de memoria.
        foreach (var entrada in _context.ChangeTracker.Entries()
                     .Where(e => (e.Entity is PlanillaSemanal p && p.Id == planillaId)
                                 || (e.Entity is PlanillaDetalle d && d.PlanillaSemanalId == planillaId))
                     .ToList())
        {
            entrada.State = EntityState.Detached;
        }
    }

    /// <summary>La planilla vigente de esa semana, ya bloqueada y con su detalle; null si no hay.</summary>
    private async Task<PlanillaSemanal?> BloquearSemanaAsync(DateTime lunes)
    {
        var id = await _context.PlanillasSemanales
            .Where(p => p.Desde == lunes && p.Estado != EstadoPlanilla.Anulada)
            .Select(p => (int?)p.Id)
            .FirstOrDefaultAsync();
        if (id is not int planillaId) return null;

        await BloquearAsync(planillaId);
        return await _context.PlanillasSemanales
            .Include(p => p.Detalle)
            .FirstOrDefaultAsync(p => p.Id == planillaId);
    }

    /// <summary>Lo rechazó un índice único: otra persona guardó lo mismo un instante antes.</summary>
    private static bool EsDuplicado(DbUpdateException e) =>
        e.InnerException is MySqlException { ErrorCode: MySqlErrorCode.DuplicateKeyEntry };

    /// <summary>
    /// Rehace cada línea con lo que hay ahora: quién entra, su asistencia, los feriados y sus
    /// faltantes. Conserva los bonos y descuentos a mano. Devuelve si algo de lo que se paga cambió.
    /// </summary>
    private async Task<bool> RecalcularAsync(PlanillaSemanal planilla)
    {
        var lunes = planilla.Desde;
        var domingo = planilla.Hasta;
        var antes = Huella(planilla);

        // Por sus fechas y no solo por estar activo: quien cesó a mitad de semana y ya se desactivó
        // cobra los días que trabajó. Desactivado SIN fecha de cese no entra: no se sabe hasta cuándo.
        // Sin seguimiento: siempre el sueldo y las fechas de ahora, aunque ya se hubieran leído antes.
        var empleados = await _context.Empleados
            .AsNoTracking()
            .Where(e => (e.Activo || e.FechaCese != null) && e.SueldoSemanal > 0
                        && (e.FechaIngreso == null || e.FechaIngreso <= domingo)
                        && (e.FechaCese == null || e.FechaCese >= lunes))
            .ToListAsync();
        var ids = empleados.Select(e => e.Id).ToList();

        var (asistencias, feriados) = await DatosDeLaSemanaAsync(ids, lunes);
        var pendientes = await PendientesPorEmpleadoAsync(ids);
        var adelantos = await AdelantosPendientesAsync(ids, seguir: false);

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
            CalcularAdelantos(detalle, adelantos.Where(a => a.EmpleadoId == empleado.Id).ToList(), lunes);
        }

        return !Huella(planilla).SequenceEqual(antes);
    }

    /// <summary>Lo que cuenta de cada línea para saber si un recálculo cambió lo que se paga.</summary>
    private static List<(int, decimal, int, int, decimal, decimal, decimal, decimal)> Huella(PlanillaSemanal p) =>
        p.Detalle
            .OrderBy(d => d.EmpleadoId)
            .Select(d => (d.EmpleadoId, d.SueldoSemanal, d.DiasNoPagados, d.DiasSinMarcar,
                d.DescuentoInasistencias, d.ExtraFeriados, d.DescuentoFaltantes, d.DescuentoAdelantos))
            .ToList();

    /// <summary>Los adelantos con saldo de esos empleados, del más viejo al más nuevo.</summary>
    private async Task<List<AdelantoEmpleado>> AdelantosPendientesAsync(IEnumerable<int> empleadoIds, bool seguir)
    {
        var ids = empleadoIds.Distinct().ToList();
        var query = _context.AdelantosEmpleado
            .Where(a => a.Estado == EstadoAdelanto.Pendiente && ids.Contains(a.EmpleadoId));
        if (!seguir) query = query.AsNoTracking();
        return await query.OrderBy(a => a.Fecha).ThenBy(a => a.Id).ToListAsync();
    }

    /// <summary>
    /// Cuánto descontarle de sus adelantos esta semana. Lo que le toca (todo, o la cuota, de los que
    /// ya empezaron a descontarse) salvo que se haya puesto otro monto a mano; nunca más de lo que
    /// debe, ni más de lo que le queda por cobrar después de los faltantes. Lo que no alcance queda
    /// para la semana siguiente.
    /// </summary>
    private static void CalcularAdelantos(PlanillaDetalle detalle, List<AdelantoEmpleado> suyos, DateTime lunes)
    {
        detalle.AdelantosSaldo = suyos.Sum(a => a.Saldo);
        detalle.AdelantosSugerido = suyos
            .Where(a => a.DescontarDesde <= lunes)
            .Sum(a => Math.Min(a.CuotaSemanal ?? a.Saldo, a.Saldo));

        var pedido = Math.Min(detalle.AdelantosManual ?? detalle.AdelantosSugerido, detalle.AdelantosSaldo);
        var disponible = Math.Max(0, detalle.CostoLaboral - detalle.DescuentoFaltantes);
        detalle.DescuentoAdelantos = Math.Min(pedido, disponible);
    }

    /// <summary>
    /// Reparte lo que se descuenta entre sus adelantos: primero lo que a cada uno le toca esta semana,
    /// del más viejo al más nuevo; si se ajustó para descontar más, lo que sobra sale de los más viejos.
    /// Devuelve lo aplicado.
    /// </summary>
    private static decimal AplicarAdelantos(PlanillaDetalle detalle, List<AdelantoEmpleado> suyos, DateTime lunes)
    {
        var porAplicar = detalle.DescuentoAdelantos;

        void Aplicar(AdelantoEmpleado adelanto, decimal tope)
        {
            var monto = Math.Min(Math.Min(tope, adelanto.Saldo), porAplicar);
            if (monto <= 0) return;

            adelanto.MontoDescontado += monto;
            if (adelanto.Saldo <= 0) adelanto.Estado = EstadoAdelanto.Descontado;

            var aplicacion = detalle.Adelantos.FirstOrDefault(x => x.AdelantoEmpleadoId == adelanto.Id);
            if (aplicacion is null) detalle.Adelantos.Add(new PlanillaAdelanto { AdelantoEmpleadoId = adelanto.Id, Monto = monto });
            else aplicacion.Monto += monto;

            porAplicar -= monto;
        }

        foreach (var adelanto in suyos.Where(a => a.DescontarDesde <= lunes)) Aplicar(adelanto, adelanto.CuotaSemanal ?? adelanto.Saldo);
        foreach (var adelanto in suyos) Aplicar(adelanto, adelanto.Saldo);

        detalle.DescuentoAdelantos -= porAplicar;
        return detalle.DescuentoAdelantos;
    }

    /// <summary>La asistencia vigente y los feriados de esa semana (lunes a domingo).</summary>
    private async Task<(List<Asistencia> Asistencias, List<Feriado> Feriados)> DatosDeLaSemanaAsync(
        List<int> empleadoIds, DateTime lunes)
    {
        var fin = lunes.AddDays(7);
        var asistencias = await _context.Asistencias
            .AsNoTracking()
            .Where(a => !a.Anulado && empleadoIds.Contains(a.EmpleadoId) && a.Fecha >= lunes && a.Fecha < fin)
            .ToListAsync();
        var feriados = await _context.Feriados
            .AsNoTracking()
            .Where(f => f.Fecha >= lunes && f.Fecha < fin)
            .ToListAsync();
        return (asistencias, feriados);
    }

    /// <summary>Si ese día todavía no había entrado, o ya había cesado.</summary>
    private static bool FueraDeContrato(Empleado empleado, DateTime dia) =>
        (empleado.FechaIngreso is DateTime ingreso && dia < ingreso.Date)
        || (empleado.FechaCese is DateTime cese && dia > cese.Date);

    /// <summary>Los días de lunes a sábado, dentro de su contrato y que no son feriado, sin marca.</summary>
    private static IEnumerable<DateTime> DiasSinMarcar(
        Empleado empleado, DateTime lunes, List<Asistencia> asistencias, List<Feriado> feriados) =>
        Enumerable.Range(0, DiasLaborables)
            .Select(i => lunes.AddDays(i))
            .Where(dia => !FueraDeContrato(empleado, dia)
                          && !feriados.Any(f => f.Fecha.Date == dia)
                          && !asistencias.Any(a => a.Fecha.Date == dia));

    /// <summary>
    /// Sueldo menos los días de lunes a sábado que no se pagan (fuera de su contrato, falta o
    /// permiso), más lo extra por feriados trabajados (se pagan doble). Un feriado no descuenta:
    /// es no laborable pero pagado — siempre que ese día ya trabajara aquí.
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

            // El contrato va primero: un feriado de antes de que entrara tampoco se le paga.
            if (FueraDeContrato(empleado, dia))
            {
                noPagados++;
                continue;
            }

            if (feriados.Any(f => f.Fecha.Date == dia)) continue;
            if (EstadoDel(dia) is EstadoAsistencia.Falta or EstadoAsistencia.Permiso) noPagados++;
        }

        // Un feriado trabajado se paga doble. Si cae de lunes a sábado, el
        // sueldo ya incluye ese día y se suma uno más; si cae domingo, que no
        // está en el sueldo, se suman los dos.
        var extra = 0m;
        foreach (var feriado in feriados)
        {
            var dia = feriado.Fecha.Date;
            if (FueraDeContrato(empleado, dia)) continue;

            if (EstadoDel(dia) is EstadoAsistencia.Presente or EstadoAsistencia.Tardanza)
            {
                var laborable = (dia - lunes).Days < DiasLaborables;
                extra += valorDia * (laborable ? 1 : 2);
            }
        }

        detalle.SueldoSemanal = sueldo;
        detalle.DiasNoPagados = noPagados;
        detalle.DiasSinMarcar = DiasSinMarcar(empleado, lunes, asistencias, feriados).Count();
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

    public async Task<PlanillaResponse> GetAsync(int id) =>
        await MapAsync(await Consulta().FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new NotFoundException($"No existe la planilla {id}"));

    /// <summary>La respuesta, y en borrador los días en que a alguien le falta su marca.</summary>
    private async Task<PlanillaResponse> MapAsync(PlanillaSemanal planilla)
    {
        var respuesta = Map(planilla);
        if (planilla.Estado != EstadoPlanilla.Borrador || planilla.Detalle.Count == 0) return respuesta;

        var ids = planilla.Detalle.Select(d => d.EmpleadoId).ToList();
        var (asistencias, feriados) = await DatosDeLaSemanaAsync(ids, planilla.Desde);
        respuesta.FechasSinMarcar = planilla.Detalle
            .Where(d => d.Empleado is not null)
            .SelectMany(d => DiasSinMarcar(
                d.Empleado!, planilla.Desde, asistencias.Where(a => a.EmpleadoId == d.EmpleadoId).ToList(), feriados))
            .Distinct()
            .Order()
            .ToList();
        return respuesta;
    }

    private static PlanillaResponse Map(PlanillaSemanal p)
    {
        var detalle = p.Detalle
            .OrderBy(d => d.Empleado?.Apellidos).ThenBy(d => d.Empleado?.Nombres)
            .Select(d => new PlanillaDetalleResponse
            {
                Id = d.Id,
                EmpleadoId = d.EmpleadoId,
                Empleado = d.Empleado?.NombreCompleto ?? string.Empty,
                Documento = d.Empleado?.Documento,
                Cargo = d.Empleado?.Cargo,
                SueldoSemanal = d.SueldoSemanal,
                DiasNoPagados = d.DiasNoPagados,
                DiasSinMarcar = d.DiasSinMarcar,
                DescuentoInasistencias = d.DescuentoInasistencias,
                ExtraFeriados = d.ExtraFeriados,
                Bonos = d.Bonos,
                OtrosDescuentos = d.OtrosDescuentos,
                NotaAjuste = d.NotaAjuste,
                DescuentoFaltantes = d.DescuentoFaltantes,
                DescuentoAdelantos = d.DescuentoAdelantos,
                AdelantosSugerido = d.AdelantosSugerido,
                AdelantosManual = d.AdelantosManual,
                AdelantosSaldo = d.AdelantosSaldo,
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
            TotalAdelantos = detalle.Sum(d => d.DescuentoAdelantos),
            TotalNeto = detalle.Sum(d => d.Neto),
            Detalle = detalle,
        };
    }
}
