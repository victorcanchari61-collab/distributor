using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository;
using Microsoft.EntityFrameworkCore;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>Cómo va el cuadre de un día y una persona.</summary>
public static class EstadoCuadre
{
    /// <summary>Cobró, pero todavía no ha declarado nada.</summary>
    public const string Pendiente = "pendiente";

    public const string Cuadrado = "cuadrado";

    /// <summary>Cuadró, pero lo que trajo no coincide con lo que debía traer.</summary>
    public const string ConDiferencia = "conDiferencia";

    public const string Anulado = "anulado";
}

/// <summary>
/// El cuadre de caja del reparto.
///
/// La pregunta que responde es concreta: de lo que esta persona cobró hoy
/// —ventas al contado y abonos a deudas anteriores—, ¿cuánto trae y cuánto
/// dice que le llegó por Yape? La comparación con lo que dicen los documentos
/// es automática; lo que se declara a mano es solo lo que se contó.
///
/// Los totales del sistema se calculan aquí y se congelan al cerrar, nunca
/// llegan del cliente: si viajaran en el request, editarlos en el navegador
/// haría que cualquier cuadre saliera perfecto.
/// </summary>
public class ArqueoService : IArqueoService
{
    private readonly AppDbContext _context;
    private readonly INotificador _notificador;

    public ArqueoService(AppDbContext context, INotificador notificador)
    {
        _context = context;
        _notificador = notificador;
    }

    // ------------------------------------------------------------------
    // Motivos de gasto
    // ------------------------------------------------------------------

    public async Task<IEnumerable<MotivoGastoResponse>> GetMotivosAsync() =>
        await _context.MotivosGasto
            .AsNoTracking()
            .OrderBy(m => m.Nombre)
            .Select(m => new MotivoGastoResponse
            {
                Id = m.Id,
                Nombre = m.Nombre,
                Descripcion = m.Descripcion,
                Activo = m.Activo,
                Usos = _context.ArqueoGastos.Count(g => g.MotivoGastoId == m.Id),
            })
            .ToListAsync();

    public async Task<MotivoGastoResponse> CrearMotivoAsync(MotivoGastoRequest request)
    {
        var nombre = Exigir(request.Nombre, "Ponle un nombre al motivo de gasto");

        if (await _context.MotivosGasto.AnyAsync(m => m.Nombre == nombre))
            throw new ConflictException("Ya existe un motivo de gasto con ese nombre");

        var motivo = new MotivoGasto
        {
            Nombre = nombre,
            Descripcion = request.Descripcion?.Trim(),
            Activo = request.Activo,
        };

        _context.MotivosGasto.Add(motivo);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("arqueo", "motivoCreado", new { motivo.Id });

        return (await GetMotivosAsync()).First(m => m.Id == motivo.Id);
    }

    public async Task<MotivoGastoResponse> ActualizarMotivoAsync(int id, MotivoGastoRequest request)
    {
        var motivo = await _context.MotivosGasto.FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException("Motivo de gasto no encontrado");

        var nombre = Exigir(request.Nombre, "Ponle un nombre al motivo de gasto");

        if (await _context.MotivosGasto.AnyAsync(m => m.Nombre == nombre && m.Id != id))
            throw new ConflictException("Ya existe un motivo de gasto con ese nombre");

        motivo.Nombre = nombre;
        motivo.Descripcion = request.Descripcion?.Trim();
        motivo.Activo = request.Activo;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("arqueo", "motivoActualizado", new { motivo.Id });

        return (await GetMotivosAsync()).First(m => m.Id == id);
    }

    public async Task EliminarMotivoAsync(int id)
    {
        var motivo = await _context.MotivosGasto.FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException("Motivo de gasto no encontrado");

        var usos = await _context.ArqueoGastos.CountAsync(g => g.MotivoGastoId == id);
        if (usos > 0)
        {
            throw new ConflictException(
                $"Se usó en {usos} gasto(s) ya registrado(s). Desactívalo en lugar de eliminarlo");
        }

        _context.MotivosGasto.Remove(motivo);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("arqueo", "motivoEliminado", new { id });
    }

    // ------------------------------------------------------------------
    // Los cuadres
    // ------------------------------------------------------------------

    public async Task<IEnumerable<CuadrePendienteResponse>> GetCuadresAsync(
        DateTime desde,
        DateTime hasta)
    {
        var (inicio, fin) = Rango(desde, hasta);

        // Se agrupa por dia y persona en la base: traer cobro a cobro para
        // sumarlos aqui seria arrastrar miles de filas para mostrar diez.
        var cobros = await CobrosBase()
            .Where(p => p.Fecha >= inicio && p.Fecha <= fin)
            .GroupBy(p => new { Dia = p.Fecha.Date, p.UsuarioId })
            .Select(g => new
            {
                g.Key.Dia,
                g.Key.UsuarioId,
                Efectivo = g.Where(p => p.MetodoPago!.Tipo == TipoMetodoPago.Efectivo)
                    .Sum(p => (decimal?)p.Monto) ?? 0,
                Bancos = g.Where(p => p.MetodoPago!.Tipo != TipoMetodoPago.Efectivo)
                    .Sum(p => (decimal?)p.Monto) ?? 0,
            })
            .ToListAsync();

        var arqueos = await _context.ArqueosCaja
            .AsNoTracking()
            .Include(a => a.Gastos)
            .Include(a => a.PagosDigitales)
            .Where(a => a.Fecha >= inicio.Date && a.Fecha <= fin.Date)
            .ToListAsync();

        var nombres = await NombresAsync(
            cobros.Select(c => c.UsuarioId ?? 0).Concat(arqueos.Select(a => a.UsuarioId)));

        var filas = new List<CuadrePendienteResponse>();

        foreach (var c in cobros)
        {
            // Un cobro sin usuario no se puede atribuir a nadie, asi que
            // tampoco se le puede pedir cuentas a nadie: se deja fuera.
            if (c.UsuarioId is not int usuarioId) continue;

            var arqueo = arqueos.FirstOrDefault(a => a.Fecha.Date == c.Dia && a.UsuarioId == usuarioId);

            filas.Add(new CuadrePendienteResponse
            {
                Fecha = c.Dia,
                UsuarioId = usuarioId,
                Usuario = nombres.GetValueOrDefault(usuarioId, string.Empty),
                Efectivo = c.Efectivo,
                Bancos = c.Bancos,
                DiferenciaEfectivo = arqueo?.DiferenciaEfectivo,
                ArqueoId = arqueo?.Id,
                Faltante = arqueo?.Faltante ?? 0,
                FaltanteSaldado = arqueo?.FaltanteSaldado ?? false,
                Estado = EstadoDe(arqueo),
            });
        }

        // Tambien los cuadres de dias en los que despues se anularon todos los
        // cobros: sin esto desaparecerian de la lista y no habria forma de
        // corregirlos ni de anularlos.
        foreach (var a in arqueos)
        {
            if (filas.Any(f => f.Fecha == a.Fecha.Date && f.UsuarioId == a.UsuarioId)) continue;

            filas.Add(new CuadrePendienteResponse
            {
                Fecha = a.Fecha.Date,
                UsuarioId = a.UsuarioId,
                Usuario = nombres.GetValueOrDefault(a.UsuarioId, string.Empty),
                Efectivo = a.EfectivoSistema,
                Bancos = a.BancosSistema,
                DiferenciaEfectivo = a.DiferenciaEfectivo,
                ArqueoId = a.Id,
                Faltante = a.Faltante,
                FaltanteSaldado = a.FaltanteSaldado,
                Estado = EstadoDe(a),
            });
        }

        return filas
            .OrderByDescending(f => f.Fecha)
            .ThenBy(f => f.Usuario)
            .ToList();
    }

    public async Task<DetalleCuadreResponse> GetDetalleAsync(DateTime fecha, int usuarioId)
    {
        var (inicio, fin) = Rango(fecha, fecha);

        var cobros = await CobrosBase()
            .Where(p => p.Fecha >= inicio && p.Fecha <= fin && p.UsuarioId == usuarioId)
            .Select(p => new
            {
                p.Id,
                p.Fecha,
                Cliente = p.NotaVenta!.Cliente!.Nombre,
                Documento = p.NotaVenta!.Numero,
                FechaVenta = p.NotaVenta!.Fecha,
                MetodoPago = p.MetodoPago!.Nombre,
                TipoMetodo = p.MetodoPago!.Tipo,
                p.Monto,
            })
            .OrderBy(p => p.Fecha)
            .ToListAsync();

        var mapeados = cobros
            .Select(p => new CobroDelDiaResponse
            {
                PagoId = p.Id,
                Fecha = p.Fecha,
                Cliente = p.Cliente,
                Documento = p.Documento,
                MetodoPago = p.MetodoPago,
                TipoMetodo = p.TipoMetodo,
                Monto = p.Monto,
                // La venta es de otro dia: es una deuda vieja que se cobro en
                // la ruta, y conviene distinguirla de lo vendido hoy.
                EsDeudaAnterior = p.FechaVenta.Date < fecha.Date,
            })
            .ToList();

        var arqueo = await _context.ArqueosCaja
            .AsNoTracking()
            .Include(a => a.Usuario)
            .Include(a => a.Gastos).ThenInclude(g => g.MotivoGasto)
            .Include(a => a.PagosDigitales).ThenInclude(p => p.Cliente)
            .Include(a => a.PagosDigitales).ThenInclude(p => p.MetodoPago)
            .FirstOrDefaultAsync(a => a.Fecha.Date == fecha.Date && a.UsuarioId == usuarioId);

        var efectivo = mapeados.Where(c => c.TipoMetodo == TipoMetodoPago.Efectivo).ToList();
        var digital = mapeados.Where(c => c.TipoMetodo != TipoMetodoPago.Efectivo).ToList();

        var nombre = arqueo?.Usuario?.Nombre
                     ?? (await NombresAsync([usuarioId])).GetValueOrDefault(usuarioId, string.Empty);

        return new DetalleCuadreResponse
        {
            Fecha = fecha.Date,
            UsuarioId = usuarioId,
            Usuario = nombre,
            EfectivoSistema = efectivo.Sum(c => c.Monto),
            BancosSistema = digital.Sum(c => c.Monto),
            Efectivo = efectivo,
            Digital = digital,
            Arqueo = arqueo is null ? null : await MapearAsync(arqueo),
        };
    }

    public async Task<ArqueoCajaResponse> RegistrarAsync(
        RegistrarArqueoRequest request,
        int? registradoPorId)
    {
        if (!await _context.Usuarios.AnyAsync(u => u.Id == request.UsuarioId))
            throw new BadRequestException("Elige de quién es el cuadre");

        if (request.Billetes < 0 || request.Monedas < 0)
            throw new BadRequestException("El efectivo no puede ser negativo");

        await ValidarGastosAsync(request.Gastos);
        await ValidarPagosAsync(request.PagosDigitales);

        // Los totales del sistema se recalculan al cerrar y se congelan: si un
        // cobro se anula despues, el cuadre sigue diciendo contra que se
        // compraro, que es lo que hay que poder revisar meses despues.
        var detalle = await GetDetalleAsync(request.Fecha, request.UsuarioId);

        var arqueo = await _context.ArqueosCaja
            .Include(a => a.Gastos)
            .Include(a => a.PagosDigitales)
            .FirstOrDefaultAsync(a => a.Fecha.Date == request.Fecha.Date
                                      && a.UsuarioId == request.UsuarioId);

        if (arqueo is null)
        {
            arqueo = new ArqueoCaja
            {
                Fecha = request.Fecha.Date,
                UsuarioId = request.UsuarioId,
            };
            _context.ArqueosCaja.Add(arqueo);
        }
        else
        {
            // Volver a cuadrar corrige el anterior: se limpian sus lineas en vez
            // de sumarlas a las nuevas.
            _context.ArqueoGastos.RemoveRange(arqueo.Gastos);
            _context.ArqueoPagosDigitales.RemoveRange(arqueo.PagosDigitales);
            arqueo.Gastos.Clear();
            arqueo.PagosDigitales.Clear();
        }

        arqueo.Billetes = request.Billetes;
        arqueo.Monedas = request.Monedas;
        arqueo.EfectivoSistema = detalle.EfectivoSistema;
        arqueo.BancosSistema = detalle.BancosSistema;
        arqueo.Observacion = request.Observacion?.Trim();
        arqueo.Estado = EstadoArqueo.Cuadrado;

        // Corregir el cuadre reabre la deuda: si se dio por saldada con un
        // faltante que ahora resulta ser otro, darla por buena escondaria la
        // diferencia nueva.
        arqueo.FaltanteSaldado = false;
        arqueo.FechaSaldado = null;

        arqueo.RegistradoPorId = registradoPorId;
        arqueo.FechaCreacion = DateTime.UtcNow;

        foreach (var g in request.Gastos)
        {
            arqueo.Gastos.Add(new ArqueoGasto
            {
                MotivoGastoId = g.MotivoGastoId,
                Monto = g.Monto,
                Descripcion = g.Descripcion?.Trim(),
            });
        }

        foreach (var p in request.PagosDigitales)
        {
            arqueo.PagosDigitales.Add(new ArqueoPagoDigital
            {
                ClienteId = p.ClienteId,
                MetodoPagoId = p.MetodoPagoId,
                NumeroOperacion = p.NumeroOperacion?.Trim(),
                Monto = p.Monto,
            });
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("arqueo", "registrado", new { arqueo.Id });

        return await GetAsync(arqueo.Id);
    }

    public async Task<ArqueoCajaResponse> AnularAsync(int id)
    {
        var arqueo = await _context.ArqueosCaja.FirstOrDefaultAsync(a => a.Id == id)
            ?? throw new NotFoundException("Cuadre no encontrado");

        if (arqueo.Estado == EstadoArqueo.Anulado)
            throw new ConflictException("Ese cuadre ya está anulado");

        // No se borra: quien cuadro mal y cuando es parte de lo que se revisa
        // cuando aparece un faltante.
        arqueo.Estado = EstadoArqueo.Anulado;
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("arqueo", "anulado", new { id });

        return await GetAsync(id);
    }

    public async Task<PaginaResponse<ArqueoCajaResponse>> ListarAsync(ConsultaTablaRequest consulta)
    {
        var query = _context.ArqueosCaja
            .AsNoTracking()
            .Include(a => a.Usuario)
            .Include(a => a.Gastos).ThenInclude(g => g.MotivoGasto)
            .Include(a => a.PagosDigitales).ThenInclude(p => p.Cliente)
            .Include(a => a.PagosDigitales).ThenInclude(p => p.MetodoPago)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(a => a.Usuario != null && EF.Functions.Like(a.Usuario.Nombre, $"%{texto}%"));
        }

        if (consulta.ValorDe("estado") is string estado)
            query = query.Where(a => a.Estado == estado);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(a => a.Fecha >= desde);
        if (hasta is not null) query = query.Where(a => a.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "usuario" => desc
                ? query.OrderByDescending(a => a.Usuario!.Nombre).ThenByDescending(a => a.Id)
                : query.OrderBy(a => a.Usuario!.Nombre).ThenBy(a => a.Id),
            _ => desc
                ? query.OrderByDescending(a => a.Fecha).ThenByDescending(a => a.Id)
                : query.OrderBy(a => a.Fecha).ThenBy(a => a.Id),
        };

        var (items, total) = await query.PaginarAsync(consulta);

        var mapeados = new List<ArqueoCajaResponse>();
        foreach (var a in items) mapeados.Add(await MapearAsync(a));

        return new PaginaResponse<ArqueoCajaResponse>
        {
            Items = mapeados,
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public async Task<ArqueoCajaResponse> GetAsync(int id)
    {
        var arqueo = await _context.ArqueosCaja
            .AsNoTracking()
            .Include(a => a.Usuario)
            .Include(a => a.Gastos).ThenInclude(g => g.MotivoGasto)
            .Include(a => a.PagosDigitales).ThenInclude(p => p.Cliente)
            .Include(a => a.PagosDigitales).ThenInclude(p => p.MetodoPago)
            .FirstOrDefaultAsync(a => a.Id == id)
            ?? throw new NotFoundException("Cuadre no encontrado");

        return await MapearAsync(arqueo);
    }

    public async Task<IEnumerable<DeudaUsuarioResponse>> GetDeudasAsync()
    {
        // Los anulados quedan fuera: un cuadre anulado no cobra nada a nadie.
        var arqueos = await _context.ArqueosCaja
            .AsNoTracking()
            .Include(a => a.Usuario)
            .Include(a => a.Gastos).ThenInclude(g => g.MotivoGasto)
            .Include(a => a.PagosDigitales).ThenInclude(p => p.Cliente)
            .Include(a => a.PagosDigitales).ThenInclude(p => p.MetodoPago)
            .Where(a => a.Estado != EstadoArqueo.Anulado)
            .ToListAsync();

        // El faltante se calcula sobre las lineas, asi que se filtra en memoria:
        // no es una columna que la base pueda comparar.
        var conFaltante = arqueos.Where(a => a.Faltante > 0).ToList();

        var deudas = new List<DeudaUsuarioResponse>();

        foreach (var grupo in conFaltante.GroupBy(a => a.UsuarioId))
        {
            var pendientes = grupo.Where(a => !a.FaltanteSaldado).OrderBy(a => a.Fecha).ToList();

            var detalle = new List<ArqueoCajaResponse>();
            foreach (var a in pendientes) detalle.Add(await MapearAsync(a));

            deudas.Add(new DeudaUsuarioResponse
            {
                UsuarioId = grupo.Key,
                Usuario = grupo.First().Usuario?.Nombre ?? string.Empty,
                Pendiente = pendientes.Sum(a => a.Faltante),
                Dias = pendientes.Count,
                Saldado = grupo.Where(a => a.FaltanteSaldado).Sum(a => a.Faltante),
                Detalle = detalle,
            });
        }

        // Quien mas debe, primero: es a quien hay que reclamar.
        return deudas.OrderByDescending(d => d.Pendiente).ThenBy(d => d.Usuario).ToList();
    }

    public async Task<ArqueoCajaResponse> SaldarFaltanteAsync(int id)
    {
        var arqueo = await _context.ArqueosCaja
            .Include(a => a.Gastos)
            .Include(a => a.PagosDigitales)
            .FirstOrDefaultAsync(a => a.Id == id)
            ?? throw new NotFoundException("Cuadre no encontrado");

        if (arqueo.Faltante <= 0)
            throw new BadRequestException("Ese cuadre no dejó ningún faltante");

        if (arqueo.FaltanteSaldado)
            throw new ConflictException("Ese faltante ya estaba saldado");

        arqueo.FaltanteSaldado = true;
        arqueo.FechaSaldado = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("arqueo", "faltanteSaldado", new { id });

        return await GetAsync(id);
    }

    // ------------------------------------------------------------------

    /// <summary>
    /// Los cobros que cuentan: los que no están anulados y cuya venta sigue en
    /// pie. Una nota anulada devolvió el dinero, así que su cobro no es dinero
    /// que nadie tenga que traer.
    /// </summary>
    private IQueryable<PagoVenta> CobrosBase() =>
        _context.PagosVenta
            .AsNoTracking()
            .Where(p => !p.Anulado && p.NotaVenta!.Estado == EstadoNotaVenta.Confirmada);

    /// <summary>
    /// El rango en instantes, con el "hasta" al final del día.
    ///
    /// Los cobros llevan hora; comparar contra la fecha pelada dejaría fuera
    /// todo lo cobrado después de medianoche del último día.
    /// </summary>
    private static (DateTime Inicio, DateTime Fin) Rango(DateTime desde, DateTime hasta) =>
        (desde.Date, hasta.Date.AddDays(1).AddTicks(-1));

    private static string EstadoDe(ArqueoCaja? arqueo)
    {
        if (arqueo is null) return EstadoCuadre.Pendiente;
        if (arqueo.Estado == EstadoArqueo.Anulado) return EstadoCuadre.Anulado;

        return arqueo.DiferenciaEfectivo == 0 && arqueo.DiferenciaBancos == 0
            ? EstadoCuadre.Cuadrado
            : EstadoCuadre.ConDiferencia;
    }

    private async Task<Dictionary<int, string>> NombresAsync(IEnumerable<int> ids)
    {
        var unicos = ids.Where(id => id > 0).Distinct().ToList();

        return await _context.Usuarios
            .AsNoTracking()
            .Where(u => unicos.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.Nombre);
    }

    private async Task ValidarGastosAsync(List<ArqueoGastoRequest> gastos)
    {
        if (gastos.Any(g => g.Monto <= 0))
            throw new BadRequestException("Un gasto tiene que tener importe");

        var ids = gastos.Select(g => g.MotivoGastoId).Distinct().ToList();
        var existen = await _context.MotivosGasto.CountAsync(m => ids.Contains(m.Id));

        if (existen != ids.Count)
            throw new BadRequestException("Alguno de los motivos de gasto no existe");
    }

    private async Task ValidarPagosAsync(List<ArqueoPagoDigitalRequest> pagos)
    {
        if (pagos.Any(p => p.Monto <= 0))
            throw new BadRequestException("Un pago digital tiene que tener importe");

        var metodos = pagos.Select(p => p.MetodoPagoId).Distinct().ToList();
        var existen = await _context.MetodosPago.CountAsync(m => metodos.Contains(m.Id));

        if (existen != metodos.Count)
            throw new BadRequestException("Alguno de los métodos de pago no existe");

        var clientes = pagos.Where(p => p.ClienteId is not null)
            .Select(p => p.ClienteId!.Value).Distinct().ToList();

        if (clientes.Count > 0
            && await _context.Clientes.CountAsync(c => clientes.Contains(c.Id)) != clientes.Count)
        {
            throw new BadRequestException("Alguno de los clientes no existe");
        }
    }

    private static string Exigir(string valor, string mensaje)
    {
        var limpio = valor.Trim();
        if (limpio.Length == 0) throw new BadRequestException(mensaje);
        return limpio;
    }

    private async Task<ArqueoCajaResponse> MapearAsync(ArqueoCaja a)
    {
        var registradoPor = a.RegistradoPorId is int id
            ? (await NombresAsync([id])).GetValueOrDefault(id)
            : null;

        return new ArqueoCajaResponse
        {
            Id = a.Id,
            Fecha = a.Fecha,
            UsuarioId = a.UsuarioId,
            Usuario = a.Usuario?.Nombre ?? string.Empty,
            Billetes = a.Billetes,
            Monedas = a.Monedas,
            EfectivoSistema = a.EfectivoSistema,
            BancosSistema = a.BancosSistema,
            TotalEfectivoReal = a.TotalEfectivoReal,
            TotalDigitalReal = a.TotalDigitalReal,
            DiferenciaEfectivo = a.DiferenciaEfectivo,
            DiferenciaBancos = a.DiferenciaBancos,
            Faltante = a.Faltante,
            Sobrante = a.Sobrante,
            FaltanteSaldado = a.FaltanteSaldado,
            FechaSaldado = a.FechaSaldado,
            Observacion = a.Observacion,
            Estado = a.Estado,
            RegistradoPor = registradoPor,
            FechaCreacion = a.FechaCreacion,
            Gastos = a.Gastos.Select(g => new ArqueoGastoResponse
            {
                Id = g.Id,
                MotivoGastoId = g.MotivoGastoId,
                MotivoGasto = g.MotivoGasto?.Nombre ?? string.Empty,
                Monto = g.Monto,
                Descripcion = g.Descripcion,
            }).ToList(),
            PagosDigitales = a.PagosDigitales.Select(p => new ArqueoPagoDigitalResponse
            {
                Id = p.Id,
                ClienteId = p.ClienteId,
                Cliente = p.Cliente?.Nombre,
                MetodoPagoId = p.MetodoPagoId,
                MetodoPago = p.MetodoPago?.Nombre ?? string.Empty,
                NumeroOperacion = p.NumeroOperacion,
                Monto = p.Monto,
            }).ToList(),
        };
    }
}
