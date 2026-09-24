using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

public class ConciliacionBancariaService : IConciliacionBancariaService
{
    private readonly AppDbContext _context;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IValidator<ConciliacionBancariaRequest> _validator;
    private readonly INotificador _notificador;

    public ConciliacionBancariaService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IValidator<ConciliacionBancariaRequest> validator,
        INotificador notificador)
    {
        _context = context;
        _cuentas = cuentas;
        _validator = validator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<ConciliacionBancariaResponse>> ListarAsync(int cuentaFinancieraId)
    {
        var conciliaciones = await _context.ConciliacionesBancarias
            .AsNoTracking()
            .Include(c => c.CuentaFinanciera)
            .Include(c => c.Usuario)
            .Where(c => c.CuentaFinancieraId == cuentaFinancieraId)
            .OrderByDescending(c => c.Fecha)
            .ToListAsync();

        return conciliaciones.Select(Map);
    }

    public async Task<ConciliacionBancariaResponse> CrearAsync(ConciliacionBancariaRequest request, int? usuarioId)
    {
        await _validator.ValidateAndThrowAsync(request);

        var cuenta = await _cuentas.GetOrThrowAsync(request.CuentaFinancieraId);
        if (cuenta.Naturaleza == NaturalezaCuenta.Caja)
        {
            throw new BadRequestException("La Caja General no se concilia contra un extracto bancario");
        }

        var saldoContable = await _cuentas.SaldoAFechaAsync(cuenta.Id, request.Fecha);

        var conciliacion = new ConciliacionBancaria
        {
            CuentaFinancieraId = cuenta.Id,
            Fecha = request.Fecha.Date,
            SaldoExtracto = request.SaldoExtracto,
            SaldoContable = saldoContable,
            Observacion = request.Observacion?.Trim(),
            Estado = EstadoConciliacion.Pendiente,
            UsuarioId = usuarioId,
        };

        _context.ConciliacionesBancarias.Add(conciliacion);
        await _context.SaveChangesAsync();

        var response = await GetOrThrowAsync(conciliacion.Id);
        await _notificador.AvisarAsync("conciliaciones", "creada", response);
        return response;
    }

    public async Task<ConciliacionBancariaResponse> MarcarConciliadaAsync(int id)
    {
        var conciliacion = await _context.ConciliacionesBancarias.FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException($"No existe la conciliación {id}");

        if (conciliacion.Estado == EstadoConciliacion.Conciliado)
        {
            throw new BadRequestException("Esa conciliación ya está marcada como conciliada");
        }

        conciliacion.Estado = EstadoConciliacion.Conciliado;
        await _context.SaveChangesAsync();

        var response = await GetOrThrowAsync(id);
        await _notificador.AvisarAsync("conciliaciones", "conciliada", response);
        return response;
    }

    private async Task<ConciliacionBancariaResponse> GetOrThrowAsync(int id) =>
        Map(await _context.ConciliacionesBancarias
            .AsNoTracking()
            .Include(c => c.CuentaFinanciera)
            .Include(c => c.Usuario)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException($"No existe la conciliación {id}"));

    private static ConciliacionBancariaResponse Map(ConciliacionBancaria c) => new()
    {
        Id = c.Id,
        CuentaFinancieraId = c.CuentaFinancieraId,
        CuentaFinanciera = c.CuentaFinanciera?.Nombre ?? string.Empty,
        Fecha = c.Fecha,
        SaldoExtracto = c.SaldoExtracto,
        SaldoContable = c.SaldoContable,
        Diferencia = c.Diferencia,
        Observacion = c.Observacion,
        Estado = c.Estado,
        Usuario = c.Usuario?.Nombre,
        FechaCreacion = c.FechaCreacion,
    };
}
