using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class CierreCajaService : ICierreCajaService
{
    private readonly AppDbContext _context;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IValidator<CerrarCajaRequest> _validator;
    private readonly INotificador _notificador;

    public CierreCajaService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IValidator<CerrarCajaRequest> validator,
        INotificador notificador)
    {
        _context = context;
        _cuentas = cuentas;
        _validator = validator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<CuentaDestinoResponse>> DestinosAsync(int usuarioId)
    {
        var caja = await _cuentas.ExigirCajaUsuarioAsync(usuarioId);

        return await _context.CuentasFinancieras
            .AsNoTracking()
            .Where(c => c.Activo && c.Id != caja.Id)
            .OrderBy(c => c.Naturaleza).ThenBy(c => c.Nombre)
            .Select(c => new CuentaDestinoResponse { Id = c.Id, Nombre = c.Nombre, Naturaleza = c.Naturaleza })
            .ToListAsync();
    }

    public async Task<CierreCajaResponse> CerrarAsync(int usuarioId, CerrarCajaRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        var caja = await _cuentas.ExigirCajaUsuarioAsync(usuarioId);

        if (request.CuentaDestinoId == caja.Id)
        {
            throw new BadRequestException("Elige otra cuenta: no puedes entregarte a tu propia caja");
        }

        var destino = await _cuentas.GetOrThrowAsync(request.CuentaDestinoId);
        if (!destino.Activo) throw new BadRequestException("Esa cuenta está desactivada");

        var cierre = new CierreCaja
        {
            CuentaFinancieraId = caja.Id,
            UsuarioId = usuarioId,
            Fecha = DateTime.UtcNow,
            // Antes de mover nada: es lo que la caja decía tener, contra lo que
            // se compara lo contado.
            SaldoSistema = caja.SaldoActual,
            Billetes = Math.Round(request.Billetes, 2),
            Monedas = Math.Round(request.Monedas, 2),
            CuentaDestinoId = destino.Id,
            Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
        };

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        _context.CierresCaja.Add(cierre);
        await _context.SaveChangesAsync();

        if (cierre.Contado > 0)
        {
            var (salida, entrada) = await _cuentas.TransferirAsync(
                caja.Id, destino.Id, cierre.Contado,
                DocumentoOrigenMovimiento.CierreCaja, cierre.Id, usuarioId, cierre.Fecha,
                $"Cierre de {caja.Nombre}");

            cierre.MovimientoSalidaId = salida.Id;
            cierre.MovimientoEntradaId = entrada.Id;
        }

        // La caja queda en cero: si la diferencia se quedara en ella, el
        // siguiente cierre la volvería a cobrar como faltante.
        var diferencia = cierre.Diferencia;
        if (diferencia < 0)
        {
            var faltante = -diferencia;
            var ajuste = await _cuentas.PostearAsync(
                caja.Id, TipoMovimientoCuenta.Egreso, faltante,
                DocumentoOrigenMovimiento.FaltanteCaja, cierre.Id, usuarioId, cierre.Fecha,
                "Faltante del cierre: se descuenta en planilla");
            cierre.MovimientoAjusteId = ajuste.Id;

            _context.DescuentosFaltante.Add(new DescuentoFaltante
            {
                CierreCajaId = cierre.Id,
                UsuarioId = usuarioId,
                Monto = faltante,
            });
        }
        else if (diferencia > 0)
        {
            var ajuste = await _cuentas.PostearAsync(
                caja.Id, TipoMovimientoCuenta.Ingreso, diferencia,
                DocumentoOrigenMovimiento.SobranteCaja, cierre.Id, usuarioId, cierre.Fecha,
                "Sobrante del cierre");
            cierre.MovimientoAjusteId = ajuste.Id;
        }

        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("cuentasfinancieras", "cierre", new { CajaId = caja.Id, DestinoId = destino.Id });
        await _notificador.AvisarAsync("cierrescaja", "creado", new { cierre.Id });
        return await GetAsync(cierre.Id);
    }

    public async Task<IEnumerable<CierreCajaResponse>> ListarAsync(DateTime desde, DateTime hasta)
    {
        var inicio = Zona.AUtc(desde.Date);
        var fin = Zona.AUtc(hasta.Date.AddDays(1));

        var cierres = await Consulta()
            .Where(c => c.Fecha >= inicio && c.Fecha < fin)
            .OrderByDescending(c => c.Fecha).ThenByDescending(c => c.Id)
            .ToListAsync();

        var conEmpleado = await UsuariosConEmpleadoAsync(cierres.Select(c => c.UsuarioId));
        return cierres.Select(c => Map(c, conEmpleado.Contains(c.UsuarioId)));
    }

    public async Task<CierreCajaResponse> AnularAsync(int id, int? usuarioId)
    {
        var cierre = await _context.CierresCaja
            .Include(c => c.Descuento)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException($"No existe el cierre {id}");

        if (cierre.Anulado) throw new BadRequestException("Ese cierre ya está anulado");

        if (cierre.Descuento is { MontoAplicado: > 0 })
        {
            throw new BadRequestException(
                "Su faltante ya se descontó en una planilla pagada: anula primero esa planilla");
        }

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        if (cierre.MovimientoSalidaId is int salida && cierre.MovimientoEntradaId is int entrada)
        {
            await _cuentas.ReversarTransferenciaAsync(salida, entrada, usuarioId);
        }

        if (cierre.MovimientoAjusteId is int ajuste)
        {
            await _cuentas.ReversarAsync(ajuste, usuarioId);
        }

        if (cierre.Descuento is not null)
        {
            cierre.Descuento.Estado = EstadoDescuentoFaltante.Anulado;
        }

        cierre.Anulado = true;
        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("cuentasfinancieras", "cierreAnulado", new { cierre.Id });
        await _notificador.AvisarAsync("cierrescaja", "anulado", new { cierre.Id });
        return await GetAsync(id);
    }

    private IQueryable<CierreCaja> Consulta() => _context.CierresCaja
        .AsNoTracking()
        .Include(c => c.Usuario)
        .Include(c => c.CuentaFinanciera)
        .Include(c => c.CuentaDestino)
        .Include(c => c.Descuento);

    private async Task<CierreCajaResponse> GetAsync(int id)
    {
        var cierre = await Consulta().FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException($"No existe el cierre {id}");
        var conEmpleado = await UsuariosConEmpleadoAsync([cierre.UsuarioId]);
        return Map(cierre, conEmpleado.Contains(cierre.UsuarioId));
    }

    private async Task<HashSet<int>> UsuariosConEmpleadoAsync(IEnumerable<int> usuarioIds)
    {
        var ids = usuarioIds.Distinct().ToList();
        return (await _context.Usuarios
                .Where(u => ids.Contains(u.Id) && u.EmpleadoId != null)
                .Select(u => u.Id)
                .ToListAsync())
            .ToHashSet();
    }

    private static CierreCajaResponse Map(CierreCaja c, bool tieneEmpleado) => new()
    {
        Id = c.Id,
        Fecha = c.Fecha,
        UsuarioId = c.UsuarioId,
        Usuario = c.Usuario?.Nombre ?? string.Empty,
        Caja = c.CuentaFinanciera?.Nombre ?? string.Empty,
        SaldoSistema = c.SaldoSistema,
        Billetes = c.Billetes,
        Monedas = c.Monedas,
        Contado = c.Contado,
        Diferencia = c.Diferencia,
        CuentaDestinoId = c.CuentaDestinoId,
        CuentaDestino = c.CuentaDestino?.Nombre ?? string.Empty,
        Observacion = c.Observacion,
        Anulado = c.Anulado,
        Descuento = c.Descuento is null ? null : new DescuentoFaltanteResponse
        {
            Id = c.Descuento.Id,
            Monto = c.Descuento.Monto,
            MontoAplicado = c.Descuento.MontoAplicado,
            Saldo = c.Descuento.Saldo,
            Estado = c.Descuento.Estado,
        },
        SinEmpleado = c.Descuento is not null && !tieneEmpleado,
    };
}
