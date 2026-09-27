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
    private readonly ICobroDigitalService _cobros;

    public CierreCajaService(
        AppDbContext context,
        ICuentaFinancieraService cuentas,
        IValidator<CerrarCajaRequest> validator,
        INotificador notificador,
        ICobroDigitalService cobros)
    {
        _context = context;
        _cuentas = cuentas;
        _validator = validator;
        _notificador = notificador;
        _cobros = cobros;
    }

    public async Task<IEnumerable<CuentaDestinoResponse>> DestinosAsync(int usuarioId)
    {
        var caja = await _cuentas.ExigirCajaUsuarioAsync(usuarioId);

        return await _context.CuentasFinancieras
            .AsNoTracking()
            .Where(c => c.Activo && c.Id != caja.Id)
            // La Bóveda primero: es adonde va el efectivo de un cierre normal.
            .OrderBy(c => c.Naturaleza == NaturalezaCuenta.Caja && c.UsuarioResponsableId == null ? 0 : 1)
            .ThenBy(c => c.Naturaleza).ThenBy(c => c.Nombre)
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

        // Con el desglose, los totales salen de él: así no pueden contradecirse.
        var contadas = request.Denominaciones
            .Where(d => d.Cantidad > 0)
            .GroupBy(d => d.Valor)
            .Select(g => new CierreCajaDenominacion { Valor = g.Key, Cantidad = g.Sum(d => d.Cantidad) })
            .OrderByDescending(d => d.Valor)
            .ToList();
        var conDesglose = request.Denominaciones.Count > 0;
        var billetes = conDesglose ? contadas.Where(d => d.EsBillete).Sum(d => d.Valor * d.Cantidad) : request.Billetes;
        var monedas = conDesglose ? contadas.Where(d => !d.EsBillete).Sum(d => d.Valor * d.Cantidad) : request.Monedas;

        var cierre = new CierreCaja
        {
            CuentaFinancieraId = caja.Id,
            UsuarioId = usuarioId,
            Fecha = DateTime.UtcNow,
            // Antes de mover nada: es lo que la caja decía tener, contra lo que
            // se compara lo contado.
            SaldoSistema = caja.SaldoActual,
            Billetes = Math.Round(billetes, 2),
            Monedas = Math.Round(monedas, 2),
            Denominaciones = contadas,
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

        return await MapearAsync(cierres);
    }

    public async Task<CierreDetalleResponse> DetalleAsync(int id)
    {
        var cierre = await Consulta()
            .Include(c => c.Denominaciones)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException($"No existe el cierre {id}");

        var desde = (await InicioDePeriodosAsync([cierre]))[cierre.Id];
        var digitales = await _cobros.DelPeriodoAsync(cierre.UsuarioId, desde, cierre.Fecha);
        var efectivo = await EfectivoDelPeriodoAsync(cierre, desde);

        // Lo que ya había en la caja al empezar: lo que explica que el saldo
        // del cierre no sea solo la suma de este periodo.
        var neto = efectivo.Sum(m => m.Tipo == TipoMovimientoCuenta.Ingreso ? m.Monto : -m.Monto);

        return new CierreDetalleResponse
        {
            Cierre = (await MapearAsync([cierre])).Single(),
            Desde = desde,
            SaldoAnterior = Math.Round(cierre.SaldoSistema - neto, 2),
            Denominaciones = cierre.Denominaciones
                .OrderByDescending(d => d.Valor)
                .Select(d => new DenominacionResponse
                {
                    Valor = d.Valor,
                    Cantidad = d.Cantidad,
                    Total = d.Valor * d.Cantidad,
                    EsBillete = d.EsBillete,
                })
                .ToList(),
            Efectivo = efectivo,
            Digitales = digitales,
        };
    }

    /// <summary>
    /// Desde cuándo cuenta cada cierre: la fecha del cierre vigente anterior de
    /// su caja, o nulo si es el primero. Uno anulado no corta: lo suyo volvió a
    /// la caja y entra en el siguiente.
    /// </summary>
    private async Task<Dictionary<int, DateTime?>> InicioDePeriodosAsync(List<CierreCaja> cierres)
    {
        if (cierres.Count == 0) return [];

        var cajaIds = cierres.Select(c => c.CuentaFinancieraId).Distinct().ToList();
        var hasta = cierres.Max(c => c.Fecha);
        var fronteras = await _context.CierresCaja
            .AsNoTracking()
            .Where(c => cajaIds.Contains(c.CuentaFinancieraId) && !c.Anulado && c.Fecha <= hasta)
            .Select(c => new { c.Id, c.CuentaFinancieraId, c.Fecha })
            .ToListAsync();

        return cierres.ToDictionary(
            c => c.Id,
            c => fronteras
                .Where(f => f.CuentaFinancieraId == c.CuentaFinancieraId && f.Id != c.Id && f.Fecha < c.Fecha)
                .Select(f => (DateTime?)f.Fecha)
                .Max());
    }

    /// <summary>
    /// Lo que pasó por la caja en el periodo, sin la entrega ni el ajuste del
    /// propio cierre: eso es el cierre, no lo que se cuadra.
    /// </summary>
    private async Task<List<MovimientoCierreResponse>> EfectivoDelPeriodoAsync(CierreCaja cierre, DateTime? desde)
    {
        // Lista y no arreglo: con un arreglo, .NET 10 elige el Contains de
        // ReadOnlySpan y EF no lo puede traducir a SQL.
        List<string> delCierre =
        [
            DocumentoOrigenMovimiento.CierreCaja,
            DocumentoOrigenMovimiento.FaltanteCaja,
            DocumentoOrigenMovimiento.SobranteCaja,
        ];

        var movimientos = await _context.MovimientosCuenta
            .AsNoTracking()
            .Where(m => m.CuentaFinancieraId == cierre.CuentaFinancieraId
                        && m.Fecha <= cierre.Fecha
                        && (desde == null || m.Fecha > desde)
                        && !(m.OrigenId == cierre.Id && delCierre.Contains(m.DocumentoOrigen)))
            .OrderBy(m => m.Fecha).ThenBy(m => m.Id)
            .Select(m => new
            {
                m.Id,
                m.Fecha,
                m.Tipo,
                m.Monto,
                m.DocumentoOrigen,
                m.OrigenId,
                m.Observacion,
                Anulado = _context.MovimientosCuenta.Any(r =>
                    r.DocumentoOrigen == DocumentoOrigenMovimiento.Reversion && r.MovimientoOrigenId == m.Id),
            })
            .ToListAsync();

        // El detalle de cada uno: la venta y su cliente, la compra y su
        // proveedor, o la categoría del gasto.
        List<int> Origenes(string documento) =>
            movimientos.Where(m => m.DocumentoOrigen == documento && m.OrigenId != null).Select(m => m.OrigenId!.Value).ToList();

        var cobros = Origenes(DocumentoOrigenMovimiento.PagoVenta);
        var ventas = await _context.PagosVenta
            .Where(p => cobros.Contains(p.Id))
            .Select(p => new { p.Id, Texto = p.NotaVenta!.Numero + (p.NotaVenta.Cliente != null ? " · " + p.NotaVenta.Cliente.Nombre : "") })
            .ToDictionaryAsync(p => p.Id, p => p.Texto);

        var pagos = Origenes(DocumentoOrigenMovimiento.PagoCompra);
        var compras = await _context.CompraPagos
            .Where(p => pagos.Contains(p.Id))
            .Select(p => new { p.Id, Texto = p.Compra!.Numero + (p.Compra.Proveedor != null ? " · " + p.Compra.Proveedor.Nombre : "") })
            .ToDictionaryAsync(p => p.Id, p => p.Texto);

        var operativos = Origenes(DocumentoOrigenMovimiento.MovimientoOperativo);
        var categorias = await _context.MovimientosOperativos
            .Where(o => operativos.Contains(o.Id))
            .Select(o => new { o.Id, Categoria = o.MotivoGasto != null ? o.MotivoGasto.Nombre : null })
            .ToDictionaryAsync(o => o.Id, o => o.Categoria);

        string? Detalle(string documento, int? origenId, string? observacion)
        {
            var id = origenId ?? 0;
            var texto = documento switch
            {
                DocumentoOrigenMovimiento.PagoVenta => ventas.GetValueOrDefault(id),
                DocumentoOrigenMovimiento.PagoCompra => compras.GetValueOrDefault(id),
                DocumentoOrigenMovimiento.MovimientoOperativo => categorias.GetValueOrDefault(id),
                _ => null,
            };
            // En un cobro o un pago la observación repite el documento ("Pago de
            // la compra CP-0003"): basta con el documento y su cliente o proveedor.
            if (texto is not null && documento != DocumentoOrigenMovimiento.MovimientoOperativo) return texto;

            return string.Join(" · ", new[] { texto, observacion }.Where(t => !string.IsNullOrWhiteSpace(t)))
                is { Length: > 0 } unido ? unido : null;
        }

        return movimientos.Select(m => new MovimientoCierreResponse
        {
            Id = m.Id,
            Fecha = m.Fecha,
            Tipo = m.Tipo,
            Monto = m.Monto,
            DocumentoOrigen = m.DocumentoOrigen,
            Detalle = Detalle(m.DocumentoOrigen, m.OrigenId, m.Observacion),
            Anulado = m.Anulado,
            EsReversa = m.DocumentoOrigen == DocumentoOrigenMovimiento.Reversion,
        }).ToList();
    }

    /// <summary>
    /// Los cierres con lo que falta para revisarlos de un vistazo: si su
    /// trabajador tiene empleado y cuánto cobró digital en su periodo.
    /// </summary>
    private async Task<List<CierreCajaResponse>> MapearAsync(List<CierreCaja> cierres)
    {
        if (cierres.Count == 0) return [];

        var conEmpleado = await UsuariosConEmpleadoAsync(cierres.Select(c => c.UsuarioId));
        var inicios = await InicioDePeriodosAsync(cierres);

        // Una sola consulta para todos: los cobros digitales de esas personas
        // entre el periodo más viejo y el cierre más nuevo, repartidos después.
        var usuarioIds = cierres.Select(c => c.UsuarioId).Distinct().ToList();
        var hasta = cierres.Max(c => c.Fecha);
        var desde = inicios.Values.Any(v => v == null) ? null : inicios.Values.Min();
        var digitales = await _context.PagosVenta
            .AsNoTracking()
            .Where(p => p.EstadoVerificacion != null
                        && !p.Anulado
                        && p.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && p.UsuarioId != null && usuarioIds.Contains(p.UsuarioId.Value)
                        && p.Fecha <= hasta
                        && (desde == null || p.Fecha > desde))
            .Select(p => new { UsuarioId = p.UsuarioId!.Value, p.Fecha, p.Monto, Estado = p.EstadoVerificacion! })
            .ToListAsync();

        return cierres.Select(c =>
        {
            var inicio = inicios[c.Id];
            var suyos = digitales
                .Where(d => d.UsuarioId == c.UsuarioId && d.Fecha <= c.Fecha && (inicio == null || d.Fecha > inicio))
                .ToList();

            var r = Map(c, conEmpleado.Contains(c.UsuarioId));
            r.Digital = suyos.Where(d => d.Estado != EstadoVerificacionCobro.Rechazado).Sum(d => d.Monto);
            r.DigitalPorVerificar = suyos.Count(d => d.Estado == EstadoVerificacionCobro.Pendiente);
            r.DigitalRechazados = suyos.Count(d => d.Estado == EstadoVerificacionCobro.Rechazado);
            return r;
        }).ToList();
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
        return (await MapearAsync([cierre])).Single();
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
