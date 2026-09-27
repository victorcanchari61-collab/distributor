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
    private readonly IValidator<TransferenciaCuentasRequest> _transferenciaValidator;
    private readonly IValidator<CuentaFinancieraRequest> _validator;
    private readonly INotificador _notificador;

    public CuentaFinancieraService(
        AppDbContext context, IValidator<CuentaFinancieraRequest> validator,
        IValidator<TransferenciaCuentasRequest> transferenciaValidator, INotificador notificador)
    {
        _context = context;
        _validator = validator;
        _transferenciaValidator = transferenciaValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<CuentaFinancieraResponse>> GetAllAsync()
    {
        var cuentas = await _context.CuentasFinancieras
            .AsNoTracking()
            .Include(c => c.UsuarioResponsable)
            .Include(c => c.Banco)
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
            .Include(c => c.Banco)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new NotFoundException($"No existe la cuenta financiera {id}");

        return Map(cuenta);
    }

    public async Task<CuentaFinanciera> GetOrThrowAsync(int id) =>
        await _context.CuentasFinancieras.FirstOrDefaultAsync(c => c.Id == id)
        ?? throw new NotFoundException($"No existe la cuenta financiera {id}");

    public async Task<CuentaFinancieraResponse> CreateAsync(CuentaFinancieraRequest request, int? usuarioId = null)
    {
        await _validator.ValidateAndThrowAsync(request);

        if (await _context.CuentasFinancieras.AnyAsync(c => c.Nombre == request.Nombre.Trim()))
        {
            throw new ConflictException("Ya existe una cuenta financiera con ese nombre");
        }

        if (request.Naturaleza == NaturalezaCuenta.Caja)
        {
            await ValidarResponsableDeCajaAsync(request.UsuarioResponsableId!.Value, cajaId: null);
        }

        var banco = request.Naturaleza == NaturalezaCuenta.Banco
            ? await ValidarBancoAsync(request.BancoId!.Value)
            : null;

        var cuenta = new CuentaFinanciera { Activo = true };
        Aplicar(cuenta, request, banco);

        _context.CuentasFinancieras.Add(cuenta);
        await _context.SaveChangesAsync();

        // Con lo que ya tenía antes de registrarla: un movimiento más, no un
        // campo aparte — así el saldo siempre sale de sumar el libro mayor, sin
        // excepciones para la conciliación ni para "Mi Caja".
        if (request.MontoInicial > 0)
        {
            await PostearAsync(
                cuenta.Id, TipoMovimientoCuenta.Ingreso, request.MontoInicial,
                DocumentoOrigenMovimiento.SaldoInicial, null, usuarioId,
                observacion: "Saldo con el que se registró la cuenta");
        }

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

        if (request.Naturaleza == NaturalezaCuenta.Caja)
        {
            await ValidarResponsableDeCajaAsync(request.UsuarioResponsableId!.Value, cajaId: id);
        }

        var banco = request.Naturaleza == NaturalezaCuenta.Banco
            ? await ValidarBancoAsync(request.BancoId!.Value)
            : null;

        Aplicar(cuenta, request, banco);
        cuenta.Activo = request.Activo;

        await _context.SaveChangesAsync();

        var response = Map(cuenta);
        await _notificador.AvisarAsync("cuentasfinancieras", "actualizada", response);
        return response;
    }

    public async Task<CuentaFinancieraResponse> CrearBovedaAsync(CrearBovedaRequest request, int? usuarioId)
    {
        if (request.MontoInicial < 0)
            throw new BadRequestException("El monto inicial no puede ser negativo");

        // Una sola: la plata de los cierres tiene que ir a un único lugar, o el
        // efectivo de la empresa queda repartido sin saber dónde está.
        if (await _context.CuentasFinancieras.AnyAsync(c =>
                c.Naturaleza == NaturalezaCuenta.Caja && c.UsuarioResponsableId == null))
        {
            throw new ConflictException("La Bóveda ya existe");
        }

        if (await _context.CuentasFinancieras.AnyAsync(c => c.Nombre == CuentaFinanciera.NombreBoveda))
        {
            throw new ConflictException(
                $"Ya hay una cuenta llamada \"{CuentaFinanciera.NombreBoveda}\": renómbrala antes de crear la Bóveda");
        }

        var boveda = new CuentaFinanciera
        {
            Nombre = CuentaFinanciera.NombreBoveda,
            Naturaleza = NaturalezaCuenta.Caja,
            UsuarioResponsableId = null,
            Activo = true,
        };
        _context.CuentasFinancieras.Add(boveda);
        await _context.SaveChangesAsync();

        // El efectivo que ya había guardado, como su primer movimiento.
        if (request.MontoInicial > 0)
        {
            await PostearAsync(
                boveda.Id, TipoMovimientoCuenta.Ingreso, Math.Round(request.MontoInicial, 2),
                DocumentoOrigenMovimiento.SaldoInicial, null, usuarioId,
                observacion: "Efectivo con el que se abrió la Bóveda");
        }

        var response = Map(boveda);
        await _notificador.AvisarAsync("cuentasfinancieras", "creada", response);
        return response;
    }

    public async Task<int> TransferirEntreCuentasAsync(TransferenciaCuentasRequest request, int? usuarioId)
    {
        await _transferenciaValidator.ValidateAndThrowAsync(request);

        var origen = await GetOrThrowAsync(request.CuentaOrigenId);
        var destino = await GetOrThrowAsync(request.CuentaDestinoId);
        if (!origen.Activo) throw new BadRequestException($"{origen.Nombre} está desactivada");
        if (!destino.Activo) throw new BadRequestException($"{destino.Nombre} está desactivada");

        // No se mueve plata que no hay: una caja no tiene efectivo de más.
        var monto = Math.Round(request.Monto, 2);
        if (origen.SaldoActual < monto)
        {
            throw new BadRequestException(
                $"{origen.Nombre} tiene S/ {Soles(origen.SaldoActual)}: no alcanza para mover S/ {Soles(monto)}");
        }

        var detalle = $"De {origen.Nombre} a {destino.Nombre}";
        if (!string.IsNullOrWhiteSpace(request.Observacion)) detalle += $" — {request.Observacion.Trim()}";

        var (salida, entrada) = await TransferirAsync(
            origen.Id, destino.Id, monto, DocumentoOrigenMovimiento.TransferenciaInterna,
            null, usuarioId, observacion: detalle);

        // Las dos mitades apuntan a la salida: con cualquiera se encuentra la otra.
        salida.OrigenId = salida.Id;
        entrada.OrigenId = salida.Id;
        await _context.SaveChangesAsync();

        return salida.Id;
    }

    public async Task AnularTransferenciaAsync(int movimientoId, int? usuarioId)
    {
        var mitad = await _context.MovimientosCuenta.AsNoTracking().FirstOrDefaultAsync(m => m.Id == movimientoId)
            ?? throw new NotFoundException($"No existe el movimiento {movimientoId}");

        if (mitad.DocumentoOrigen != DocumentoOrigenMovimiento.TransferenciaInterna || mitad.OrigenId is not int salidaId)
            throw new BadRequestException("Ese movimiento no es una transferencia entre cuentas");

        var mitades = await _context.MovimientosCuenta.AsNoTracking()
            .Where(m => m.DocumentoOrigen == DocumentoOrigenMovimiento.TransferenciaInterna && m.OrigenId == salidaId)
            .ToListAsync();
        var salida = mitades.FirstOrDefault(m => m.Tipo == TipoMovimientoCuenta.Egreso);
        var entrada = mitades.FirstOrDefault(m => m.Tipo == TipoMovimientoCuenta.Ingreso);
        if (salida is null || entrada is null)
            throw new BadRequestException("No se encontraron las dos mitades de esta transferencia");

        if (await _context.MovimientosCuenta.AnyAsync(m =>
                m.DocumentoOrigen == DocumentoOrigenMovimiento.Reversion && m.MovimientoOrigenId == salida.Id))
        {
            throw new BadRequestException("Esta transferencia ya está anulada");
        }

        // Devolverla no puede dejar sin saldo al destino: esa plata ya pudo moverse.
        var cuentaDestino = await GetOrThrowAsync(entrada.CuentaFinancieraId);
        if (cuentaDestino.SaldoActual < entrada.Monto)
        {
            throw new BadRequestException(
                $"{cuentaDestino.Nombre} ya no tiene los S/ {Soles(entrada.Monto)} para devolverlos");
        }

        await ReversarTransferenciaAsync(salida.Id, entrada.Id, usuarioId);
    }

    public async Task<IEnumerable<MovimientoDigitalResponse>> MovimientosDigitalesAsync(
        int usuarioId, DateTime? desde, DateTime? hasta)
    {
        var (inicio, fin) = Zona.RangoUtc(desde, hasta);

        // La cuenta es la del movimiento que dejó en el libro; si ya se anuló
        // (el movimiento se revirtió), la que tiene su método de pago.
        var cobros = await _context.PagosVenta
            .AsNoTracking()
            .Where(p => p.UsuarioId == usuarioId && p.Fecha >= inicio && p.Fecha < fin
                        && p.MetodoPago!.Tipo != TipoMetodoPago.Efectivo)
            .Select(p => new MovimientoDigitalResponse
            {
                Id = p.Id,
                Fecha = p.Fecha,
                Tipo = "COBRO",
                Documento = p.NotaVenta!.Numero,
                Contraparte = p.NotaVenta.Cliente != null ? p.NotaVenta.Cliente.Nombre : null,
                MetodoPago = p.MetodoPago!.Nombre,
                MetodoTipo = p.MetodoPago.Tipo,
                Monto = p.Monto,
                Cuenta = _context.MovimientosCuenta
                             .Where(m => m.Id == p.MovimientoCuentaId)
                             .Select(m => m.CuentaFinanciera!.Nombre)
                             .FirstOrDefault()
                         ?? (p.MetodoPago.CuentaFinanciera != null ? p.MetodoPago.CuentaFinanciera.Nombre : null),
                // Anular la venta reversa sus cobros sin marcarlos: para quien
                // cobró es lo mismo, ese cobro ya no vale.
                Anulado = p.Anulado || p.NotaVenta.Estado == EstadoNotaVenta.Anulada,
                NumeroOperacion = p.NumeroOperacion,
                EstadoVerificacion = p.EstadoVerificacion,
            })
            .ToListAsync();

        var pagos = await _context.CompraPagos
            .AsNoTracking()
            .Where(p => p.UsuarioId == usuarioId && p.Fecha >= inicio && p.Fecha < fin
                        && p.MetodoPago!.Tipo != TipoMetodoPago.Efectivo)
            .Select(p => new MovimientoDigitalResponse
            {
                Id = p.Id,
                Fecha = p.Fecha,
                Tipo = "PAGO",
                Documento = p.Compra!.Numero,
                Contraparte = p.Compra.Proveedor != null ? p.Compra.Proveedor.Nombre : null,
                MetodoPago = p.MetodoPago!.Nombre,
                MetodoTipo = p.MetodoPago.Tipo,
                Monto = p.Monto,
                Cuenta = _context.MovimientosCuenta
                             .Where(m => m.Id == p.MovimientoCuentaId)
                             .Select(m => m.CuentaFinanciera!.Nombre)
                             .FirstOrDefault()
                         ?? (p.MetodoPago.CuentaFinanciera != null ? p.MetodoPago.CuentaFinanciera.Nombre : null),
                Anulado = p.Anulado,
            })
            .ToListAsync();

        return cobros.Concat(pagos)
            .OrderByDescending(m => m.Fecha).ThenByDescending(m => m.Id)
            .ToList();
    }

    public async Task<IEnumerable<MovimientoCuentaResponse>> MovimientosAsync(
        int cuentaFinancieraId, DateTime? desde, DateTime? hasta)
    {
        // Días en hora de Perú, 30 por defecto y nunca más de un año: una caja
        // o un banco acumula movimientos todos los días, no se pide el libro entero.
        var (inicio, fin) = Zona.RangoUtc(desde, hasta);

        var query = _context.MovimientosCuenta
            .AsNoTracking()
            .Where(m => m.CuentaFinancieraId == cuentaFinancieraId && m.Fecha >= inicio && m.Fecha < fin);

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
                // Anulado: alguna reversa lo apunta. Se resuelve en la misma consulta.
                Anulado = _context.MovimientosCuenta.Any(r =>
                    r.DocumentoOrigen == DocumentoOrigenMovimiento.Reversion && r.MovimientoOrigenId == m.Id),
                EsReversa = m.DocumentoOrigen == DocumentoOrigenMovimiento.Reversion,
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

    public async Task<CuentaFinanciera?> ObtenerCajaUsuarioAsync(int usuarioId) =>
        await _context.CuentasFinancieras.FirstOrDefaultAsync(c =>
            c.Naturaleza == NaturalezaCuenta.Caja && c.UsuarioResponsableId == usuarioId && c.Activo);

    public async Task<CuentaFinanciera> ExigirCajaUsuarioAsync(int usuarioId) =>
        await ObtenerCajaUsuarioAsync(usuarioId)
        ?? throw new BadRequestException(
            "Este usuario no tiene una caja asignada. Pídele a un administrador que se la cree en Finanzas > Cajas.");

    /// <summary>Que el usuario exista y que nadie más tenga ya una caja activa a su nombre.</summary>
    private async Task ValidarResponsableDeCajaAsync(int usuarioId, int? cajaId)
    {
        if (!await _context.Usuarios.AnyAsync(u => u.Id == usuarioId))
        {
            throw new NotFoundException($"No existe el usuario {usuarioId}");
        }

        var yaTieneOtra = await _context.CuentasFinancieras.AnyAsync(c =>
            c.Naturaleza == NaturalezaCuenta.Caja
            && c.UsuarioResponsableId == usuarioId
            && c.Activo
            && c.Id != cajaId);

        if (yaTieneOtra)
        {
            throw new ConflictException("Ese usuario ya tiene una caja asignada");
        }
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

    private async Task<Banco> ValidarBancoAsync(int bancoId) =>
        await _context.Bancos.FirstOrDefaultAsync(b => b.Id == bancoId)
        ?? throw new NotFoundException($"No existe el banco {bancoId}");

    private static void Aplicar(CuentaFinanciera cuenta, CuentaFinancieraRequest request, Banco? banco)
    {
        cuenta.Nombre = request.Nombre.Trim();
        cuenta.Naturaleza = request.Naturaleza;

        if (request.Naturaleza == NaturalezaCuenta.Caja)
        {
            cuenta.BancoId = null;
            cuenta.Banco = null;
            cuenta.NumeroCuenta = null;
            cuenta.Cci = null;
            cuenta.Titular = null;
            cuenta.UsuarioResponsableId = request.UsuarioResponsableId;
            return;
        }

        cuenta.BancoId = banco?.Id;
        cuenta.Banco = banco;
        cuenta.NumeroCuenta = Limpiar(request.NumeroCuenta);
        cuenta.Cci = Limpiar(request.Cci);
        cuenta.Titular = Limpiar(request.Titular);
        cuenta.UsuarioResponsableId = null;
    }

    /// <summary>Un monto como se lee en el sistema: 1250.50, con punto.</summary>
    private static string Soles(decimal monto) =>
        monto.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture);

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static CuentaFinancieraResponse Map(CuentaFinanciera c) => new()
    {
        Id = c.Id,
        Nombre = c.Nombre,
        Naturaleza = c.Naturaleza,
        UsuarioResponsableId = c.UsuarioResponsableId,
        UsuarioResponsable = c.UsuarioResponsable?.Nombre,
        BancoId = c.BancoId,
        Banco = c.Banco?.Nombre,
        NumeroCuenta = c.NumeroCuenta,
        Cci = c.Cci,
        Titular = c.Titular,
        SaldoActual = c.SaldoActual,
        Activo = c.Activo,
        FechaCreacion = c.FechaCreacion,
        EsBoveda = c.EsBoveda,
    };
}
