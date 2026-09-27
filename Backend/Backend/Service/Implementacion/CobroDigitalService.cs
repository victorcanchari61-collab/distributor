using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// El cuadre de lo que no pasa por la caja.
///
/// El efectivo se cuadra contando, en el cierre. Un Yape o una transferencia
/// entra directo al banco, así que el vendedor podría registrar un cobro que
/// nunca llegó: por eso cada uno lleva su número de operación y queda
/// PENDIENTE hasta que alguien lo busca en el banco.
/// </summary>
public class CobroDigitalService : ICobroDigitalService
{
    private readonly AppDbContext _context;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IValidator<RechazarCobroRequest> _rechazoValidator;
    private readonly INotificador _notificador;

    public CobroDigitalService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IValidator<RechazarCobroRequest> rechazoValidator,
        INotificador notificador)
    {
        _context = context;
        _cuentas = cuentas;
        _rechazoValidator = rechazoValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<CobroDigitalResponse>> ListarAsync(DateTime desde, DateTime hasta)
    {
        var inicio = Zona.AUtc(desde.Date);
        var fin = Zona.AUtc(hasta.Date.AddDays(1));

        // Los pendientes salen siempre: uno viejo sin verificar no puede
        // perderse de vista solo porque cayó fuera de las fechas.
        return await FilasAsync(Vigentes().Where(p =>
            (p.Fecha >= inicio && p.Fecha < fin) || p.EstadoVerificacion == EstadoVerificacionCobro.Pendiente));
    }

    public Task<List<CobroDigitalResponse>> DelPeriodoAsync(int usuarioId, DateTime? desdeExclusivo, DateTime hasta) =>
        FilasAsync(Vigentes().Where(p =>
            p.UsuarioId == usuarioId && p.Fecha <= hasta && (desdeExclusivo == null || p.Fecha > desdeExclusivo)));

    public async Task<CobroDigitalResponse> VerificarAsync(int pagoId, int? usuarioId)
    {
        var pago = await ExigirVigenteAsync(pagoId);

        if (pago.EstadoVerificacion != EstadoVerificacionCobro.Pendiente)
        {
            throw new BadRequestException(pago.EstadoVerificacion == EstadoVerificacionCobro.Verificado
                ? "Ese cobro ya está verificado"
                : "Ese cobro ya se rechazó");
        }

        pago.EstadoVerificacion = EstadoVerificacionCobro.Verificado;
        pago.VerificadoPorId = usuarioId;
        pago.VerificadoEn = DateTime.UtcNow;
        pago.ObservacionVerificacion = null;
        await _context.SaveChangesAsync();

        await AvisarAsync(pago, "verificado");
        return await FilaAsync(pagoId);
    }

    public async Task<CobroDigitalResponse> QuitarVerificacionAsync(int pagoId)
    {
        var pago = await ExigirVigenteAsync(pagoId);

        if (pago.EstadoVerificacion != EstadoVerificacionCobro.Verificado)
        {
            throw new BadRequestException("Solo se puede quitar la verificación a un cobro verificado");
        }

        pago.EstadoVerificacion = EstadoVerificacionCobro.Pendiente;
        pago.VerificadoPorId = null;
        pago.VerificadoEn = null;
        await _context.SaveChangesAsync();

        await AvisarAsync(pago, "pendiente");
        return await FilaAsync(pagoId);
    }

    public async Task<CobroDigitalResponse> RechazarAsync(int pagoId, RechazarCobroRequest request, int? usuarioId)
    {
        await _rechazoValidator.ValidateAndThrowAsync(request);

        var pago = await ExigirVigenteAsync(pagoId);

        if (pago.EstadoVerificacion != EstadoVerificacionCobro.Pendiente)
        {
            throw new BadRequestException(pago.EstadoVerificacion == EstadoVerificacionCobro.Verificado
                ? "Ese cobro está verificado: quítale la verificación primero"
                : "Ese cobro ya se rechazó");
        }

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        // La plata no está en el banco: el ingreso que dejó el cobro se reversa.
        if (pago.MovimientoCuentaId is int movimientoId)
        {
            await _cuentas.ReversarAsync(movimientoId, usuarioId);
            pago.MovimientoCuentaId = null;
        }

        pago.EstadoVerificacion = EstadoVerificacionCobro.Rechazado;
        pago.VerificadoPorId = usuarioId;
        pago.VerificadoEn = DateTime.UtcNow;
        pago.ObservacionVerificacion = request.Observacion.Trim();

        /*
         * La venta NO vuelve a quedar por cobrar: quien cobró dijo que el
         * cliente pagó, así que ahora el que debe es él, igual que con un
         * faltante de caja. Si resulta que el cliente de verdad no pagó, se
         * anula el cobro en la venta y este descuento se cae solo.
         */
        if (pago.UsuarioId is int cobradorId)
        {
            _context.DescuentosFaltante.Add(new DescuentoFaltante
            {
                PagoVentaId = pago.Id,
                UsuarioId = cobradorId,
                Monto = Math.Round(pago.Monto, 2),
            });
        }

        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await AvisarAsync(pago, "rechazado");
        await _notificador.AvisarAsync("cuentasfinancieras", "cobroRechazado", new { PagoId = pago.Id });
        return await FilaAsync(pagoId);
    }

    public async Task ExigirNumeroLibreAsync(int cuentaFinancieraId, string numeroOperacion, int? excluirPagoId)
    {
        // Solo cuenta lo vigente: si la venta se anuló y se rehízo, el mismo
        // Yape vuelve a registrarse en la nueva.
        var repetido = await _context.PagosVenta
            .AsNoTracking()
            .Where(p => p.NumeroOperacion == numeroOperacion
                        && !p.Anulado
                        && p.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && p.MetodoPago!.CuentaFinancieraId == cuentaFinancieraId
                        && (excluirPagoId == null || p.Id != excluirPagoId))
            .Select(p => p.NotaVenta!.Numero)
            .FirstOrDefaultAsync();

        if (repetido is not null)
        {
            throw new BadRequestException(
                $"La operación {numeroOperacion} ya está cobrada en la {repetido}: un mismo Yape o transferencia no se registra dos veces.");
        }
    }

    public async Task LiberarDescuentoAsync(int pagoId)
    {
        var descuento = await _context.DescuentosFaltante
            .Include(d => d.Usuario)
            .FirstOrDefaultAsync(d => d.PagoVentaId == pagoId && d.Estado != EstadoDescuentoFaltante.Anulado);

        if (descuento is null) return;

        if (descuento.MontoAplicado > 0)
        {
            throw new BadRequestException(
                $"Ese cobro se rechazó y ya se le descontó a {descuento.Usuario?.Nombre ?? "quien lo cobró"} en una planilla pagada: anula primero esa planilla.");
        }

        descuento.Estado = EstadoDescuentoFaltante.Anulado;
    }

    /// <summary>Los cobros digitales que siguen valiendo: ni anulados ni de una venta anulada.</summary>
    private IQueryable<PagoVenta> Vigentes() => _context.PagosVenta
        .AsNoTracking()
        .Where(p => p.EstadoVerificacion != null
                    && !p.Anulado
                    && p.NotaVenta!.Estado != EstadoNotaVenta.Anulada);

    private async Task<PagoVenta> ExigirVigenteAsync(int pagoId)
    {
        var pago = await _context.PagosVenta
            .Include(p => p.NotaVenta)
            .FirstOrDefaultAsync(p => p.Id == pagoId)
            ?? throw new NotFoundException($"No existe el cobro {pagoId}");

        if (pago.EstadoVerificacion is null)
        {
            throw new BadRequestException("Ese cobro es en efectivo: se cuadra contando, en el cierre de caja");
        }

        if (pago.Anulado || pago.NotaVenta?.Estado == EstadoNotaVenta.Anulada)
        {
            throw new BadRequestException("Ese cobro está anulado");
        }

        return pago;
    }

    private async Task<CobroDigitalResponse> FilaAsync(int pagoId) =>
        (await FilasAsync(_context.PagosVenta.AsNoTracking().Where(p => p.Id == pagoId))).First();

    private async Task<List<CobroDigitalResponse>> FilasAsync(IQueryable<PagoVenta> consulta)
    {
        // La cuenta es la del ingreso que dejó en el libro; si ya se reversó
        // (rechazado), la que tiene su método de pago.
        var filas = await consulta
            .OrderByDescending(p => p.Fecha).ThenByDescending(p => p.Id)
            .Select(p => new CobroDigitalResponse
            {
                Id = p.Id,
                Fecha = p.Fecha,
                NotaVentaId = p.NotaVentaId,
                Documento = p.NotaVenta!.Numero,
                Cliente = p.NotaVenta.Cliente != null ? p.NotaVenta.Cliente.Nombre : null,
                UsuarioId = p.UsuarioId,
                Usuario = p.Usuario != null ? p.Usuario.Nombre : null,
                MetodoPago = p.MetodoPago!.Nombre,
                MetodoTipo = p.MetodoPago.Tipo,
                Cuenta = _context.MovimientosCuenta
                             .Where(m => m.Id == p.MovimientoCuentaId)
                             .Select(m => m.CuentaFinanciera!.Nombre)
                             .FirstOrDefault()
                         ?? (p.MetodoPago.CuentaFinanciera != null ? p.MetodoPago.CuentaFinanciera.Nombre : null),
                NumeroOperacion = p.NumeroOperacion,
                Monto = p.Monto,
                Estado = p.EstadoVerificacion!,
                VerificadoPor = p.VerificadoPor != null ? p.VerificadoPor.Nombre : null,
                VerificadoEn = p.VerificadoEn,
                Observacion = p.ObservacionVerificacion,
            })
            .ToListAsync();

        var rechazados = filas.Where(f => f.Estado == EstadoVerificacionCobro.Rechazado).Select(f => f.Id).ToList();
        if (rechazados.Count == 0) return filas;

        var descuentos = await _context.DescuentosFaltante
            .AsNoTracking()
            .Where(d => d.PagoVentaId != null && rechazados.Contains(d.PagoVentaId.Value))
            .ToDictionaryAsync(d => d.PagoVentaId!.Value);

        var cobradores = descuentos.Values.Select(d => d.UsuarioId).Distinct().ToList();
        var conEmpleado = (await _context.Usuarios
                .Where(u => cobradores.Contains(u.Id) && u.EmpleadoId != null)
                .Select(u => u.Id)
                .ToListAsync())
            .ToHashSet();

        foreach (var fila in filas)
        {
            if (!descuentos.TryGetValue(fila.Id, out var d)) continue;

            fila.Descuento = new DescuentoFaltanteResponse
            {
                Id = d.Id,
                Monto = d.Monto,
                MontoAplicado = d.MontoAplicado,
                Saldo = d.Saldo,
                Estado = d.Estado,
            };
            fila.SinEmpleado = d.Estado != EstadoDescuentoFaltante.Anulado && !conEmpleado.Contains(d.UsuarioId);
        }

        return filas;
    }

    /// <summary>Cambia la bandeja de verificación y el estado del cobro en su venta y en Mi Caja.</summary>
    private async Task AvisarAsync(PagoVenta pago, string accion)
    {
        await _notificador.AvisarAsync("cierrescaja", accion, new { PagoId = pago.Id });
        await _notificador.AvisarAsync("notasventa", "pago", new { pago.NotaVentaId });
    }
}
