using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class FinanciamientoService : IFinanciamientoService
{
    private readonly AppDbContext _context;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IValidator<CrearFinanciamientoRequest> _crearValidator;
    private readonly IValidator<PagoFinanciamientoRequest> _pagoValidator;
    private readonly INotificador _notificador;

    public FinanciamientoService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IValidator<CrearFinanciamientoRequest> crearValidator,
        IValidator<PagoFinanciamientoRequest> pagoValidator,
        INotificador notificador)
    {
        _context = context;
        _cuentas = cuentas;
        _crearValidator = crearValidator;
        _pagoValidator = pagoValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<FinanciamientoResponse>> ListarAsync()
    {
        var financiamientos = await Consulta()
            .OrderByDescending(f => f.Fecha).ThenByDescending(f => f.Id)
            .ToListAsync();
        return financiamientos.Select(Map);
    }

    public async Task<FinanciamientoResponse> GetAsync(int id) =>
        Map(await Consulta().FirstOrDefaultAsync(f => f.Id == id)
            ?? throw new NotFoundException($"No existe el préstamo {id}"));

    public async Task<FinanciamientoResponse> CrearAsync(CrearFinanciamientoRequest request, int? usuarioId)
    {
        await _crearValidator.ValidateAndThrowAsync(request);
        var cuenta = await CuentaActivaAsync(request.CuentaFinancieraId);

        var recibido = Math.Round(request.MontoRecibido, 2);
        var financiamiento = new Financiamiento
        {
            Acreedor = request.Acreedor.Trim(),
            Descripcion = string.IsNullOrWhiteSpace(request.Descripcion) ? null : request.Descripcion.Trim(),
            Fecha = request.Fecha ?? DateTime.UtcNow,
            MontoRecibido = recibido,
            TotalADevolver = Math.Round(request.TotalADevolver ?? recibido, 2),
            CuentaFinancieraId = cuenta.Id,
            UsuarioId = usuarioId,
        };

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        _context.Financiamientos.Add(financiamiento);
        await _context.SaveChangesAsync();

        var ingreso = await _cuentas.PostearAsync(
            cuenta.Id, TipoMovimientoCuenta.Ingreso, recibido,
            DocumentoOrigenMovimiento.Financiamiento, financiamiento.Id, usuarioId, financiamiento.Fecha,
            $"Préstamo de {financiamiento.Acreedor}");
        financiamiento.MovimientoCuentaId = ingreso.Id;

        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await AvisarAsync("creado", financiamiento.Id);
        return await GetAsync(financiamiento.Id);
    }

    public async Task<FinanciamientoResponse> RegistrarPagoAsync(int id, PagoFinanciamientoRequest request, int? usuarioId)
    {
        await _pagoValidator.ValidateAndThrowAsync(request);

        var financiamiento = await ConPagosAsync(id);
        if (financiamiento.Estado != EstadoFinanciamiento.Vigente)
        {
            throw new BadRequestException(financiamiento.Estado == EstadoFinanciamiento.Cancelado
                ? "Este préstamo ya está pagado"
                : "Este préstamo está anulado");
        }

        var monto = Math.Round(request.Monto, 2);
        if (monto > financiamiento.Saldo)
        {
            throw new BadRequestException(
                $"El pago (S/ {monto:N2}) es más de lo que falta pagar (S/ {financiamiento.Saldo:N2})");
        }

        var cuenta = await CuentaActivaAsync(request.CuentaFinancieraId);

        var pago = new PagoFinanciamiento
        {
            Fecha = request.Fecha ?? DateTime.UtcNow,
            Monto = monto,
            CuentaFinancieraId = cuenta.Id,
            UsuarioId = usuarioId,
            Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
        };

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        financiamiento.Pagos.Add(pago);
        await _context.SaveChangesAsync();

        var egreso = await _cuentas.PostearAsync(
            cuenta.Id, TipoMovimientoCuenta.Egreso, monto,
            DocumentoOrigenMovimiento.PagoFinanciamiento, pago.Id, usuarioId, pago.Fecha,
            $"Pago de préstamo a {financiamiento.Acreedor}");
        pago.MovimientoCuentaId = egreso.Id;

        if (financiamiento.Saldo <= 0) financiamiento.Estado = EstadoFinanciamiento.Cancelado;

        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await AvisarAsync("pago", financiamiento.Id);
        return await GetAsync(id);
    }

    public async Task<FinanciamientoResponse> AnularPagoAsync(int id, int pagoId, int? usuarioId)
    {
        var financiamiento = await ConPagosAsync(id);
        if (financiamiento.Estado == EstadoFinanciamiento.Anulado) throw new BadRequestException("Este préstamo está anulado");

        var pago = financiamiento.Pagos.FirstOrDefault(p => p.Id == pagoId)
            ?? throw new NotFoundException($"Este préstamo no tiene el pago {pagoId}");
        if (pago.Anulado) throw new BadRequestException("Ese pago ya está anulado");

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        if (pago.MovimientoCuentaId is int movimiento)
        {
            await _cuentas.ReversarAsync(movimiento, usuarioId);
        }

        pago.Anulado = true;
        if (financiamiento.Saldo > 0) financiamiento.Estado = EstadoFinanciamiento.Vigente;

        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await AvisarAsync("pagoAnulado", financiamiento.Id);
        return await GetAsync(id);
    }

    public async Task<FinanciamientoResponse> AnularAsync(int id, int? usuarioId)
    {
        var financiamiento = await ConPagosAsync(id);
        if (financiamiento.Estado == EstadoFinanciamiento.Anulado) throw new BadRequestException("Este préstamo ya está anulado");

        if (financiamiento.Pagos.Any(p => !p.Anulado))
        {
            throw new BadRequestException("Tiene pagos registrados: anúlalos primero");
        }

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        if (financiamiento.MovimientoCuentaId is int movimiento)
        {
            await _cuentas.ReversarAsync(movimiento, usuarioId);
        }

        financiamiento.Estado = EstadoFinanciamiento.Anulado;
        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await AvisarAsync("anulado", financiamiento.Id);
        return await GetAsync(id);
    }

    public async Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync() =>
        await _context.CuentasFinancieras
            .AsNoTracking()
            .Where(c => c.Activo)
            .OrderBy(c => c.Naturaleza).ThenBy(c => c.Nombre)
            .Select(c => new CuentaDestinoResponse { Id = c.Id, Nombre = c.Nombre, Naturaleza = c.Naturaleza })
            .ToListAsync();

    // ------------------------------------------------------------ Auxiliares

    private async Task<CuentaFinanciera> CuentaActivaAsync(int id)
    {
        var cuenta = await _cuentas.GetOrThrowAsync(id);
        if (!cuenta.Activo) throw new BadRequestException("Esa cuenta está desactivada");
        return cuenta;
    }

    private async Task<Financiamiento> ConPagosAsync(int id) =>
        await _context.Financiamientos.Include(f => f.Pagos).FirstOrDefaultAsync(f => f.Id == id)
        ?? throw new NotFoundException($"No existe el préstamo {id}");

    private IQueryable<Financiamiento> Consulta() => _context.Financiamientos
        .AsNoTracking()
        .Include(f => f.CuentaFinanciera)
        .Include(f => f.Usuario)
        .Include(f => f.Pagos).ThenInclude(p => p.CuentaFinanciera)
        .Include(f => f.Pagos).ThenInclude(p => p.Usuario);

    private async Task AvisarAsync(string accion, int id)
    {
        await _notificador.AvisarAsync("financiamientos", accion, new { id });
        await _notificador.AvisarAsync("cuentasfinancieras", "movimiento", new { FinanciamientoId = id });
    }

    private static FinanciamientoResponse Map(Financiamiento f) => new()
    {
        Id = f.Id,
        Acreedor = f.Acreedor,
        Descripcion = f.Descripcion,
        Fecha = f.Fecha,
        MontoRecibido = f.MontoRecibido,
        TotalADevolver = f.TotalADevolver,
        Pagado = f.Pagado,
        Saldo = f.Estado == EstadoFinanciamiento.Anulado ? 0 : f.Saldo,
        Estado = f.Estado,
        CuentaFinancieraId = f.CuentaFinancieraId,
        CuentaFinanciera = f.CuentaFinanciera?.Nombre ?? string.Empty,
        Usuario = f.Usuario?.Nombre,
        Pagos = f.Pagos
            .OrderByDescending(p => p.Fecha).ThenByDescending(p => p.Id)
            .Select(p => new PagoFinanciamientoResponse
            {
                Id = p.Id,
                Fecha = p.Fecha,
                Monto = p.Monto,
                CuentaFinancieraId = p.CuentaFinancieraId,
                CuentaFinanciera = p.CuentaFinanciera?.Nombre ?? string.Empty,
                Anulado = p.Anulado,
                Usuario = p.Usuario?.Nombre,
                Observacion = p.Observacion,
            })
            .ToList(),
    };
}
