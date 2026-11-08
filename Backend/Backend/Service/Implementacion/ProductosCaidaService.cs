using Backend.Data;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Productos con caída: lo que vendió cada producto en el tramo elegido contra el mismo tramo del mes anterior (o del
/// año anterior), y en qué estado queda.
///
/// Dos maneras de decidir el estado, con la misma escala de colores que Clientes con caída:
///  - "variacion" (la de siempre): el % que cayó la venta frente al tramo anterior. Crítico 71 % o más, en riesgo
///    26 a 70, en seguimiento 11 a 25, normal 0 a 10 (o si vende más). Sin ventas en el tramo anterior no hay caída
///    que medir: "sin comparación".
///  - "dias": los días desde la última venta hasta el corte. 0 a 15 normal (activo), 16 a 30 en seguimiento, 31 a 60
///    en riesgo, 61 o más crítico. El que nunca se vendió queda "sin comparación".
///
/// Se mide en soles o en unidades. La venta es la de las notas de venta vigentes, menos lo recogido. Con un almacén
/// elegido todo se mide en él: la última venta es la de ese almacén y el stock el que tiene allí.
/// </summary>
public class ProductosCaidaService : IProductosCaidaService
{
    /// <summary>Hasta cuántos días un punto de la evolución es un día; de ahí en adelante, un mes.</summary>
    private const int MaxDiasPorDia = 62;

    /// <summary>Desde cuántos días sin venta empieza cada estado (criterio "dias").</summary>
    private static string EstadoPorDias(int dias) => dias switch
    {
        >= 61 => EstadoCaida.Critico,
        >= 31 => EstadoCaida.Riesgo,
        >= 16 => EstadoCaida.Seguimiento,
        _ => EstadoCaida.Normal,
    };

    private readonly AppDbContext _context;

    public ProductosCaidaService(AppDbContext context)
    {
        _context = context;
    }

    private readonly record struct Medida(decimal Monto, decimal Unidades);

    public async Task<ProductosCaidaResponse> AnalisisAsync(
        DateTime? desde, DateTime? hasta, string? comparar, string? medida, string? criterio,
        int? almacenId, int? categoriaId, int? marcaId, bool incluirSinStock)
    {
        if (comparar is not null && comparar is not ("mes" or "anio"))
            throw new BadRequestException("Compara contra el mes anterior (mes) o el año anterior (anio).");
        if (medida is not null && medida is not ("soles" or "unidades"))
            throw new BadRequestException("Mide en soles o en unidades.");
        if (criterio is not null && criterio is not ("variacion" or "dias"))
            throw new BadRequestException("El criterio es la variación de ventas o los días sin vender.");

        var contraAnio = comparar == "anio";
        var enSoles = medida != "unidades";
        var porDias = criterio == "dias";
        var periodo = PeriodoComparado.CrearContra(desde, hasta, Zona.Hoy, contraAnio);

        // Los días sin vender se cuentan hasta el fin del tramo; si llega al futuro, hasta hoy.
        var corte = periodo.Hasta > Zona.Hoy ? Zona.Hoy : periodo.Hasta;
        var corteFinUtc = Zona.AUtc(corte.AddDays(1));

        var productos = _context.Productos.AsNoTracking().Where(p => p.Activo && p.ControlaStock);
        if (categoriaId is int cat) productos = productos.Where(p => p.CategoriaId == cat);
        if (marcaId is int marca) productos = productos.Where(p => p.MarcaId == marca);

        var catalogo = await productos
            .Select(p => new
            {
                p.Id,
                p.Codigo,
                p.Nombre,
                p.Foto,
                p.CategoriaId,
                Categoria = p.Categoria != null ? p.Categoria.Nombre : null,
                Marca = p.Marca != null ? p.Marca.Nombre : null,
                UnidadBase = p.UnidadBase != null ? p.UnidadBase.Codigo : string.Empty,
                p.FechaCreacion,
            })
            .ToListAsync();

        var ventaActual = await VentasAsync(periodo.ActualIni, periodo.ActualFin, almacenId);
        var ventaAnterior = await VentasAsync(periodo.AnteriorIni, periodo.AnteriorFin, almacenId);
        var ultimas = await UltimasVentasAsync(corteFinUtc, almacenId);
        var existencias = await ExistenciasAsync(almacenId);
        var ingresos = await IngresosAsync(corteFinUtc, almacenId);

        var items = new List<ProductoCaidaFilaResponse>(catalogo.Count);
        foreach (var p in catalogo)
        {
            ventaActual.TryGetValue(p.Id, out var va);
            ventaAnterior.TryGetValue(p.Id, out var vb);
            var actual = enSoles ? va.Monto : va.Unidades;
            var anterior = enSoles ? vb.Monto : vb.Unidades;

            existencias.TryGetValue(p.Id, out var existencia);
            ingresos.TryGetValue(p.Id, out var ingreso);
            var tieneVenta = ultimas.TryGetValue(p.Id, out var ultima);

            // Sin ventas, los días corren desde que pudo venderse: su primer ingreso y, si no hay, el alta del producto.
            var referencia = tieneVenta ? ultima : ingreso.Primero ?? p.FechaCreacion;
            var dias = Math.Max(0, (int)(corte - Zona.DiaDe(referencia)).TotalDays);

            var stock = existencia.Stock;
            if (!incluirSinStock && stock <= 0) continue;

            items.Add(new ProductoCaidaFilaResponse
            {
                ProductoId = p.Id,
                Codigo = p.Codigo,
                Producto = p.Nombre,
                Foto = p.Foto,
                Marca = p.Marca,
                CategoriaId = p.CategoriaId,
                Categoria = p.Categoria ?? "SIN CATEGORÍA",
                UnidadBase = p.UnidadBase,
                UltimaVenta = tieneVenta ? Zona.DiaDe(ultima) : null,
                NuncaVendido = !tieneVenta,
                DiasSinVenta = dias,
                Stock = stock,
                CostoStock = Math.Round(existencia.Costo, 2),
                UltimaCompra = ingreso.Ultimo is DateTime uc ? Zona.DiaDe(uc) : null,
                Anterior = Math.Round(anterior, 2),
                Actual = Math.Round(actual, 2),
                Variacion = Math.Round(actual - anterior, 2),
                CaidaPct = EstadoCaida.CaidaPct(actual, anterior),
                Perdida = Math.Round(Math.Max(anterior - actual, 0m), 2),
                Estado = porDias
                    ? (tieneVenta ? EstadoPorDias(dias) : EstadoCaida.SinBase)
                    : EstadoCaida.Clasificar(actual, anterior),
            });
        }

        items = (porDias
                ? items.OrderByDescending(i => i.DiasSinVenta).ThenByDescending(i => i.Perdida)
                : items.OrderBy(i => i.Variacion).ThenByDescending(i => i.Perdida).ThenByDescending(i => i.DiasSinVenta))
            .ThenBy(i => i.Producto)
            .ToList();

        var porDia = (periodo.Hasta - periodo.Desde).TotalDays + 1 <= MaxDiasPorDia;

        return new ProductosCaidaResponse
        {
            Periodo = new PeriodoProductosResponse
            {
                Desde = periodo.Desde,
                Hasta = periodo.Hasta,
                AnteriorDesde = periodo.AnteriorDesde,
                AnteriorHasta = periodo.AnteriorHasta,
            },
            Comparar = contraAnio ? "anio" : "mes",
            Medida = enSoles ? "soles" : "unidades",
            Criterio = porDias ? "dias" : "variacion",
            Granularidad = porDia ? "dia" : "mes",
            Corte = corte,
            Resumen = Resumir(items),
            Estados = EstadoCaida.Todos
                .Select(e =>
                {
                    var delEstado = items.Where(i => i.Estado == e).ToList();
                    return new EstadoProductosResponse
                    {
                        Estado = e,
                        Productos = delEstado.Count,
                        CostoStock = Math.Round(delEstado.Sum(i => i.CostoStock), 2),
                        Perdida = Math.Round(delEstado.Sum(i => i.Perdida), 2),
                    };
                })
                .ToList(),
            PorCategoria = CategoriasConMayorCaida(items),
            Evolucion = await EvolucionAsync(periodo, items, almacenId, enSoles, porDia),
            Items = items,
        };
    }

    // ---------------------------------------------------------------- resumen

    private static ResumenProductosCaidaResponse Resumir(List<ProductoCaidaFilaResponse> items)
    {
        // Inmovilizado = lo que ya está en riesgo o crítico.
        var parado = items.Where(i => i.Estado is EstadoCaida.Riesgo or EstadoCaida.Critico).ToList();
        var enCaida = items.Where(i => i.Estado is EstadoCaida.Critico or EstadoCaida.Riesgo or EstadoCaida.Seguimiento).ToList();

        return new ResumenProductosCaidaResponse
        {
            TotalProductos = items.Count,
            EnCaida = enCaida.Count,
            ConStock = items.Count(i => i.Stock > 0),
            UnidadesInmovilizadas = parado.Where(i => i.Stock > 0).Sum(i => i.Stock),
            StockInmovilizado = Math.Round(parado.Sum(i => i.CostoStock), 2),
            VentaPerdida = Math.Round(enCaida.Sum(i => i.Perdida), 2),
        };
    }

    /// <summary>Las 10 categorías que más cayeron: lo que venden hoy sus productos contra lo que vendían antes.</summary>
    private static List<CategoriaCaidaResponse> CategoriasConMayorCaida(List<ProductoCaidaFilaResponse> items) =>
        items
            .GroupBy(i => i.Categoria)
            .Select(g =>
            {
                var anterior = g.Sum(i => i.Anterior);
                var actual = g.Sum(i => i.Actual);
                return new CategoriaCaidaResponse
                {
                    Categoria = g.Key,
                    Anterior = Math.Round(anterior, 2),
                    Actual = Math.Round(actual, 2),
                    Variacion = Math.Round(actual - anterior, 2),
                    CaidaPct = EstadoCaida.CaidaPct(actual, anterior),
                };
            })
            .Where(c => c.Variacion < 0)
            .OrderBy(c => c.Variacion)
            .Take(10)
            .ToList();

    // ------------------------------------------------------------------ ventas

    /// <summary>Lo vendido por producto en [ini, fin): las líneas vigentes menos lo recogido, en soles y en unidades.</summary>
    private async Task<Dictionary<int, Medida>> VentasAsync(DateTime ini, DateTime fin, int? almacenId)
    {
        var lineas = LineasVigentes(ini, fin, almacenId);
        var recojos = RecojosVigentes(ini, fin, almacenId);

        var vendido = (await lineas
                .GroupBy(d => d.ProductoId)
                .Select(g => new
                {
                    ProductoId = g.Key,
                    Monto = g.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion),
                    Unidades = g.Sum(d => d.Cantidad),
                })
                .ToListAsync())
            .ToDictionary(x => x.ProductoId, x => new Medida(x.Monto, x.Unidades));

        var recogido = await recojos
            .GroupBy(r => r.ProductoId)
            .Select(g => new { ProductoId = g.Key, Monto = g.Sum(r => r.Importe), Unidades = g.Sum(r => r.Cantidad) })
            .ToListAsync();

        foreach (var r in recogido)
        {
            vendido.TryGetValue(r.ProductoId, out var previo);
            vendido[r.ProductoId] = new Medida(previo.Monto - r.Monto, previo.Unidades - r.Unidades);
        }

        return vendido;
    }

    private IQueryable<NotaVentaDetalle> LineasVigentes(DateTime ini, DateTime fin, int? almacenId)
    {
        var lineas = _context.NotaVentaDetalles.AsNoTracking()
            .Where(d => !d.Anulado
                        && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && d.NotaVenta.Fecha >= ini && d.NotaVenta.Fecha < fin);
        return almacenId is int a ? lineas.Where(d => d.NotaVenta!.AlmacenId == a) : lineas;
    }

    private IQueryable<RecojoVenta> RecojosVigentes(DateTime ini, DateTime fin, int? almacenId)
    {
        var recojos = _context.RecojosVenta.AsNoTracking()
            .Where(r => r.Estado != EstadoRecojo.Anulado
                        && r.NotaVenta!.Estado != EstadoNotaVenta.Anulada
                        && r.NotaVenta.Fecha >= ini && r.NotaVenta.Fecha < fin);
        return almacenId is int a ? recojos.Where(r => r.NotaVenta!.AlmacenId == a) : recojos;
    }

    /// <summary>La fecha (UTC) de la última venta vigente de cada producto hasta el corte.</summary>
    private async Task<Dictionary<int, DateTime>> UltimasVentasAsync(DateTime corteFinUtc, int? almacenId)
    {
        var lineas = _context.NotaVentaDetalles.AsNoTracking()
            .Where(d => !d.Anulado && d.NotaVenta!.Estado != EstadoNotaVenta.Anulada && d.NotaVenta.Fecha < corteFinUtc);
        if (almacenId is int a) lineas = lineas.Where(d => d.NotaVenta!.AlmacenId == a);

        return await lineas
            .GroupBy(d => d.ProductoId)
            .Select(g => new { ProductoId = g.Key, Ultima = g.Max(d => d.NotaVenta!.Fecha) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Ultima);
    }

    // ------------------------------------------------------------------- stock

    private readonly record struct Existencia(decimal Stock, decimal Costo);

    /// <summary>Lo que hay de cada producto y lo que vale a su costo (las capas con saldo), en todos los almacenes o en uno.</summary>
    private async Task<Dictionary<int, Existencia>> ExistenciasAsync(int? almacenId)
    {
        var capas = _context.CapasCosto.AsNoTracking().Where(c => c.CantidadDisponible > 0);
        if (almacenId is int a) capas = capas.Where(c => c.AlmacenId == a);

        return (await capas
                .GroupBy(c => c.ProductoId)
                .Select(g => new
                {
                    ProductoId = g.Key,
                    Stock = g.Sum(c => c.CantidadDisponible),
                    Costo = g.Sum(c => c.CantidadDisponible * c.CostoUnitario),
                })
                .ToListAsync())
            .ToDictionary(x => x.ProductoId, x => new Existencia(x.Stock, x.Costo));
    }

    private readonly record struct Ingreso(DateTime? Primero, DateTime? Ultimo);

    /// <summary>El primer y el último ingreso de mercadería de cada producto hasta el corte (sin contar devoluciones de stock).</summary>
    private async Task<Dictionary<int, Ingreso>> IngresosAsync(DateTime corteFinUtc, int? almacenId)
    {
        var entradas = _context.Movimientos.AsNoTracking()
            .Where(m => m.Tipo == TipoMovimiento.Entrada && m.MovimientoOrigenId == null && m.Fecha < corteFinUtc);
        if (almacenId is int a) entradas = entradas.Where(m => m.AlmacenId == a);

        return (await entradas
                .GroupBy(m => m.ProductoId)
                .Select(g => new { ProductoId = g.Key, Primero = g.Min(m => m.Fecha), Ultimo = g.Max(m => m.Fecha) })
                .ToListAsync())
            .ToDictionary(x => x.ProductoId, x => new Ingreso(x.Primero, x.Ultimo));
    }

    // --------------------------------------------------------------- evolución

    /// <summary>Lo vendido por un producto en un punto de la evolución (un día o un mes).</summary>
    private readonly record struct PuntoProducto(int ProductoId, int Indice, decimal Monto, decimal Unidades);

    /// <summary>
    /// La evolución de lo vendido, punto a punto, de los productos que cayeron y de cada estado: el tramo actual frente al
    /// tramo anterior. Un punto es un día si el tramo es corto y un mes si es largo; el punto del tramo anterior que le
    /// corresponde es el mismo día (o el mismo mes) un mes o un año antes.
    /// </summary>
    private async Task<List<SerieEvolucionResponse>> EvolucionAsync(
        PeriodoComparado periodo, List<ProductoCaidaFilaResponse> items, int? almacenId, bool enSoles, bool porDia)
    {
        var actual = await PuntosAsync(periodo.ActualIni, periodo.ActualFin, periodo.Desde, almacenId, porDia);
        var anterior = await PuntosAsync(periodo.AnteriorIni, periodo.AnteriorFin, periodo.AnteriorDesde, almacenId, porDia);

        var cantidad = porDia
            ? (int)(periodo.Hasta - periodo.Desde).TotalDays + 1
            : (periodo.Hasta.Year * 12 + periodo.Hasta.Month) - (periodo.Desde.Year * 12 + periodo.Desde.Month) + 1;

        string Etiqueta(int i) => porDia
            ? periodo.Desde.AddDays(i).ToString("yyyy-MM-dd")
            : periodo.Desde.AddMonths(i).ToString("yyyy-MM");

        decimal Valor(PuntoProducto p) => enSoles ? p.Monto : p.Unidades;

        SerieEvolucionResponse Serie(string clave, IEnumerable<ProductoCaidaFilaResponse> productos)
        {
            var ids = productos.ToList();
            var idsSet = ids.Select(i => i.ProductoId).ToHashSet();

            var puntosActual = actual.Where(p => idsSet.Contains(p.ProductoId)).GroupBy(p => p.Indice)
                .ToDictionary(g => g.Key, g => g.Sum(Valor));
            var puntosAnterior = anterior.Where(p => idsSet.Contains(p.ProductoId)).GroupBy(p => p.Indice)
                .ToDictionary(g => g.Key, g => g.Sum(Valor));

            return new SerieEvolucionResponse
            {
                Clave = clave,
                Anterior = Math.Round(ids.Sum(i => i.Anterior), 2),
                Actual = Math.Round(ids.Sum(i => i.Actual), 2),
                Puntos = Enumerable.Range(0, cantidad)
                    .Select(i => new PuntoEvolucionResponse
                    {
                        Etiqueta = Etiqueta(i),
                        Anterior = Math.Round(puntosAnterior.GetValueOrDefault(i), 2),
                        Actual = Math.Round(puntosActual.GetValueOrDefault(i), 2),
                    })
                    .ToList(),
            };
        }

        // "Todos": los que ya vendieron menos (su suma es la venta perdida de las tarjetas). Por estado: ese estado; los
        // que no tienen con qué compararse entran todos, y los demás solo si cayeron.
        var series = new List<SerieEvolucionResponse>
        {
            Serie("TODOS", items.Where(i => i.Estado != EstadoCaida.SinBase && i.Perdida > 0)),
        };
        foreach (var estado in EstadoCaida.Todos)
        {
            series.Add(Serie(estado, items.Where(i => i.Estado == estado && (estado == EstadoCaida.SinBase || i.Perdida > 0))));
        }
        return series;
    }

    /// <summary>
    /// Lo vendido por producto en cada punto del tramo [ini, fin): el índice cuenta días (o meses) desde el inicio del tramo
    /// en hora local. Las líneas vigentes menos lo recogido.
    /// </summary>
    private async Task<List<PuntoProducto>> PuntosAsync(DateTime ini, DateTime fin, DateTime inicioLocal, int? almacenId, bool porDia)
    {
        var lineas = LineasVigentes(ini, fin, almacenId);
        var recojos = RecojosVigentes(ini, fin, almacenId);

        // Agrupar en la base por día local (o por mes local): las fechas se guardan en UTC y el día de la calle va cinco horas atrás.
        int Indice(DateTime dia) => porDia
            ? (int)(dia.Date - inicioLocal.Date).TotalDays
            : (dia.Year * 12 + dia.Month) - (inicioLocal.Year * 12 + inicioLocal.Month);

        var puntos = new Dictionary<(int Producto, int Indice), (decimal Monto, decimal Unidades)>();

        void Sumar(int productoId, DateTime dia, decimal monto, decimal unidades, int signo)
        {
            var clave = (productoId, Indice(dia));
            puntos.TryGetValue(clave, out var previo);
            puntos[clave] = (previo.Monto + signo * monto, previo.Unidades + signo * unidades);
        }

        if (porDia)
        {
            foreach (var x in await lineas
                         .GroupBy(d => new { d.ProductoId, Dia = d.NotaVenta!.Fecha.AddHours(-5).Date })
                         .Select(g => new
                         {
                             g.Key.ProductoId,
                             g.Key.Dia,
                             Monto = g.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion),
                             Unidades = g.Sum(d => d.Cantidad),
                         })
                         .ToListAsync())
                Sumar(x.ProductoId, x.Dia, x.Monto, x.Unidades, 1);

            foreach (var x in await recojos
                         .GroupBy(r => new { r.ProductoId, Dia = r.NotaVenta!.Fecha.AddHours(-5).Date })
                         .Select(g => new { g.Key.ProductoId, g.Key.Dia, Monto = g.Sum(r => r.Importe), Unidades = g.Sum(r => r.Cantidad) })
                         .ToListAsync())
                Sumar(x.ProductoId, x.Dia, x.Monto, x.Unidades, -1);
        }
        else
        {
            foreach (var x in await lineas
                         .GroupBy(d => new
                         {
                             d.ProductoId,
                             Anio = d.NotaVenta!.Fecha.AddHours(-5).Year,
                             Mes = d.NotaVenta.Fecha.AddHours(-5).Month,
                         })
                         .Select(g => new
                         {
                             g.Key.ProductoId,
                             g.Key.Anio,
                             g.Key.Mes,
                             Monto = g.Sum(d => d.CantidadPresentacion * d.PrecioPresentacion),
                             Unidades = g.Sum(d => d.Cantidad),
                         })
                         .ToListAsync())
                Sumar(x.ProductoId, new DateTime(x.Anio, x.Mes, 1), x.Monto, x.Unidades, 1);

            foreach (var x in await recojos
                         .GroupBy(r => new
                         {
                             r.ProductoId,
                             Anio = r.NotaVenta!.Fecha.AddHours(-5).Year,
                             Mes = r.NotaVenta.Fecha.AddHours(-5).Month,
                         })
                         .Select(g => new { g.Key.ProductoId, g.Key.Anio, g.Key.Mes, Monto = g.Sum(r => r.Importe), Unidades = g.Sum(r => r.Cantidad) })
                         .ToListAsync())
                Sumar(x.ProductoId, new DateTime(x.Anio, x.Mes, 1), x.Monto, x.Unidades, -1);
        }

        return puntos.Select(p => new PuntoProducto(p.Key.Producto, p.Key.Indice, p.Value.Monto, p.Value.Unidades)).ToList();
    }
}
