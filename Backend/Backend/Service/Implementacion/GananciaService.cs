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

        // Lo que ve cada quien: el alcance del submódulo. Sin usuario en el
        // token (llamada interna) no hay a quién acotar.
        var (todas, soloPropio) = await LineasAsync(inicioUtc, finUtc);

        // Lo que hay para elegir se arma ANTES de filtrar: si al elegir un
        // vendedor las demás opciones se encogieran, no habría cómo cambiarlo.
        var opciones = new GananciaOpcionesResponse
        {
            Vendedores = Distintos(todas.Select(l => l.Vendedor)),
            Categorias = Distintos(todas.Select(l => l.Categoria)),
            Marcas = Distintos(todas.Select(l => l.Marca)),
            Productos = Distintos(todas.Select(l => l.Producto)),
            Ventas = Distintos(todas.Select(l => l.Venta)),
        };

        var lineas = Filtrar(todas, consulta);

        var productos = lineas
            .GroupBy(l => l.ProductoId)
            .Select(g =>
            {
                var primera = g.First();
                var importe = Math.Round(g.Sum(l => l.Importe), 2);
                var valorVenta = Math.Round(g.Sum(l => l.ValorVenta), 2);
                var costo = Math.Round(g.Sum(l => l.Costo), 2);
                return new GananciaProductoResponse
                {
                    ProductoId = g.Key,
                    Codigo = primera.Codigo,
                    Producto = primera.Producto,
                    Categoria = primera.Categoria,
                    Marca = primera.Marca,
                    Cantidad = g.Sum(l => l.Cantidad),
                    UnidadBase = primera.UnidadBase,
                    Ventas = g.Select(l => l.NotaVentaId).Distinct().Count(),
                    Notas = g.OrderBy(l => l.Fecha).Select(l => l.Venta).Distinct().ToList(),
                    Vendedores = Distintos(g.Select(l => l.Vendedor)),
                    UltimaVenta = Zona.DiaDe(g.Max(l => l.Fecha)),
                    Importe = importe,
                    Costo = costo,
                    // La ganancia sale del valor de venta SIN el IGV: el importe cobrado
                    // trae ese 18% que no es ingreso, es plata que se le pasa al fisco.
                    Ganancia = valorVenta - costo,
                    Margen = Margen(valorVenta, valorVenta - costo),
                    SinCosto = g.Any(l => l.Importe > 0 && l.Costo <= 0),
                };
            })
            .ToList();

        var totalImporte = Math.Round(lineas.Sum(l => l.Importe), 2);
        var totalValorVenta = Math.Round(lineas.Sum(l => l.ValorVenta), 2);
        var totalCosto = Math.Round(lineas.Sum(l => l.Costo), 2);

        var resumen = new GananciaResumenResponse
        {
            Desde = primero,
            Hasta = ultimo,
            SoloPropio = soloPropio,
            Ventas = lineas.Select(l => l.NotaVentaId).Distinct().Count(),
            Productos = productos.Count,
            Importe = totalImporte,
            Costo = totalCosto,
            Ganancia = totalValorVenta - totalCosto,
            Margen = Margen(totalValorVenta, totalValorVenta - totalCosto),
            LineasSinCosto = lineas.Count(l => l.Importe > 0 && l.Costo <= 0),
        };

        var ordenados = Ordenar(productos, consulta);
        var pagina = ordenados
            .Skip((consulta.PaginaSegura - 1) * consulta.PorPaginaSegura)
            .Take(consulta.PorPaginaSegura)
            .ToList();

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
        // Lo que ve cada quien: el alcance del submódulo. Sin usuario en el
        // token (llamada interna) no hay a quién acotar.
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

        var lineas = (await notas
                .SelectMany(n => n.Detalle)
                .Select(d => new
                {
                    d.NotaVentaId,
                    Venta = d.NotaVenta!.Numero,
                    d.NotaVenta.Fecha,
                    Vendedor = d.NotaVenta.Usuario != null ? d.NotaVenta.Usuario.Nombre : null,
                    d.ProductoId,
                    Codigo = d.Producto!.Codigo,
                    Producto = d.Producto.Nombre,
                    Categoria = d.Producto.Categoria != null ? d.Producto.Categoria.Nombre : null,
                    Marca = d.Producto.Marca != null ? d.Producto.Marca.Nombre : null,
                    UnidadBase = d.Producto.UnidadBase != null ? d.Producto.UnidadBase.Codigo : string.Empty,
                    Cantidad = d.Anulado ? 0m : d.Cantidad,
                    Importe = d.Anulado ? 0m : d.CantidadPresentacion * d.PrecioPresentacion,
                    d.AfectoIgv,
                    Costo = _context.Movimientos
                        .Where(m => m.NotaVentaDetalleId == d.Id)
                        .Sum(m => (decimal?)(m.Tipo == TipoMovimiento.Salida ? m.CostoTotal : -m.CostoTotal)) ?? 0m,
                })
                .AsNoTracking()
                .ToListAsync())
            .Select(l => new LineaGanancia(
                l.NotaVentaId, l.Venta, l.Fecha,
                l.Vendedor ?? SinVendedor,
                l.ProductoId, l.Codigo, l.Producto,
                l.Categoria ?? SinCategoria,
                l.Marca ?? SinMarca,
                l.UnidadBase, l.Cantidad, l.Importe, l.Costo, l.AfectoIgv))
            .ToList();

        return (lineas, alcance is { SinRestriccion: false });
    }

    /// <summary>Los filtros del panel y el buscador, sobre las líneas del rango.</summary>
    private static List<LineaGanancia> Filtrar(List<LineaGanancia> lineas, ConsultaTablaRequest consulta)
    {
        IEnumerable<LineaGanancia> query = lineas;

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
            var texto = consulta.Buscar.Trim();
            query = query.Where(l =>
                Contiene(l.Producto, texto) || Contiene(l.Codigo, texto)
                || Contiene(l.Categoria, texto) || Contiene(l.Marca, texto));
        }

        return query.ToList();
    }

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

    private static bool Contiene(string texto, string buscado) =>
        texto.Contains(buscado, StringComparison.OrdinalIgnoreCase);

    /// <summary>Un día como lo manda el panel de filtros: yyyy-MM-dd.</summary>
    private static DateTime? Dia(string? valor) =>
        DateTime.TryParse(valor, CultureInfo.InvariantCulture, DateTimeStyles.None, out var d) ? d.Date : null;

    private static decimal? Margen(decimal importe, decimal ganancia) =>
        importe > 0 ? Math.Round(ganancia / importe * 100, 1) : null;
}
