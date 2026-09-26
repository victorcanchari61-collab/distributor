using System.Globalization;
using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Cuánto se ganó con cada producto.
///
///   - Importe: lo que valen las líneas de las notas de venta vigentes. Una
///     devolución aprobada ya bajó la línea, así que no hay que restarla otra vez.
///   - Costo: lo que costó la mercadería que salió, que es el costo real que
///     dejó cada salida (la más antigua primero), no un costo de referencia.
///     Se suma por línea vendida sumando sus movimientos: la salida cuenta, la
///     devolución que repuso stock resta, y la devolución dañada —que entra y
///     sale en el acto— no cambia nada: la pérdida queda a la vista.
///   - Ganancia: NO es Importe menos Costo. Es <see cref="LineaGanancia.ValorVenta"/>
///     (el importe SIN el IGV de las líneas afectas) menos Costo — lo cobrado
///     de más por el IGV no es ganancia, es plata que se le pasa al fisco.
///
/// La base es el producto. Vendedor, venta, categoría, marca y fechas recortan
/// qué ventas entran en la suma; los gastos de ruta no están aquí porque no
/// pertenecen a ningún producto.
/// </summary>
public class GananciaService : IGananciaService
{
    /// <summary>Un año basta para comparar; más es pedir el sistema entero de golpe.</summary>
    private const int MaximoDias = 366;

    private const string SinVendedor = "Sin asignar";
    private const string SinCategoria = "Sin categoría";
    private const string SinMarca = "Sin marca";

    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;

    public GananciaService(AppDbContext context, IPermisoService permisos, IUsuarioActual usuarioActual)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
    }

    public async Task<GananciaPaginaResponse> ListarAsync(ConsultaTablaRequest consulta)
    {
        // El día se cuenta como en la calle: un pedido de las 8 de la noche es
        // de ESE día aunque en UTC ya sea el siguiente.
        var hoy = Zona.Hoy;
        var filtroFecha = consulta.Filtro("fecha");
        var desdeFiltro = Dia(filtroFecha?.Valor);
        var hastaFiltro = Dia(filtroFecha?.ValorHasta);

        var ultimo = hastaFiltro ?? hoy;
        var primero = desdeFiltro ?? new DateTime(ultimo.Year, ultimo.Month, 1);

        if (primero > ultimo)
            throw new BadRequestException("El \"desde\" no puede ser después del \"hasta\".");

        if ((ultimo - primero).TotalDays >= MaximoDias)
            throw new BadRequestException($"Elige un rango de hasta {MaximoDias} días.");

        var inicioUtc = Zona.AUtc(primero);
        var finUtc = Zona.AUtc(ultimo.AddDays(1));

        var (notas, soloPropio) = await NotasDelRangoAsync(inicioUtc, finUtc);
        var todas = Lineas(notas);

        // Lo que hay para elegir se arma ANTES de filtrar: si al elegir un
        // vendedor las demás opciones se encogieran, no habría cómo cambiarlo.
        // Cada lista es un DISTINCT en la base: no se traen las líneas.
        var opciones = new GananciaOpcionesResponse
        {
            Vendedores = Distintos(await todas.Select(l => l.Vendedor).Distinct().ToListAsync()),
            Categorias = Distintos(await todas.Select(l => l.Categoria).Distinct().ToListAsync()),
            Marcas = Distintos(await todas.Select(l => l.Marca).Distinct().ToListAsync()),
            Productos = Distintos(await todas.Select(l => l.Producto).Distinct().ToListAsync()),
            Ventas = Distintos(await todas.Select(l => l.Venta).Distinct().ToListAsync()),
        };

        var lineas = Filtrar(todas, consulta);

        /*
         * La suma por producto la hace la base: viaja una fila por producto, no
         * una por línea vendida. El valor sin IGV se arma aquí con el importe
         * afecto y el que no lo es: dividir la suma es lo mismo que sumar cada
         * línea dividida, como se hacía antes.
         */
        var grupos = await lineas
            .GroupBy(l => l.ProductoId)
            .Select(g => new
            {
                ProductoId = g.Key,
                Codigo = g.Max(l => l.Codigo),
                Producto = g.Max(l => l.Producto),
                Categoria = g.Max(l => l.Categoria),
                Marca = g.Max(l => l.Marca),
                UnidadBase = g.Max(l => l.UnidadBase),
                Cantidad = g.Sum(l => l.Cantidad),
                Importe = g.Sum(l => l.Importe),
                ImporteAfecto = g.Sum(l => l.AfectoIgv ? l.Importe : 0m),
                Costo = g.Sum(l => l.Costo),
                Ventas = g.Select(l => l.NotaVentaId).Distinct().Count(),
                UltimaVenta = g.Max(l => l.Fecha),
                LineasSinCosto = g.Sum(l => l.Importe > 0 && l.Costo <= 0 ? 1 : 0),
            })
            .ToListAsync();

        var productos = grupos.Select(g =>
        {
            var importe = Math.Round(g.Importe, 2);
            var valorVenta = Math.Round(ValorVenta(g.Importe, g.ImporteAfecto), 2);
            var costo = Math.Round(g.Costo, 2);
            return new GananciaProductoResponse
            {
                ProductoId = g.ProductoId,
                // Max() sobre texto se declara anulable, pero ninguno llega
                // nulo: la categoría y la marca ya traen su "Sin ..." desde la
                // línea, y los otros son obligatorios en el producto.
                Codigo = g.Codigo ?? string.Empty,
                Producto = g.Producto ?? string.Empty,
                Categoria = g.Categoria ?? SinCategoria,
                Marca = g.Marca ?? SinMarca,
                Cantidad = g.Cantidad,
                UnidadBase = g.UnidadBase ?? string.Empty,
                Ventas = g.Ventas,
                UltimaVenta = Zona.DiaDe(g.UltimaVenta),
                Importe = importe,
                Costo = costo,
                // La ganancia sale del valor de venta SIN el IGV: el importe cobrado
                // trae ese 18% que no es ingreso, es plata que se le pasa al fisco.
                Ganancia = valorVenta - costo,
                Margen = Margen(valorVenta, valorVenta - costo),
                SinCosto = g.LineasSinCosto > 0,
            };
        }).ToList();

        var totalImporte = Math.Round(grupos.Sum(g => g.Importe), 2);
        var totalValorVenta = Math.Round(grupos.Sum(g => ValorVenta(g.Importe, g.ImporteAfecto)), 2);
        var totalCosto = Math.Round(grupos.Sum(g => g.Costo), 2);

        var resumen = new GananciaResumenResponse
        {
            Desde = primero,
            Hasta = ultimo,
            SoloPropio = soloPropio,
            Ventas = await lineas.Select(l => l.NotaVentaId).Distinct().CountAsync(),
            Productos = productos.Count,
            Importe = totalImporte,
            Costo = totalCosto,
            Ganancia = totalValorVenta - totalCosto,
            Margen = Margen(totalValorVenta, totalValorVenta - totalCosto),
            LineasSinCosto = grupos.Sum(g => g.LineasSinCosto),
        };

        // Ordenar y paginar sobre los productos (unos cientos), no sobre las líneas.
        var pagina = Ordenar(productos, consulta)
            .Skip((consulta.PaginaSegura - 1) * consulta.PorPaginaSegura)
            .Take(consulta.PorPaginaSegura)
            .ToList();

        // En qué ventas y con qué vendedores salió cada producto: solo los de la página.
        var ids = pagina.Select(p => p.ProductoId).ToList();
        var dondeSalio = await lineas
            .Where(l => ids.Contains(l.ProductoId))
            .Select(l => new { l.ProductoId, l.Venta, l.Fecha, l.Vendedor })
            .Distinct()
            .ToListAsync();
        var porProducto = dondeSalio.ToLookup(x => x.ProductoId);
        foreach (var p in pagina)
        {
            var suyas = porProducto[p.ProductoId];
            p.Notas = suyas.OrderBy(x => x.Fecha).Select(x => x.Venta).Distinct().ToList();
            p.Vendedores = Distintos(suyas.Select(x => x.Vendedor));
        }

        return new GananciaPaginaResponse
        {
            Items = pagina,
            Total = productos.Count,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
            Resumen = resumen,
            Opciones = opciones,
        };
    }

    /// <summary>
    /// Las líneas vendidas entre dos instantes (UTC), cada una con lo que costó,
    /// ya acotadas a lo que la persona tiene permitido ver.
    ///
    /// Es la base común de esta pantalla y del dashboard: si cada una calculara
    /// el costo por su cuenta, dos pantallas dirían dos ganancias distintas.
    /// </summary>
    public async Task<(List<LineaGanancia> Lineas, bool SoloPropio)> LineasAsync(
        DateTime inicioUtc, DateTime finUtc)
    {
        var (notas, soloPropio) = await NotasDelRangoAsync(inicioUtc, finUtc);

        var lineas = (await Lineas(notas).AsNoTracking().ToListAsync())
            .Select(l => new LineaGanancia(
                l.NotaVentaId, l.Venta, l.Fecha, l.Vendedor,
                l.ProductoId, l.Codigo, l.Producto, l.Categoria, l.Marca,
                l.UnidadBase, l.Cantidad, l.Importe, l.Costo, l.AfectoIgv))
            .ToList();

        return (lineas, soloPropio);
    }

    /// <summary>
    /// Las notas vigentes del rango, recortadas al alcance de quien pregunta.
    /// Sin usuario en el token (llamada interna) no hay a quién acotar.
    /// </summary>
    private async Task<(IQueryable<NotaVenta> Notas, bool SoloPropio)> NotasDelRangoAsync(
        DateTime inicioUtc, DateTime finUtc)
    {
        var alcance = _usuarioActual.Id is int uid
            ? await _permisos.AlcanceFiltroAsync(uid, "finanzas.ganancias")
            : null;

        var notas = _context.NotasVenta
            .Where(n => n.Estado != EstadoNotaVenta.Anulada && n.Fecha >= inicioUtc && n.Fecha < finUtc);

        if (alcance is { SinRestriccion: false })
        {
            var ruta = alcance.RutaId;
            notas = alcance.SoloPropios
                ? notas.Where(n => n.UsuarioId == alcance.UsuarioId)
                : notas.Where(n => n.UsuarioId == alcance.UsuarioId
                                   || (ruta != null && n.Cliente != null && n.Cliente.RutaId == ruta));
        }

        return (notas, alcance is { SinRestriccion: false });
    }

    /// <summary>Una línea vendida con su costo, tal como la ve la base (sin traerla todavía).</summary>
    private sealed class LineaVendida
    {
        public int NotaVentaId { get; set; }
        public string Venta { get; set; } = string.Empty;
        public DateTime Fecha { get; set; }
        public string Vendedor { get; set; } = string.Empty;
        public int ProductoId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Producto { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public string Marca { get; set; } = string.Empty;
        public string UnidadBase { get; set; } = string.Empty;
        public decimal Cantidad { get; set; }
        public decimal Importe { get; set; }
        public bool AfectoIgv { get; set; }
        public decimal Costo { get; set; }
    }

    /// <summary>
    /// Las líneas de esas notas. El costo es el de sus movimientos: la salida
    /// suma y la devolución que repuso stock resta.
    /// </summary>
    private IQueryable<LineaVendida> Lineas(IQueryable<NotaVenta> notas) =>
        notas
            .SelectMany(n => n.Detalle)
            .Select(d => new LineaVendida
            {
                NotaVentaId = d.NotaVentaId,
                Venta = d.NotaVenta!.Numero,
                Fecha = d.NotaVenta.Fecha,
                Vendedor = d.NotaVenta.Usuario != null ? d.NotaVenta.Usuario.Nombre : SinVendedor,
                ProductoId = d.ProductoId,
                Codigo = d.Producto!.Codigo,
                Producto = d.Producto.Nombre,
                Categoria = d.Producto.Categoria != null ? d.Producto.Categoria.Nombre : SinCategoria,
                Marca = d.Producto.Marca != null ? d.Producto.Marca.Nombre : SinMarca,
                UnidadBase = d.Producto.UnidadBase != null ? d.Producto.UnidadBase.Codigo : string.Empty,
                Cantidad = d.Anulado ? 0m : d.Cantidad,
                Importe = d.Anulado ? 0m : d.CantidadPresentacion * d.PrecioPresentacion,
                AfectoIgv = d.AfectoIgv,
                Costo = _context.Movimientos
                    .Where(m => m.NotaVentaDetalleId == d.Id)
                    .Sum(m => (decimal?)(m.Tipo == TipoMovimiento.Salida ? m.CostoTotal : -m.CostoTotal)) ?? 0m,
            });

    /// <summary>Los filtros del panel y el buscador, resueltos en la base.</summary>
    private static IQueryable<LineaVendida> Filtrar(IQueryable<LineaVendida> lineas, ConsultaTablaRequest consulta)
    {
        var query = lineas;

        if (consulta.ValorDe("vendedor") is string vendedor)
            query = query.Where(l => l.Vendedor == vendedor);

        if (consulta.ValorDe("categoria") is string categoria)
            query = query.Where(l => l.Categoria == categoria);

        if (consulta.ValorDe("marca") is string marca)
            query = query.Where(l => l.Marca == marca);

        // Venta y producto se eligen de una lista, así que llegan exactos.
        if (consulta.ValorDe("venta") is string venta)
            query = query.Where(l => l.Venta == venta);

        if (consulta.ValorDe("producto") is string producto)
            query = query.Where(l => l.Producto == producto);

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = $"%{consulta.Buscar.Trim()}%";
            query = query.Where(l =>
                EF.Functions.Like(l.Producto, texto) || EF.Functions.Like(l.Codigo, texto)
                || EF.Functions.Like(l.Categoria, texto) || EF.Functions.Like(l.Marca, texto));
        }

        return query;
    }

    /// <summary>El importe sin IGV: la parte afecta sin el impuesto, más la que no lo lleva.</summary>
    private static decimal ValorVenta(decimal importe, decimal importeAfecto) =>
        importeAfecto / (1 + Impuestos.TasaIgv) + (importe - importeAfecto);

    private static IEnumerable<GananciaProductoResponse> Ordenar(
        List<GananciaProductoResponse> productos, ConsultaTablaRequest consulta)
    {
        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        // Sin orden elegido, lo que más ganancia deja va primero.
        if (string.IsNullOrEmpty(consulta.Orden))
            return productos.OrderByDescending(p => p.Ganancia).ThenBy(p => p.Producto, StringComparer.OrdinalIgnoreCase);

        Func<GananciaProductoResponse, object?> clave = consulta.Orden switch
        {
            "producto" => p => p.Producto.ToLowerInvariant(),
            "categoria" => p => p.Categoria.ToLowerInvariant(),
            "marca" => p => p.Marca.ToLowerInvariant(),
            "cantidad" => p => p.Cantidad,
            "ventas" or "venta" => p => p.Ventas,
            "fecha" => p => p.UltimaVenta,
            "importe" => p => p.Importe,
            "costo" => p => p.Costo,
            "margen" => p => p.Margen ?? decimal.MinValue,
            _ => p => p.Ganancia,
        };

        return desc
            ? productos.OrderByDescending(clave).ThenBy(p => p.Producto, StringComparer.OrdinalIgnoreCase)
            : productos.OrderBy(clave).ThenBy(p => p.Producto, StringComparer.OrdinalIgnoreCase);
    }

    private static List<string> Distintos(IEnumerable<string> valores) =>
        valores.Distinct().OrderBy(v => v, StringComparer.OrdinalIgnoreCase).ToList();

    /// <summary>Un día como lo manda el panel de filtros: yyyy-MM-dd.</summary>
    private static DateTime? Dia(string? valor) =>
        DateTime.TryParse(valor, CultureInfo.InvariantCulture, DateTimeStyles.None, out var d) ? d.Date : null;

    private static decimal? Margen(decimal importe, decimal ganancia) =>
        importe > 0 ? Math.Round(ganancia / importe * 100, 1) : null;
}
