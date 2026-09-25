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

        _context.CierresCaja.Add(cierre);
        await _context.SaveChangesAsync();

        // Solo sale lo contado: si faltó, la diferencia se queda en su caja
        // como lo que debe; si sobró, su caja queda en negativo.
        if (cierre.Contado > 0)
        {
            var (salida, entrada) = await _cuentas.TransferirAsync(
                caja.Id, destino.Id, cierre.Contado,
                DocumentoOrigenMovimiento.CierreCaja, cierre.Id, usuarioId, cierre.Fecha,
                $"Cierre de {caja.Nombre}");

            cierre.MovimientoSalidaId = salida.Id;
            cierre.MovimientoEntradaId = entrada.Id;
            await _context.SaveChangesAsync();
        }

        var response = Map(cierre, destino.Nombre);
        await _notificador.AvisarAsync("cuentasfinancieras", "cierre", new { CajaId = caja.Id, DestinoId = destino.Id });
        return response;
    }

    private static CierreCajaResponse Map(CierreCaja c, string destino) => new()
    {
        Id = c.Id,
        Fecha = c.Fecha,
        SaldoSistema = c.SaldoSistema,
        Billetes = c.Billetes,
        Monedas = c.Monedas,
        Contado = c.Contado,
        Diferencia = c.Diferencia,
        CuentaDestinoId = c.CuentaDestinoId,
        CuentaDestino = destino,
        Observacion = c.Observacion,
    };
}
