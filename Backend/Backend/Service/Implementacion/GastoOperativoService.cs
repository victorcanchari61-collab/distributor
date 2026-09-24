using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

public class GastoOperativoService : IGastoOperativoService
{
    private readonly AppDbContext _context;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IValidator<GastoRecurrenteRequest> _recurrenteValidator;
    private readonly IValidator<MovimientoOperativoRequest> _movimientoValidator;
    private readonly INotificador _notificador;

    public GastoOperativoService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IValidator<GastoRecurrenteRequest> recurrenteValidator,
        IValidator<MovimientoOperativoRequest> movimientoValidator,
        INotificador notificador)
    {
        _context = context;
        _cuentas = cuentas;
        _recurrenteValidator = recurrenteValidator;
        _movimientoValidator = movimientoValidator;
        _notificador = notificador;
    }

    // ---------------------------------------------------------- Plantillas

    public async Task<IEnumerable<GastoRecurrenteResponse>> GetRecurrentesAsync()
    {
        var recurrentes = await _context.GastosRecurrentes
            .AsNoTracking()
            .Include(g => g.MotivoGasto)
            .Include(g => g.CuentaFinancieraSugerida)
            .OrderByDescending(g => g.Activo)
            .ThenBy(g => g.Nombre)
            .ToListAsync();

        return recurrentes.Select(MapRecurrente);
    }

    public async Task<GastoRecurrenteResponse> CrearRecurrenteAsync(GastoRecurrenteRequest request)
    {
        await _recurrenteValidator.ValidateAndThrowAsync(request);
        await ValidarReferenciasAsync(request.MotivoGastoId, request.CuentaFinancieraSugeridaId);

        var recurrente = new GastoRecurrente();
        AplicarRecurrente(recurrente, request);

        _context.GastosRecurrentes.Add(recurrente);
        await _context.SaveChangesAsync();

        var response = await GetRecurrenteOrThrowAsync(recurrente.Id);
        await _notificador.AvisarAsync("gastosoperativos", "recurrenteCreado", response);
        return response;
    }

    public async Task<GastoRecurrenteResponse> ActualizarRecurrenteAsync(int id, GastoRecurrenteRequest request)
    {
        await _recurrenteValidator.ValidateAndThrowAsync(request);
        await ValidarReferenciasAsync(request.MotivoGastoId, request.CuentaFinancieraSugeridaId);

        var recurrente = await _context.GastosRecurrentes.FirstOrDefaultAsync(g => g.Id == id)
            ?? throw new NotFoundException($"No existe el gasto recurrente {id}");

        AplicarRecurrente(recurrente, request);
        await _context.SaveChangesAsync();

        var response = await GetRecurrenteOrThrowAsync(id);
        await _notificador.AvisarAsync("gastosoperativos", "recurrenteActualizado", response);
        return response;
    }

    public async Task EliminarRecurrenteAsync(int id)
    {
        var recurrente = await _context.GastosRecurrentes.FirstOrDefaultAsync(g => g.Id == id)
            ?? throw new NotFoundException($"No existe el gasto recurrente {id}");

        if (await _context.MovimientosOperativos.AnyAsync(m => m.GastoRecurrenteId == id))
        {
            throw new BadRequestException(
                "Ya tiene pagos registrados. Desactívalo en vez de eliminarlo.");
        }

        _context.GastosRecurrentes.Remove(recurrente);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("gastosoperativos", "recurrenteEliminado", new { id });
    }

    public async Task<IEnumerable<GastoPendienteResponse>> GetPendientesAsync()
    {
        var hoy = Zona.Hoy;
        var diasEnMes = DateTime.DaysInMonth(hoy.Year, hoy.Month);

        var recurrentes = await _context.GastosRecurrentes
            .AsNoTracking()
            .Include(g => g.MotivoGasto)
            .Where(g => g.Activo)
            .ToListAsync();

        var pendientes = new List<GastoPendienteResponse>();

        foreach (var g in recurrentes)
        {
            var yaPagado = await _context.MovimientosOperativos.AnyAsync(m =>
                m.GastoRecurrenteId == g.Id && !m.Anulado
                && m.Fecha.Year == hoy.Year && m.Fecha.Month == hoy.Month);

            if (yaPagado) continue;

            var dia = Math.Min(g.DiaVencimiento, diasEnMes);
            var vencimiento = new DateTime(hoy.Year, hoy.Month, dia);

            pendientes.Add(new GastoPendienteResponse
            {
                GastoRecurrenteId = g.Id,
                Nombre = g.Nombre,
                MotivoGastoId = g.MotivoGastoId,
                MotivoGasto = g.MotivoGasto?.Nombre ?? string.Empty,
                MontoEstimado = g.MontoEstimado,
                CuentaFinancieraSugeridaId = g.CuentaFinancieraSugeridaId,
                ProximoVencimiento = vencimiento,
                Vencido = vencimiento < hoy,
            });
        }

        return pendientes.OrderBy(p => p.ProximoVencimiento).ToList();
    }

    // ---------------------------------------------------------- Movimientos

    public async Task<IEnumerable<MovimientoOperativoResponse>> ListarAsync(DateTime desde, DateTime hasta)
    {
        var movimientos = await _context.MovimientosOperativos
            .AsNoTracking()
            .Include(m => m.CuentaFinanciera)
            .Include(m => m.MotivoGasto)
            .Include(m => m.Usuario)
            .Where(m => m.Fecha >= desde.Date && m.Fecha < hasta.Date.AddDays(1))
            .OrderByDescending(m => m.Fecha).ThenByDescending(m => m.Id)
            .ToListAsync();

        return movimientos.Select(Map);
    }

    public async Task<MovimientoOperativoResponse> CrearAsync(MovimientoOperativoRequest request, int? usuarioId)
    {
        await _movimientoValidator.ValidateAndThrowAsync(request);
        await ValidarReferenciasAsync(request.MotivoGastoId, null);

        var cuenta = await _cuentas.GetOrThrowAsync(request.CuentaFinancieraId);
        if (!cuenta.Activo) throw new BadRequestException("Esa cuenta está desactivada");

        GastoRecurrente? plantilla = null;
        if (request.GastoRecurrenteId is int recurrenteId)
        {
            plantilla = await _context.GastosRecurrentes.FirstOrDefaultAsync(g => g.Id == recurrenteId)
                ?? throw new BadRequestException("Ese gasto recurrente no existe");
        }

        var fecha = request.Fecha ?? DateTime.UtcNow;

        var movimiento = new MovimientoOperativo
        {
            CuentaFinancieraId = cuenta.Id,
            Tipo = request.Tipo,
            MotivoGastoId = request.MotivoGastoId,
            Monto = request.Monto,
            Fecha = fecha,
            Descripcion = request.Descripcion?.Trim(),
            GastoRecurrenteId = plantilla?.Id,
            UsuarioId = usuarioId,
        };

        _context.MovimientosOperativos.Add(movimiento);
        await _context.SaveChangesAsync();

        var tipoLedger = request.Tipo == TipoMovimientoOperativo.Ingreso
            ? TipoMovimientoCuenta.Ingreso
            : TipoMovimientoCuenta.Egreso;

        var posteo = await _cuentas.PostearAsync(
            cuenta.Id, tipoLedger, request.Monto,
            DocumentoOrigenMovimiento.MovimientoOperativo, movimiento.Id, usuarioId, fecha,
            movimiento.Descripcion);

        movimiento.MovimientoCuentaId = posteo.Id;
        await _context.SaveChangesAsync();

        var response = await GetOrThrowAsync(movimiento.Id);
        await _notificador.AvisarAsync("gastosoperativos", "creado", response);
        await _notificador.AvisarAsync("cuentasfinancieras", "movimiento", new { cuenta.Id });
        return response;
    }

    public async Task<MovimientoOperativoResponse> AnularAsync(int id, int? usuarioId)
    {
        var movimiento = await _context.MovimientosOperativos.FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException($"No existe el movimiento {id}");

        if (movimiento.Anulado) throw new BadRequestException("Ese movimiento ya está anulado");

        if (movimiento.MovimientoCuentaId is int movimientoCuentaId)
        {
            await _cuentas.ReversarAsync(movimientoCuentaId, usuarioId);
        }

        movimiento.Anulado = true;
        await _context.SaveChangesAsync();

        var response = await GetOrThrowAsync(id);
        await _notificador.AvisarAsync("gastosoperativos", "anulado", response);
        return response;
    }

    // ---------------------------------------------------------- Auxiliares

    private async Task<GastoRecurrenteResponse> GetRecurrenteOrThrowAsync(int id) =>
        MapRecurrente(await _context.GastosRecurrentes
            .AsNoTracking()
            .Include(g => g.MotivoGasto)
            .Include(g => g.CuentaFinancieraSugerida)
            .FirstOrDefaultAsync(g => g.Id == id)
            ?? throw new NotFoundException($"No existe el gasto recurrente {id}"));

    private async Task<MovimientoOperativoResponse> GetOrThrowAsync(int id) =>
        Map(await _context.MovimientosOperativos
            .AsNoTracking()
            .Include(m => m.CuentaFinanciera)
            .Include(m => m.MotivoGasto)
            .Include(m => m.Usuario)
            .FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException($"No existe el movimiento {id}"));

    private async Task ValidarReferenciasAsync(int motivoGastoId, int? cuentaFinancieraSugeridaId)
    {
        if (!await _context.MotivosGasto.AnyAsync(m => m.Id == motivoGastoId))
        {
            throw new BadRequestException("Esa categoría de gasto no existe");
        }

        if (cuentaFinancieraSugeridaId is int id)
        {
            await _cuentas.GetOrThrowAsync(id);
        }
    }

    private static void AplicarRecurrente(GastoRecurrente recurrente, GastoRecurrenteRequest request)
    {
        recurrente.Nombre = request.Nombre.Trim();
        recurrente.MotivoGastoId = request.MotivoGastoId;
        recurrente.MontoEstimado = request.MontoEstimado;
        recurrente.DiaVencimiento = request.DiaVencimiento;
        recurrente.CuentaFinancieraSugeridaId = request.CuentaFinancieraSugeridaId;
        recurrente.Activo = request.Activo;
    }

    private static GastoRecurrenteResponse MapRecurrente(GastoRecurrente g) => new()
    {
        Id = g.Id,
        Nombre = g.Nombre,
        MotivoGastoId = g.MotivoGastoId,
        MotivoGasto = g.MotivoGasto?.Nombre ?? string.Empty,
        MontoEstimado = g.MontoEstimado,
        DiaVencimiento = g.DiaVencimiento,
        CuentaFinancieraSugeridaId = g.CuentaFinancieraSugeridaId,
        CuentaFinancieraSugerida = g.CuentaFinancieraSugerida?.Nombre,
        Activo = g.Activo,
    };

    private static MovimientoOperativoResponse Map(MovimientoOperativo m) => new()
    {
        Id = m.Id,
        CuentaFinancieraId = m.CuentaFinancieraId,
        CuentaFinanciera = m.CuentaFinanciera?.Nombre ?? string.Empty,
        Tipo = m.Tipo,
        MotivoGastoId = m.MotivoGastoId,
        MotivoGasto = m.MotivoGasto?.Nombre ?? string.Empty,
        Monto = m.Monto,
        Fecha = m.Fecha,
        Descripcion = m.Descripcion,
        GastoRecurrenteId = m.GastoRecurrenteId,
        Usuario = m.Usuario?.Nombre,
        Anulado = m.Anulado,
    };
}
