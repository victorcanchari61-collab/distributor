using Backend.Data;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Los números de los dashboards.
///
/// Todo se agrupa por día de calle (hora de Lima), no por día UTC: una venta
/// de las 8 de la noche es de ESE día. Los importes salen de las mismas
/// fórmulas que las pantallas de cada módulo, para que el tablero y la pantalla
/// nunca digan cosas distintas.
/// </summary>
public class DashboardService : IDashboardService
{
    private const int MaximoDias = 366;
    private const string SinVendedor = "Sin asignar";
    private const string SinCategoria = "Sin categoría";
    private const string SinCliente = "Sin cliente";

    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;
    private readonly IGananciaService _ganancias;

    public DashboardService(
        AppDbContext context,
        IPermisoService permisos,
        IUsuarioActual usuarioActual,
        IGananciaService ganancias)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
        _ganancias = ganancias;
    }

    // ------------------------------------------------------------- Utilidades

    /// <summary>Sin fechas, los últimos 30 días.</summary>
    private static (DateTime Primero, DateTime Ultimo) Rango(DateTime? desde, DateTime? hasta)
    {
        var ultimo = hasta?.Date ?? Zona.Hoy;
        var primero = desde?.Date ?? ultimo.AddDays(-29);

        if (primero > ultimo)
            throw new BadRequestException("El \"desde\" no puede ser después del \"hasta\".");

        if ((ultimo - primero).TotalDays >= MaximoDias)
            throw new BadRequestException($"Elige un rango de hasta {MaximoDias} días.");

        return (primero, ultimo);
    }

    private async Task<AlcanceFiltro?> AlcanceAsync(string submodulo) =>
        _usuarioActual.Id is int uid
            ? await _permisos.AlcanceFiltroAsync(uid, submodulo)
            : null;

    private static IQueryable<NotaVenta> Acotar(IQueryable<NotaVenta> query, AlcanceFiltro? alcance)
    {
        if (alcance is null || alcance.SinRestriccion) return query;

        // Local y no alcance.RutaId dentro de la consulta: asi EF la manda como parametro y el
        // "sin ruta" (null) queda descartado antes de comparar, en vez de emparejar con clientes sin ruta.
        var ruta = alcance.RutaId;

        return alcance.SoloPropios
            ? query.Where(n => n.UsuarioId == alcance.UsuarioId)
            : query.Where(n => n.UsuarioId == alcance.UsuarioId
                               || (ruta != null && n.Cliente != null && n.Cliente.RutaId == ruta));
    }

    private static IQueryable<Pedido> Acotar(IQueryable<Pedido> query, AlcanceFiltro? alcance)
    {
        if (alcance is null || alcance.SinRestriccion) return query;

        // Local y no alcance.RutaId dentro de la consulta: asi EF la manda como parametro y el
        // "sin ruta" (null) queda descartado antes de comparar, en vez de emparejar con clientes sin ruta.
        var ruta = alcance.RutaId;

        return alcance.SoloPropios
            ? query.Where(p => p.UsuarioId == alcance.UsuarioId)
            : query.Where(p => p.UsuarioId == alcance.UsuarioId
                               || (ruta != null && p.Cliente != null && p.Cliente.RutaId == ruta));
    }

    /// <summary>Lunes = 0 … domingo = 6.</summary>
    private static int DiaSemana(DateTime fecha) => ((int)fecha.DayOfWeek + 6) % 7;

    private static decimal R2(decimal valor) => Math.Round(valor, 2);

    private static decimal? Margen(decimal importe, decimal ganancia) =>
        importe > 0 ? Math.Round(ganancia / importe * 100, 1) : null;

    /// <summary>Las cinco barras de antigüedad de una deuda.</summary>
    private static readonly (string Nombre, int Hasta)[] TramosDeuda =
    [
        ("0–7 días", 7), ("8–15 días", 15), ("16–30 días", 30), ("31–60 días", 60), ("Más de 60", int.MaxValue),
    ];

    // ------------------------------------------------------------------ Ventas

    public async Task<DashboardVentasResponse> VentasAsync(DateTime? desde, DateTime? hasta)
    {
        var (primero, ultimo) = Rango(desde, hasta);
        var dias = (int)(ultimo - primero).TotalDays + 1;
        var primeroAnt = primero.AddDays(-dias);
        var ultimoAnt = primero.AddDays(-1);

        var hoy = Zona.Hoy;
        var inicioMes = new DateTime(hoy.Year, hoy.Month, 1);
        var inicioMesAnt = inicioMes.AddMonths(-1);
        var diasMes = DateTime.DaysInMonth(hoy.Year, hoy.Month);

        // Una sola ventana cubre todo lo que se necesita: el período, el
        // anterior, el mes pasado y las ocho semanas para el ritmo por día.
        var ventanaIni = new[] { primeroAnt, inicioMesAnt, hoy.AddDays(-56) }.Min();
        var ventanaFin = new[] { ultimo, hoy }.Max();

        var alcance = await AlcanceAsync("fact.notaventa");

        var notas = Acotar(
            _context.NotasVenta.Where(n => n.Estado != EstadoNotaVenta.Anulada
                                           && n.Fecha >= Zona.AUtc(ventanaIni)
                                           && n.Fecha < Zona.AUtc(ventanaFin.AddDays(1))),
            alcance);

        var cabeceras = (await notas
                .Select(n => new
                {
                    n.Id,
                    n.Fecha,
                    n.ClienteId,
                    Cliente = n.Cliente != null ? n.Cliente.Nombre : null,
                    Vendedor = n.Usuario != null ? n.Usuario.Nombre : null,
                    n.FormaPago,
                    Importe = n.Detalle.Where(d => !d.Anulado)
                        .Sum(d => (decimal?)(d.CantidadPresentacion * d.PrecioPresentacion)) ?? 0m,
                })
                .AsNoTracking()
                .ToListAsync())
            .Select(n => new
            {
                n.Id,
                Dia = Zona.DiaDe(n.Fecha),
                Hora = Zona.ALocal(n.Fecha).Hour,
                n.ClienteId,
                Cliente = n.Cliente ?? SinCliente,
                Vendedor = n.Vendedor ?? SinVendedor,
                n.FormaPago,
                n.Importe,
            })
            .ToList();

        var porDia = cabeceras
            .GroupBy(c => c.Dia)
            .ToDictionary(g => g.Key, g => (Importe: g.Sum(c => c.Importe), Notas: g.Count()));

        decimal ImporteDe(DateTime dia) => porDia.TryGetValue(dia, out var v) ? v.Importe : 0m;

        var delPeriodo = cabeceras.Where(c => c.Dia >= primero && c.Dia <= ultimo).ToList();
        var delAnterior = cabeceras.Where(c => c.Dia >= primeroAnt && c.Dia <= ultimoAnt).ToList();

        static DashTotalesVentas Totales<T>(List<T> filas, Func<T, decimal> importe, Func<T, int> cliente)
        {
            var total = filas.Sum(importe);
            return new DashTotalesVentas
            {
                Importe = R2(total),
                Notas = filas.Count,
                Clientes = filas.Select(cliente).Distinct().Count(),
                Ticket = filas.Count > 0 ? R2(total / filas.Count) : 0m,
            };
        }

        var serie = Enumerable.Range(0, dias)
            .Select(i =>
            {
                var dia = primero.AddDays(i);
                return new DashDiaVenta
                {
                    Fecha = dia,
                    Importe = R2(ImporteDe(dia)),
                    Notas = porDia.TryGetValue(dia, out var v) ? v.Notas : 0,
                    ImporteAnterior = R2(ImporteDe(primeroAnt.AddDays(i))),
                };
            })
            .ToList();

        var respuesta = new DashboardVentasResponse
        {
            Desde = primero,
            Hasta = ultimo,
            SoloPropio = alcance is { SinRestriccion: false },
            Actual = Totales(delPeriodo, c => c.Importe, c => c.ClienteId),
            Anterior = Totales(delAnterior, c => c.Importe, c => c.ClienteId),
            Serie = serie,
            Atipicos = Atipicos(serie),
            Mes = MesEnCurso(porDia.ToDictionary(k => k.Key, k => k.Value.Importe), hoy, inicioMesAnt, diasMes),
        };

        respuesta.PorVendedor = delPeriodo
            .GroupBy(c => c.Vendedor)
            .Select(g => new DashItem { Nombre = g.Key, Valor = R2(g.Sum(c => c.Importe)), Cantidad = g.Count() })
            .OrderByDescending(i => i.Valor)
            .ToList();

        respuesta.PorFormaPago = delPeriodo
            .GroupBy(c => c.FormaPago)
            .Select(g => new DashItem
            {
                Nombre = g.Key == FormaPagoVenta.Credito ? "Crédito" : "Contado",
                Valor = R2(g.Sum(c => c.Importe)),
                Cantidad = g.Count(),
            })
            .OrderByDescending(i => i.Valor)
            .ToList();

        // Pareto de clientes: cuántos sostienen el 80 % de lo vendido.
        var porCliente = delPeriodo
            .GroupBy(c => c.Cliente)
            .Select(g => (Nombre: g.Key, Valor: g.Sum(c => c.Importe)))
            .OrderByDescending(c => c.Valor)
            .ToList();

        var totalClientes = porCliente.Sum(c => c.Valor);
        var acumulado = 0m;
        var pareto = new List<DashPareto>();
        foreach (var c in porCliente)
        {
            acumulado += c.Valor;
            pareto.Add(new DashPareto
            {
                Nombre = c.Nombre,
                Valor = R2(c.Valor),
                Acumulado = totalClientes > 0 ? Math.Round(acumulado / totalClientes * 100, 1) : 0m,
            });
        }

        respuesta.ClientesTotal = pareto.Count;
        var posicion80 = pareto.FindIndex(p => p.Acumulado >= 80m);
        respuesta.ClientesAl80 = posicion80 >= 0 ? posicion80 + 1 : pareto.Count;
        respuesta.Pareto = pareto.Take(15).ToList();

        // Mapa de calor: día de la semana × hora.
        respuesta.Calor = delPeriodo
            .GroupBy(c => (Dia: DiaSemana(c.Dia), c.Hora))
            .Select(g => new DashCalor
            {
                Dia = g.Key.Dia,
                Hora = g.Key.Hora,
                Importe = R2(g.Sum(c => c.Importe)),
                Notas = g.Count(),
            })
            .ToList();

        // Lo que se vendió, por categoría y por producto.
        var lineas = await Acotar(
                _context.NotasVenta.Where(n => n.Estado != EstadoNotaVenta.Anulada
                                               && n.Fecha >= Zona.AUtc(primero)
                                               && n.Fecha < Zona.AUtc(ultimo.AddDays(1))),
                alcance)
            .SelectMany(n => n.Detalle)
            .Where(d => !d.Anulado)
            .Select(d => new
            {
                Producto = d.Producto!.Nombre,
                Categoria = d.Producto.Categoria != null ? d.Producto.Categoria.Nombre : null,
                Importe = d.CantidadPresentacion * d.PrecioPresentacion,
            })
            .AsNoTracking()
            .ToListAsync();

        respuesta.PorCategoria = lineas
            .GroupBy(l => l.Categoria ?? SinCategoria)
            .Select(g => new DashItem { Nombre = g.Key, Valor = R2(g.Sum(l => l.Importe)) })
            .OrderByDescending(i => i.Valor)
            .ToList();

        respuesta.TopProductos = lineas
            .GroupBy(l => l.Producto)
            .Select(g => new DashItem { Nombre = g.Key, Valor = R2(g.Sum(l => l.Importe)) })
            .OrderByDescending(i => i.Valor)
            .Take(10)
            .ToList();

        return respuesta;
    }

    /// <summary>
    /// Los días que se salen de lo normal: más de dos desviaciones del promedio
    /// de los días que sí vendieron. Con menos de una semana de datos no se
    /// dice nada — cualquier día parecería raro.
    /// </summary>
    private static List<DashAtipico> Atipicos(List<DashDiaVenta> serie)
    {
        var conVenta = serie.Where(d => d.Importe > 0).Select(d => (double)d.Importe).ToList();
        if (conVenta.Count < 7) return [];

        var media = conVenta.Average();
        var desviacion = Math.Sqrt(conVenta.Sum(v => Math.Pow(v - media, 2)) / conVenta.Count);
        if (desviacion <= 0) return [];

        var atipicos = new List<DashAtipico>();
        for (var i = 0; i < serie.Count; i++)
        {
            if (serie[i].Importe <= 0) continue;
            var z = ((double)serie[i].Importe - media) / desviacion;
            if (Math.Abs(z) >= 2) atipicos.Add(new DashAtipico { Indice = i, Tipo = z > 0 ? "PICO" : "CAIDA" });
        }

        return atipicos;
    }

    /// <summary>El mes en curso contra el pasado, con la proyección del cierre.</summary>
    private static DashMes MesEnCurso(
        Dictionary<DateTime, decimal> importePorDia, DateTime hoy, DateTime inicioMesAnt, int diasMes)
    {
        decimal De(DateTime dia) => importePorDia.TryGetValue(dia, out var v) ? v : 0m;

        var inicioMes = new DateTime(hoy.Year, hoy.Month, 1);
        var diasMesAnt = DateTime.DaysInMonth(inicioMesAnt.Year, inicioMesAnt.Month);

        var actual = new List<decimal>();
        var suma = 0m;
        for (var d = 1; d <= hoy.Day; d++)
        {
            suma += De(inicioMes.AddDays(d - 1));
            actual.Add(R2(suma));
        }

        var anterior = new List<decimal>();
        suma = 0m;
        for (var d = 1; d <= diasMesAnt; d++)
        {
            suma += De(inicioMesAnt.AddDays(d - 1));
            anterior.Add(R2(suma));
        }

        // Lo que se vende en promedio cada día de la semana, en las últimas
        // ocho semanas cerradas. Un domingo sin ventas cuenta como cero: es lo
        // que va a pasar el próximo domingo.
        var promedioDia = new decimal[7];
        for (var dow = 0; dow < 7; dow++)
        {
            var fechas = Enumerable.Range(1, 56).Select(n => hoy.AddDays(-n)).Where(f => DiaSemana(f) == dow).ToList();
            promedioDia[dow] = fechas.Count > 0 ? fechas.Sum(De) / fechas.Count : 0m;
        }

        var acumulado = actual[^1];
        var faltaHoy = Math.Max(0m, promedioDia[DiaSemana(hoy)] - De(hoy));

        var proyeccion = new List<decimal?>();
        for (var d = 1; d <= diasMes; d++) proyeccion.Add(null);
        proyeccion[hoy.Day - 1] = acumulado;

        var corrida = acumulado + faltaHoy;
        for (var d = hoy.Day + 1; d <= diasMes; d++)
        {
            corrida += promedioDia[DiaSemana(inicioMes.AddDays(d - 1))];
            proyeccion[d - 1] = R2(corrida);
        }

        return new DashMes
        {
            Nombre = inicioMes.ToString("MMMM", new System.Globalization.CultureInfo("es-PE")),
            DiaActual = hoy.Day,
            DiasMes = diasMes,
            Acumulado = acumulado,
            Proyectado = proyeccion[^1] ?? acumulado,
            MesAnterior = anterior.Count > 0 ? anterior[^1] : 0m,
            MesAnteriorMismoPunto = anterior.Count > 0 ? anterior[Math.Min(hoy.Day, anterior.Count) - 1] : 0m,
            SerieActual = actual,
            SerieAnterior = anterior,
            SerieProyeccion = proyeccion,
        };
    }

    // --------------------------------------------------------------- Ganancias

    public async Task<DashboardGananciasResponse> GananciasAsync(DateTime? desde, DateTime? hasta)
    {
        var (primero, ultimo) = Rango(desde, hasta);
        var dias = (int)(ultimo - primero).TotalDays + 1;
        var primeroAnt = primero.AddDays(-dias);

        var (todas, soloPropio) = await _ganancias.LineasAsync(
            Zona.AUtc(primeroAnt), Zona.AUtc(ultimo.AddDays(1)));

        var lineas = todas.Where(l => Zona.DiaDe(l.Fecha) >= primero).ToList();
        var previas = todas.Where(l => Zona.DiaDe(l.Fecha) < primero).ToList();

        // La ganancia sale del valor de venta SIN el IGV, no del importe cobrado: ese 18% no es
        // ingreso, es plata que se le pasa al fisco. El Importe que se muestra sigue siendo lo
        // cobrado de verdad — solo la ganancia y el margen se corrigen.
        var importe = lineas.Sum(l => l.Importe);
        var valorVenta = lineas.Sum(l => l.ValorVenta);
        var costo = lineas.Sum(l => l.Costo);
        var valorVentaAnt = previas.Sum(l => l.ValorVenta);
        var gananciaAnt = valorVentaAnt - previas.Sum(l => l.Costo);

        var porDia = lineas
            .GroupBy(l => Zona.DiaDe(l.Fecha))
            .ToDictionary(g => g.Key, g => (Importe: g.Sum(l => l.Importe), ValorVenta: g.Sum(l => l.ValorVenta), Costo: g.Sum(l => l.Costo)));

        return new DashboardGananciasResponse
        {
            Desde = primero,
            Hasta = ultimo,
            SoloPropio = soloPropio,
            Importe = R2(importe),
            Costo = R2(costo),
            Ganancia = R2(valorVenta - costo),
            Margen = Margen(valorVenta, valorVenta - costo),
            GananciaAnterior = R2(gananciaAnt),
            MargenAnterior = Margen(valorVentaAnt, gananciaAnt),
            LineasSinCosto = lineas.Count(l => l.Importe > 0 && l.Costo <= 0),

            Serie = Enumerable.Range(0, dias)
                .Select(i =>
                {
                    var dia = primero.AddDays(i);
                    var (imp, val, cos) = porDia.TryGetValue(dia, out var v) ? v : (0m, 0m, 0m);
                    return new DashDiaGanancia
                    {
                        Fecha = dia,
                        Importe = R2(imp),
                        Ganancia = R2(val - cos),
                        Margen = Margen(val, val - cos),
                    };
                })
                .ToList(),

            // Todos los productos con venta: la matriz margen × volumen los
            // necesita a todos para poder marcar cuáles están fuera de lugar.
            Productos = lineas
                .GroupBy(l => l.ProductoId)
                .Select(g =>
                {
                    var imp = g.Sum(l => l.Importe);
                    var val = g.Sum(l => l.ValorVenta);
                    var gan = val - g.Sum(l => l.Costo);
                    return new DashProductoGanancia
                    {
                        Nombre = g.First().Producto,
                        Categoria = g.First().Categoria,
                        Importe = R2(imp),
                        Ganancia = R2(gan),
                        Margen = Margen(val, gan),
                    };
                })
                .Where(p => p.Importe > 0)
                .OrderByDescending(p => p.Importe)
                .Take(60)
                .ToList(),

            PorCategoria = lineas
                .GroupBy(l => l.Categoria)
                .Select(g => new DashItem { Nombre = g.Key, Valor = R2(g.Sum(l => l.Importe - l.Costo)) })
                .OrderByDescending(i => i.Valor)
                .ToList(),
        };
    }

    // ---------------------------------------------------------------- Cobranza

    public async Task<DashboardCobranzaResponse> CobranzaAsync(DateTime? desde, DateTime? hasta)
    {
        var (primero, ultimo) = Rango(desde, hasta);
        var hoy = Zona.Hoy;

        // Lo que todavía se debe: la misma regla de Cuentas por cobrar — crédito
        // vigente cuyo detalle vale más que lo pagado.
        var abiertas = (await _context.NotasVenta
                .Where(n => n.Estado == EstadoNotaVenta.Confirmada && n.FormaPago == FormaPagoVenta.Credito)
                .Select(n => new
                {
                    n.Fecha,
                    n.ClienteId,
                    Cliente = n.Cliente != null ? n.Cliente.Nombre : null,
                    Total = n.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.Cantidad * d.PrecioUnitario)) ?? 0m,
                    Pagado = n.Pagos.Where(p => !p.Anulado).Sum(p => (decimal?)p.Monto) ?? 0m,
                })
                .AsNoTracking()
                .ToListAsync())
            .Where(n => n.Total > n.Pagado)
            .Select(n => new
            {
                n.ClienteId,
                Cliente = n.Cliente ?? SinCliente,
                Saldo = n.Total - n.Pagado,
                Dias = Math.Max(0, (int)(hoy - Zona.DiaDe(n.Fecha)).TotalDays),
            })
            .ToList();

        var antiguedad = TramosDeuda
            .Select((t, i) =>
            {
                var desdeDias = i == 0 ? 0 : TramosDeuda[i - 1].Hasta + 1;
                var deTramo = abiertas.Where(a => a.Dias >= desdeDias && a.Dias <= t.Hasta).ToList();
                return new DashItem { Nombre = t.Nombre, Valor = R2(deTramo.Sum(a => a.Saldo)), Cantidad = deTramo.Count };
            })
            .ToList();

        var deudores = abiertas
            .GroupBy(a => a.ClienteId)
            .Select(g => new DashDeudor
            {
                Cliente = g.First().Cliente,
                Saldo = R2(g.Sum(a => a.Saldo)),
                Notas = g.Count(),
                Dias = g.Max(a => a.Dias),
            })
            .OrderByDescending(d => d.Saldo)
            .Take(8)
            .ToList();

        // Lo cobrado en el período, por día y por método.
        var cobros = await _context.PagosVenta
            .Where(p => !p.Anulado
                        && p.NotaVenta!.Estado == EstadoNotaVenta.Confirmada
                        && p.Fecha >= Zona.AUtc(primero)
                        && p.Fecha < Zona.AUtc(ultimo.AddDays(1)))
            .Select(p => new { p.Fecha, p.Monto, Metodo = p.MetodoPago != null ? p.MetodoPago.Nombre : "Otro" })
            .AsNoTracking()
            .ToListAsync();

        var metodos = cobros
            .GroupBy(c => c.Metodo)
            .OrderByDescending(g => g.Sum(c => c.Monto))
            .Select(g => g.Key)
            .ToList();

        var porDiaMetodo = cobros
            .GroupBy(c => (Dia: Zona.DiaDe(c.Fecha), c.Metodo))
            .ToDictionary(g => g.Key, g => g.Sum(c => c.Monto));

        var dias = (int)(ultimo - primero).TotalDays + 1;
        var serie = Enumerable.Range(0, dias)
            .Select(i =>
            {
                var dia = primero.AddDays(i);
                return new DashCobroDia
                {
                    Fecha = dia,
                    Valores = metodos.Select(m => R2(porDiaMetodo.TryGetValue((dia, m), out var v) ? v : 0m)).ToList(),
                };
            })
            .ToList();

        var credito = await _context.NotasVenta
            .Where(n => n.Estado == EstadoNotaVenta.Confirmada
                        && n.FormaPago == FormaPagoVenta.Credito
                        && n.Fecha >= Zona.AUtc(primero)
                        && n.Fecha < Zona.AUtc(ultimo.AddDays(1)))
            .SelectMany(n => n.Detalle)
            .Where(d => !d.Anulado)
            .SumAsync(d => (decimal?)(d.Cantidad * d.PrecioUnitario)) ?? 0m;

        return new DashboardCobranzaResponse
        {
            Desde = primero,
            Hasta = ultimo,
            TotalPorCobrar = R2(abiertas.Sum(a => a.Saldo)),
            Cuentas = abiertas.Count,
            Clientes = abiertas.Select(a => a.ClienteId).Distinct().Count(),
            Antiguedad = antiguedad,
            Deudores = deudores,
            CobradoPeriodo = R2(cobros.Sum(c => c.Monto)),
            Metodos = metodos,
            Cobros = serie,
            CreditoOtorgado = R2(credito),
        };
    }

    // -------------------------------------------------------------- Inventario

    public async Task<DashboardInventarioResponse> InventarioAsync()
    {
        var hoy = Zona.Hoy;

        var capas = await _context.CapasCosto
            .Where(c => c.CantidadDisponible > 0 && c.Producto!.ControlaStock && c.Producto.Activo)
            .Select(c => new
            {
                c.ProductoId,
                c.CantidadDisponible,
                c.CostoUnitario,
                c.FechaVencimiento,
            })
            .AsNoTracking()
            .ToListAsync();

        var ritmo = await _context.NotaVentaDetalles
            .Where(d => !d.Anulado
                        && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && d.NotaVenta.Fecha >= Zona.AUtc(hoy.AddDays(-29)))
            .GroupBy(d => d.ProductoId)
            .Select(g => new { ProductoId = g.Key, Cantidad = g.Sum(d => d.Cantidad) })
            .AsNoTracking()
            .ToDictionaryAsync(x => x.ProductoId, x => x.Cantidad / 30m);

        var stockPorProducto = capas
            .GroupBy(c => c.ProductoId)
            .ToDictionary(g => g.Key, g => (Stock: g.Sum(c => c.CantidadDisponible), Valor: g.Sum(c => c.CantidadDisponible * c.CostoUnitario)));

        // Los productos que importan: los que tienen algo y los que se venden.
        var ids = stockPorProducto.Keys.Union(ritmo.Keys).ToList();
        var productos = await _context.Productos
            .Where(p => ids.Contains(p.Id) && p.ControlaStock)
            .Select(p => new
            {
                p.Id,
                p.Nombre,
                Categoria = p.Categoria != null ? p.Categoria.Nombre : null,
                Unidad = p.UnidadBase != null ? p.UnidadBase.Codigo : string.Empty,
            })
            .AsNoTracking()
            .ToListAsync();

        var filas = productos
            .Select(p =>
            {
                var (stock, valor) = stockPorProducto.TryGetValue(p.Id, out var s) ? s : (0m, 0m);
                var venta = ritmo.TryGetValue(p.Id, out var r) ? r : 0m;
                return new
                {
                    p.Id,
                    p.Nombre,
                    Categoria = p.Categoria ?? SinCategoria,
                    p.Unidad,
                    Stock = stock,
                    Valor = valor,
                    Venta = venta,
                    Dias = venta > 0 ? stock / venta : (decimal?)null,
                };
            })
            .ToList();

        static string Estado(decimal stock, decimal venta, decimal? dias) =>
            venta <= 0 ? "Sin rotación"
            : stock <= 0 ? "Agotado"
            : dias < 7 ? "Crítico"
            : dias < 15 ? "Atención"
            : dias <= 60 ? "Sano"
            : "Sobrestock";

        var orden = new[] { "Agotado", "Crítico", "Atención", "Sano", "Sobrestock", "Sin rotación" };
        var salud = filas
            .Where(f => f.Stock > 0 || f.Venta > 0)
            .GroupBy(f => Estado(f.Stock, f.Venta, f.Dias))
            .Select(g => new DashItem { Nombre = g.Key, Valor = g.Count(), Cantidad = g.Count() })
            .OrderBy(i => Array.IndexOf(orden, i.Nombre))
            .ToList();

        var dormidos = filas.Where(f => f.Stock > 0 && f.Venta <= 0).OrderByDescending(f => f.Valor).ToList();

        // Lo que vence, valorizado a costo, por ventanas desde hoy.
        var conFecha = capas.Where(c => c.FechaVencimiento != null).ToList();
        decimal Valorizar(Func<int, bool> dentro) => conFecha
            .Where(c => dentro((int)(c.FechaVencimiento!.Value.Date - hoy).TotalDays))
            .Sum(c => c.CantidadDisponible * c.CostoUnitario);

        var vencimientos = new List<DashItem>
        {
            new() { Nombre = "Vencido", Valor = R2(Valorizar(d => d < 0)) },
            new() { Nombre = "0–15 días", Valor = R2(Valorizar(d => d is >= 0 and <= 15)) },
            new() { Nombre = "16–30 días", Valor = R2(Valorizar(d => d is > 15 and <= 30)) },
            new() { Nombre = "31–60 días", Valor = R2(Valorizar(d => d is > 30 and <= 60)) },
            new() { Nombre = "61–90 días", Valor = R2(Valorizar(d => d is > 60 and <= 90)) },
        };

        var porCategoria = filas
            .Where(f => f.Valor > 0)
            .GroupBy(f => f.Categoria)
            .Select(g => new DashItem { Nombre = g.Key, Valor = R2(g.Sum(f => f.Valor)), Cantidad = g.Count() })
            .OrderByDescending(i => i.Valor)
            .ToList();

        return new DashboardInventarioResponse
        {
            ValorTotal = R2(filas.Sum(f => f.Valor)),
            Productos = filas.Count(f => f.Stock > 0),
            Salud = salud,
            ValorPorCategoria = porCategoria,
            DormidoTotal = R2(dormidos.Sum(f => f.Valor)),
            Dormido = dormidos.Take(8).Select(f => new DashItem { Nombre = f.Nombre, Valor = R2(f.Valor) }).ToList(),
            Vencimientos = vencimientos,
            Cobertura = filas
                .Where(f => f.Venta > 0)
                .OrderBy(f => f.Dias)
                .Take(12)
                .Select(f => new DashCobertura
                {
                    Producto = f.Nombre,
                    Stock = Math.Round(f.Stock, 2),
                    Unidad = f.Unidad,
                    VentaDiaria = Math.Round(f.Venta, 2),
                    Dias = Math.Round(f.Dias ?? 0m, 1),
                })
                .ToList(),
        };
    }

    // ------------------------------------------------------------------ Reparto

    public async Task<DashboardRepartoResponse> RepartoAsync(DateTime? desde, DateTime? hasta)
    {
        var (primero, ultimo) = Rango(desde, hasta);
        var alcance = await AlcanceAsync("fact.pedidos");

        var inicioUtc = Zona.AUtc(primero);
        var finUtc = Zona.AUtc(ultimo.AddDays(1));

        var pedidos = (await Acotar(_context.Pedidos.Where(p => p.Fecha >= inicioUtc && p.Fecha < finUtc), alcance)
                .Select(p => new
                {
                    p.Fecha,
                    p.Estado,
                    // Salió con faltantes o recortes: alguna novedad vigente lo dice.
                    ConNovedad = _context.NovedadesEntrega
                        .Any(nv => nv.PedidoId == p.Id && nv.Estado != EstadoNovedad.Anulada),
                    // La venta vigente quedó totalmente cobrada.
                    Cobrado = p.Ventas.Any(v => v.Estado == EstadoNotaVenta.Confirmada
                        && (v.Pagos.Where(x => !x.Anulado).Sum(x => (decimal?)x.Monto) ?? 0m)
                           >= (v.Detalle.Where(d => !d.Anulado).Sum(d => (decimal?)(d.Cantidad * d.PrecioUnitario)) ?? 0m)),
                })
                .AsNoTracking()
                .ToListAsync())
            .Select(p => new { Dia = Zona.DiaDe(p.Fecha), p.Estado, p.ConNovedad, p.Cobrado })
            .ToList();

        var dias = (int)(ultimo - primero).TotalDays + 1;
        var serie = Enumerable.Range(0, dias)
            .Select(i =>
            {
                var dia = primero.AddDays(i);
                var delDia = pedidos.Where(p => p.Dia == dia).ToList();
                return new DashDiaPedidos
                {
                    Fecha = dia,
                    Pendientes = delDia.Count(p => p.Estado == EstadoPedido.Pendiente),
                    Confirmados = delDia.Count(p => p.Estado == EstadoPedido.Confirmado),
                    Anulados = delDia.Count(p => p.Estado == EstadoPedido.Anulado),
                };
            })
            .ToList();

        var vigentes = pedidos.Where(p => p.Estado != EstadoPedido.Anulado).ToList();
        var confirmados = pedidos.Where(p => p.Estado == EstadoPedido.Confirmado).ToList();
        var completos = confirmados.Count(p => !p.ConNovedad);

        var respuesta = new DashboardRepartoResponse
        {
            Desde = primero,
            Hasta = ultimo,
            SoloPropio = alcance is { SinRestriccion: false },
            Serie = serie,
            PorEstado =
            [
                new() { Nombre = "Pendientes", Valor = pedidos.Count(p => p.Estado == EstadoPedido.Pendiente) },
                new() { Nombre = "Convertidos a venta", Valor = confirmados.Count },
                new() { Nombre = "Anulados", Valor = pedidos.Count(p => p.Estado == EstadoPedido.Anulado) },
            ],
            Embudo =
            [
                new() { Nombre = "Pedidos tomados", Valor = vigentes.Count },
                new() { Nombre = "Convertidos a venta", Valor = confirmados.Count },
                new() { Nombre = "Entregados completos", Valor = completos },
                new() { Nombre = "Cobrados del todo", Valor = confirmados.Count(p => p.Cobrado) },
            ],
            EntregaCompleta = confirmados.Count > 0 ? Math.Round((decimal)completos / confirmados.Count * 100, 1) : null,
        };

        // Las novedades tienen su propio permiso: quien ve pedidos no
        // necesariamente ve por qué se recortaron.
        if (_usuarioActual.Id is int uid && await _permisos.PuedeAsync(uid, "tms.novedades", Accion.Ver))
        {
            var novedades = await _context.NovedadesEntrega
                .Where(n => n.Estado != EstadoNovedad.Anulada && n.Fecha >= inicioUtc && n.Fecha < finUtc)
                .Select(n => new { Motivo = n.Motivo != null ? n.Motivo.Nombre : "Sin motivo", n.Importe })
                .AsNoTracking()
                .ToListAsync();

            respuesta.NovedadesPorMotivo = novedades
                .GroupBy(n => n.Motivo)
                .Select(g => new DashItem { Nombre = g.Key, Valor = R2(g.Sum(n => n.Importe)), Cantidad = g.Count() })
                .OrderByDescending(i => i.Valor)
                .ToList();
            respuesta.ImporteNovedades = R2(novedades.Sum(n => n.Importe));
        }

        return respuesta;
    }
}
