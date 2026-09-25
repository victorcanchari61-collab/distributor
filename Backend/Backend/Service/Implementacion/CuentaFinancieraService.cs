using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

public class CuentaFinancieraService : ICuentaFinancieraService
{
    private readonly AppDbContext _context;
    private readonly IValidator<CuentaFinancieraRequest> _validator;
    private readonly INotificador _notificador;

    public CuentaFinancieraService(
        AppDbContext context, IValidator<CuentaFinancieraRequest> validator, INotificador notificador)
    {
        _context = context;
        _validator = validator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<CuentaFinancieraResponse>> GetAllAsync()
    {
        var cuentas = await _context.CuentasFinancieras
            .AsNoTracking()
            .Include(c => c.UsuarioResponsable)
            .OrderByDescending(c => c.Activo)
            .ThenBy(c => c.Naturaleza)
            .ThenBy(c => c.Nombre)
            .ToListAsync();

        return cuentas.Select(Map);
    }

    public async Task<CuentaFinancieraResponse> GetByIdAsync(int id)
    {
        var cuenta = await _context.CuentasFinancieras
            .AsNoTracking()
            .Include(c => c.UsuarioResponsable)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException($"No existe la cuenta financiera {id}");

        return Map(cuenta);
    }

    public async Task<CuentaFinanciera> GetOrThrowAsync(int id) =>
        await _context.CuentasFinancieras.FirstOrDefaultAsync(c => c.Id == id)
        ?? throw new NotFoundException($"No existe la cuenta financiera {id}");

    public async Task<CuentaFinancieraResponse> CreateAsync(CuentaFinancieraRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        if (await _context.CuentasFinancieras.AnyAsync(c => c.Nombre == request.Nombre.Trim()))
        {
            throw new ConflictException("Ya existe una cuenta financiera con ese nombre");
        }

        var cuenta = new CuentaFinanciera { Activo = true };
        Aplicar(cuenta, request);

        _context.CuentasFinancieras.Add(cuenta);
        await _context.SaveChangesAsync();

        var response = Map(cuenta);
        await _notificador.AvisarAsync("cuentasfinancieras", "creada", response);
        return response;
    }

    public async Task<CuentaFinancieraResponse> UpdateAsync(int id, CuentaFinancieraRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        var cuenta = await GetOrThrowAsync(id);

        if (await _context.CuentasFinancieras.AnyAsync(c => c.Nombre == request.Nombre.Trim() && c.Id != id))
        {
            throw new ConflictException("Ya existe una cuenta financiera con ese nombre");
        }

        // Cambiar la naturaleza de una cuenta con movimientos mezclaría, por
        // ejemplo, una Caja que de golpe se cree Banco: el saldo ya acumulado
        // seguiria significando lo que significaba antes.
        if (cuenta.Naturaleza != request.Naturaleza
            && await _context.MovimientosCuenta.AnyAsync(m => m.CuentaFinancieraId == id))
        {
            throw new BadRequestException(
                "Esta cuenta ya tiene movimientos: no se le puede cambiar la naturaleza");
        }

        Aplicar(cuenta, request);
        cuenta.Activo = request.Activo;

        await _context.SaveChangesAsync();

        var response = Map(cuenta);
        await _notificador.AvisarAsync("cuentasfinancieras", "actualizada", response);
        return response;
    }

    public async Task<IEnumerable<MovimientoCuentaResponse>> MovimientosAsync(
        int cuentaFinancieraId, DateTime? desde, DateTime? hasta)
    {
        var query = _context.MovimientosCuenta
            .AsNoTracking()
            .Include(m => m.Usuario)
            .Where(m => m.CuentaFinancieraId == cuentaFinancieraId);

        if (desde is not null) query = query.Where(m => m.Fecha >= desde.Value.Date);
        if (hasta is not null) query = query.Where(m => m.Fecha < hasta.Value.Date.AddDays(1));

        return await query
            .OrderByDescending(m => m.Fecha).ThenByDescending(m => m.Id)
            .Select(m => new MovimientoCuentaResponse
            {
                Id = m.Id,
                CuentaFinancieraId = m.CuentaFinancieraId,
                Tipo = m.Tipo,
                Monto = m.Monto,
                SaldoResultante = m.SaldoResultante,
                Fecha = m.Fecha,
                DocumentoOrigen = m.DocumentoOrigen,
                OrigenId = m.OrigenId,
                MovimientoOrigenId = m.MovimientoOrigenId,
                Usuario = m.Usuario!.Nombre,
                Observacion = m.Observacion,
            })
            .ToListAsync();
    }

    public async Task<MovimientoCuenta> PostearAsync(
        int cuentaFinancieraId,
        string tipo,
        decimal monto,
        string documentoOrigen,
        int? origenId,
        int? usuarioId,
        DateTime? fecha = null,
        string? observacion = null)
    {
        if (monto <= 0) throw new BadRequestException("El monto a postear tiene que ser mayor a cero");

        var cuenta = await GetOrThrowAsync(cuentaFinancieraId);

        cuenta.SaldoActual += tipo == TipoMovimientoCuenta.Ingreso ? monto : -monto;

        var movimiento = new MovimientoCuenta
        {
            CuentaFinancieraId = cuenta.Id,
            Tipo = tipo,
            Monto = monto,
            SaldoResultante = cuenta.SaldoActual,
            Fecha = fecha ?? DateTime.UtcNow,
            DocumentoOrigen = documentoOrigen,
            OrigenId = origenId,
            UsuarioId = usuarioId,
            Observacion = observacion,
        };

        _context.MovimientosCuenta.Add(movimiento);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("cuentasfinancieras", "movimiento", new { cuenta.Id, cuenta.SaldoActual });

        return movimiento;
    }

    public async Task<MovimientoCuenta> ReversarAsync(int movimientoId, int? usuarioId)
    {
        var original = await _context.MovimientosCuenta.FirstOrDefaultAsync(m => m.Id == movimientoId)
            ?? throw new NotFoundException($"No existe el movimiento {movimientoId}");

        var tipoEspejo = original.Tipo == TipoMovimientoCuenta.Ingreso
            ? TipoMovimientoCuenta.Egreso
            : TipoMovimientoCuenta.Ingreso;

        var reversa = await PostearAsync(
            original.CuentaFinancieraId,
            tipoEspejo,
            original.Monto,
            DocumentoOrigenMovimiento.Reversion,
            original.Id,
            usuarioId,
            observacion: $"Reversa el movimiento #{original.Id}");

        reversa.MovimientoOrigenId = original.Id;
        await _context.SaveChangesAsync();

        return reversa;
    }

    public async Task<decimal> SaldoAFechaAsync(int cuentaFinancieraId, DateTime fecha)
    {
        var limite = fecha.Date.AddDays(1).AddTicks(-1);

        var ultimo = await _context.MovimientosCuenta
            .AsNoTracking()
            .Where(m => m.CuentaFinancieraId == cuentaFinancieraId && m.Fecha <= limite)
            .OrderByDescending(m => m.Fecha).ThenByDescending(m => m.Id)
            .FirstOrDefaultAsync();

        return ultimo?.SaldoResultante ?? 0;
    }

    public async Task<CuentaFinanciera> GetOrCrearCajaUsuarioAsync(int usuarioId)
    {
        var existente = await _context.CuentasFinancieras.FirstOrDefaultAsync(c =>
            c.Naturaleza == NaturalezaCuenta.Caja && c.UsuarioResponsableId == usuarioId);
        if (existente is not null) return existente;

        var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.Id == usuarioId)
            ?? throw new NotFoundException($"No existe el usuario {usuarioId}");

        var caja = new CuentaFinanciera
        {
            Nombre = $"Caja de {usuario.Nombre}",
            Naturaleza = NaturalezaCuenta.Caja,
            UsuarioResponsableId = usuarioId,
            SaldoActual = 0,
            Activo = true,
        };

        _context.CuentasFinancieras.Add(caja);
        await _context.SaveChangesAsync();
        return caja;
    }

    public async Task<(MovimientoCuenta Salida, MovimientoCuenta Entrada)> TransferirAsync(
        int cuentaOrigenId,
        int cuentaDestinoId,
        decimal monto,
        string documentoOrigen,
        int? origenId,
        int? usuarioId,
        DateTime? fecha = null,
        string? observacion = null)
    {
        var salida = await PostearAsync(
            cuentaOrigenId, TipoMovimientoCuenta.Egreso, monto, documentoOrigen, origenId, usuarioId, fecha, observacion);
        var entrada = await PostearAsync(
            cuentaDestinoId, TipoMovimientoCuenta.Ingreso, monto, documentoOrigen, origenId, usuarioId, fecha, observacion);

        return (salida, entrada);
    }

    public async Task ReversarTransferenciaAsync(int movimientoSalidaId, int movimientoEntradaId, int? usuarioId)
    {
        await ReversarAsync(movimientoSalidaId, usuarioId);
        await ReversarAsync(movimientoEntradaId, usuarioId);
    }

    private static void Aplicar(CuentaFinanciera cuenta, CuentaFinancieraRequest request)
    {
        cuenta.Nombre = request.Nombre.Trim();
        cuenta.Naturaleza = request.Naturaleza;

        if (request.Naturaleza == NaturalezaCuenta.Caja)
        {
            cuenta.Banco = null;
            cuenta.NumeroCuenta = null;
            cuenta.Cci = null;
            cuenta.Titular = null;
            return;
        }

        cuenta.Banco = Limpiar(request.Banco);
        cuenta.NumeroCuenta = Limpiar(request.NumeroCuenta);
        cuenta.Cci = Limpiar(request.Cci);
        cuenta.Titular = Limpiar(request.Titular);
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static CuentaFinancieraResponse Map(CuentaFinanciera c) => new()
    {
        Id = c.Id,
        Nombre = c.Nombre,
        Naturaleza = c.Naturaleza,
        UsuarioResponsableId = c.UsuarioResponsableId,
        UsuarioResponsable = c.UsuarioResponsable?.Nombre,
        Banco = c.Banco,
        NumeroCuenta = c.NumeroCuenta,
        Cci = c.Cci,
        Titular = c.Titular,
        SaldoActual = c.SaldoActual,
        Activo = c.Activo,
        FechaCreacion = c.FechaCreacion,
    };
}
