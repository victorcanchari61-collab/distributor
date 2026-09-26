using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Implementacion;

public class InventarioRepository : IInventarioRepository
{
    private readonly AppDbContext _context;

    public InventarioRepository(AppDbContext context)
    {
        _context = context;
    }

    public Task<IDbContextTransaction> IniciarTransaccionAsync() =>
        _context.Database.BeginTransactionAsync();

    public Task GuardarAsync() => _context.SaveChangesAsync();

    // ------------------------------------------------------------- Almacenes

    public async Task<IEnumerable<Almacen>> GetAlmacenesAsync() =>
        await _context.Almacenes
            .OrderByDescending(a => a.Activo)
            .ThenByDescending(a => a.EsPrincipal)
            .ThenBy(a => a.Nombre)
            .ToListAsync();

    public async Task<IEnumerable<MovimientoInventario>> GetEntradasRecientesAsync(DateTime desde) =>
        await _context.Movimientos
            .Include(m => m.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(m => m.Almacen)
            .Include(m => m.Documento)
            .Where(m => m.Tipo == TipoMovimiento.Entrada
                        && m.Fecha >= desde
                        && m.Documento!.Estado == EstadoDocumento.Confirmado
                        && (m.Documento.Tipo == TipoDocumentoInventario.Recepcion
                            || m.Documento.Tipo == TipoDocumentoInventario.Ajuste))
            .OrderByDescending(m => m.Fecha)
            .ToListAsync();

    public async Task<Almacen?> GetAlmacenAsync(int id) =>
        await _context.Almacenes.FirstOrDefaultAsync(a => a.Id == id);

    public async Task<Almacen?> GetAlmacenPrincipalAsync() =>
        await _context.Almacenes
            .Where(a => a.Activo)
            .OrderByDescending(a => a.EsPrincipal)
            .ThenBy(a => a.Id)
            .FirstOrDefaultAsync();

    public async Task<bool> ExisteCodigoAlmacenAsync(string codigo, int? excepto = null) =>
        await _context.Almacenes.AnyAsync(a =>
            a.Codigo == codigo && (excepto == null || a.Id != excepto));

    public async Task<Almacen> AddAlmacenAsync(Almacen almacen)
    {
        await _context.Almacenes.AddAsync(almacen);
        await _context.SaveChangesAsync();
        return almacen;
    }

    public async Task UpdateAlmacenAsync(Almacen almacen)
    {
        _context.Almacenes.Update(almacen);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAlmacenAsync(Almacen almacen)
    {
        _context.Almacenes.Remove(almacen);
        await _context.SaveChangesAsync();
    }

    public async Task<int> ContarMovimientosAlmacenAsync(int almacenId) =>
        await _context.Movimientos.CountAsync(m => m.AlmacenId == almacenId);

    // ---------------------------------------------------------------- Motivos

    public async Task<IEnumerable<MotivoMovimiento>> GetMotivosAsync() =>
        await _context.MotivosMovimiento
            .OrderByDescending(m => m.Activo)
            .ThenBy(m => m.DelSistema)
            .ThenBy(m => m.Nombre)
            .ToListAsync();

    public async Task<MotivoMovimiento?> GetMotivoAsync(int id) =>
        await _context.MotivosMovimiento.FirstOrDefaultAsync(m => m.Id == id);

    public async Task<bool> ExisteCodigoMotivoAsync(string codigo, int? excepto = null) =>
        await _context.MotivosMovimiento.AnyAsync(m =>
            m.Codigo == codigo && (excepto == null || m.Id != excepto));

    public async Task<int> ContarMovimientosMotivoAsync(int motivoId) =>
        await _context.Movimientos.CountAsync(m => m.MotivoId == motivoId);

    public async Task<MotivoMovimiento> AddMotivoAsync(MotivoMovimiento motivo)
    {
        await _context.MotivosMovimiento.AddAsync(motivo);
        await _context.SaveChangesAsync();
        return motivo;
    }

    public async Task UpdateMotivoAsync(MotivoMovimiento motivo)
    {
        _context.MotivosMovimiento.Update(motivo);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteMotivoAsync(MotivoMovimiento motivo)
    {
        _context.MotivosMovimiento.Remove(motivo);
        await _context.SaveChangesAsync();
    }

    // ----------------------------------------------------------------- Capas

    public async Task<List<CapaCosto>> GetCapasParaConsumirAsync(int productoId, int almacenId)
    {
        // FOR UPDATE: mientras esta transaccion decide de que capas descuenta,
        // ninguna otra puede tocarlas. Sin esto, dos ventas al mismo tiempo
        // leerian el mismo saldo y el stock terminaria negativo.
        return await _context.CapasCosto
            .FromSqlRaw(
                """
                SELECT * FROM `CapasCosto`
                WHERE `ProductoId` = {0} AND `AlmacenId` = {1} AND `CantidadDisponible` > 0
                ORDER BY `Fecha`, `Id`
                FOR UPDATE
                """,
                productoId, almacenId)
            .ToListAsync();
    }

    public async Task<List<CapaCosto>> GetCapasDisponiblesAsync(int productoId, int? almacenId = null) =>
        await _context.CapasCosto
            .Where(c => c.ProductoId == productoId
                        && c.CantidadDisponible > 0
                        && (almacenId == null || c.AlmacenId == almacenId))
            .OrderBy(c => c.Fecha)
            .ThenBy(c => c.Id)
            .ToListAsync();

    public async Task<CapaCosto?> GetCapaAsync(int id) =>
        await _context.CapasCosto.FirstOrDefaultAsync(c => c.Id == id);

    public async Task<CapaCosto?> GetUltimaCapaAsync(int productoId, int? almacenId = null) =>
        await _context.CapasCosto
            .Where(c => c.ProductoId == productoId && (almacenId == null || c.AlmacenId == almacenId))
            .OrderByDescending(c => c.Fecha)
            .ThenByDescending(c => c.Id)
            .FirstOrDefaultAsync();

    public async Task<List<CapaCosto>> GetCapasDeMovimientoAsync(int movimientoId) =>
        await _context.CapasCosto.Where(c => c.MovimientoId == movimientoId).ToListAsync();

    public async Task AddCapaAsync(CapaCosto capa) => await _context.CapasCosto.AddAsync(capa);

    public async Task<ResumenStockResponse> ResumenStockAsync(int? almacenId)
    {
        var capas = _context.CapasCosto
            .Where(c => c.CantidadDisponible > 0 && (almacenId == null || c.AlmacenId == almacenId));

        // Por producto: cuanto queda. De ahi salen los dos contadores.
        var porProducto = await capas
            .GroupBy(c => c.ProductoId)
            .Select(g => new { ProductoId = g.Key, Stock = g.Sum(c => c.CantidadDisponible) })
            .ToListAsync();

        var minimos = await _context.Productos
            .Where(p => p.ControlaStock && p.StockMinimo > 0)
            .Select(p => new { p.Id, p.StockMinimo })
            .ToListAsync();

        var stockPorProducto = porProducto.ToDictionary(x => x.ProductoId, x => x.Stock);

        return new ResumenStockResponse
        {
            ConStock = porProducto.Count(x => x.Stock > 0),
            // Un producto sin capas tambien esta bajo el minimo: tiene cero.
            BajoMinimo = minimos.Count(m => stockPorProducto.GetValueOrDefault(m.Id) <= m.StockMinimo),
            Valorizado = await capas.SumAsync(c => (decimal?)(c.CantidadDisponible * c.CostoUnitario)) ?? 0m,
        };
    }

    public async Task<HashSet<int>> GetProductoIdsConCapasAsync(int? almacenId) =>
        (await _context.CapasCosto
            .Where(c => almacenId == null || c.AlmacenId == almacenId)
            .Select(c => c.ProductoId)
            .Distinct()
            .ToListAsync()).ToHashSet();

    public async Task<Dictionary<int, ResumenStock>> GetResumenAsync(
        IEnumerable<int> productoIds, int? almacenId = null)
    {
        var ids = productoIds.ToList();

        var filas = await _context.CapasCosto
            .Where(c => ids.Contains(c.ProductoId)
                        && c.CantidadDisponible > 0
                        && (almacenId == null || c.AlmacenId == almacenId))
            .GroupBy(c => c.ProductoId)
            .Select(g => new
            {
                ProductoId = g.Key,
                Stock = g.Sum(c => c.CantidadDisponible),
                Valorizado = g.Sum(c => c.CantidadDisponible * c.CostoUnitario),
                CostoMin = g.Min(c => c.CostoUnitario),
                CostoMax = g.Max(c => c.CostoUnitario)
            })
            .ToListAsync();

        return filas.ToDictionary(
            f => f.ProductoId,
            f => new ResumenStock(f.Stock, f.Valorizado, f.CostoMin, f.CostoMax));
    }

    public async Task<Dictionary<int, ActividadStock>> GetActividadAsync(
        IEnumerable<int>? productoIds, int? almacenId, int dias)
    {
        var ids = productoIds?.ToList();
        var desde = DateTime.UtcNow.AddDays(-dias);

        var movimientos = _context.Movimientos
            .Where(m => (ids == null || ids.Contains(m.ProductoId))
                        && (almacenId == null || m.AlmacenId == almacenId));

        /*
         * La última entrada y la última salida. Agrupado por producto, tipo y
         * almacén —y no solo por producto con un MAX condicional— para que la
         * base lo resuelva saltando por el índice (ProductoId, Tipo, AlmacenId,
         * Fecha) en vez de leer todo el historial de cada producto.
         */
        var ultimas = await movimientos
            .GroupBy(m => new { m.ProductoId, m.Tipo, m.AlmacenId })
            .Select(g => new { g.Key.ProductoId, g.Key.Tipo, Fecha = g.Max(m => m.Fecha) })
            .ToListAsync();

        // Solo lo que salio POR VENTA en el ultimo mes: un traslado o un ajuste
        // no dicen nada de cuanto dura el stock, y lo viejo tampoco.
        var vendido = await movimientos
            .Where(m => m.MotivoId == Motivos.Venta && m.Fecha >= desde)
            .GroupBy(m => m.ProductoId)
            .Select(g => new { ProductoId = g.Key, Cantidad = g.Sum(m => m.Cantidad) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Cantidad);

        return ultimas
            .GroupBy(u => u.ProductoId)
            .ToDictionary(
                g => g.Key,
                g => new ActividadStock(
                    g.Where(u => u.Tipo == TipoMovimiento.Entrada).Select(u => (DateTime?)u.Fecha).Max(),
                    g.Where(u => u.Tipo == TipoMovimiento.Salida).Select(u => (DateTime?)u.Fecha).Max(),
                    vendido.GetValueOrDefault(g.Key)));
    }

    public async Task<List<CapaCosto>> GetCapasDisponiblesAsync(IEnumerable<int> productoIds, int? almacenId)
    {
        var ids = productoIds.ToList();
        return await _context.CapasCosto
            .AsNoTracking()
            .Where(c => ids.Contains(c.ProductoId)
                        && c.CantidadDisponible > 0
                        && (almacenId == null || c.AlmacenId == almacenId))
            .OrderBy(c => c.Fecha)
            .ThenBy(c => c.Id)
            .ToListAsync();
    }

    public async Task<Dictionary<int, (int Productos, decimal Valorizado)>> GetTotalesPorAlmacenAsync(int? almacenId = null)
    {
        var filas = await _context.CapasCosto
            .Where(c => c.CantidadDisponible > 0 && (almacenId == null || c.AlmacenId == almacenId))
            .GroupBy(c => c.AlmacenId)
            .Select(g => new
            {
                AlmacenId = g.Key,
                Productos = g.Select(c => c.ProductoId).Distinct().Count(),
                Valorizado = g.Sum(c => c.CantidadDisponible * c.CostoUnitario),
            })
            .ToListAsync();
        return filas.ToDictionary(f => f.AlmacenId, f => (f.Productos, f.Valorizado));
    }

    public async Task<Dictionary<int, decimal>> GetStockPorProductoAsync(int? almacenId) =>
        await _context.CapasCosto
            .Where(c => c.CantidadDisponible > 0
                        && (almacenId == null || c.AlmacenId == almacenId)
                        && c.Producto!.ControlaStock)
            .GroupBy(c => c.ProductoId)
            .Select(g => new { ProductoId = g.Key, Stock = g.Sum(c => c.CantidadDisponible) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Stock);

    // ------------------------------------------------- Documentos y kardex

    public async Task<string> SiguienteNumeroAsync(string tipo)
    {
        var prefijo = tipo switch
        {
            TipoDocumentoInventario.Anulacion => "AN",
            TipoDocumentoInventario.Transferencia => "TR",
            TipoDocumentoInventario.Prestamo => "PR",
            TipoDocumentoInventario.DevolucionPrestamo => "DP",
            TipoDocumentoInventario.Recepcion => "RC",
            TipoDocumentoInventario.NotaVenta => "SV",
            TipoDocumentoInventario.DevolucionCliente => "DC",
            TipoDocumentoInventario.Recojo => "RJ",
            _ => "AJ"
        };

        var ultimo = await _context.DocumentosInventario
            .Where(d => d.Tipo == tipo)
            .OrderByDescending(d => d.Id)
            .Select(d => d.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"{prefijo}-{correlativo:D4}";
    }

    public async Task AddDocumentoAsync(DocumentoInventario documento) =>
        await _context.DocumentosInventario.AddAsync(documento);

    private IQueryable<DocumentoInventario> DocumentosConDetalle() =>
        _context.DocumentosInventario
            .Include(d => d.Almacen)
            .Include(d => d.AlmacenDestino)
            .Include(d => d.Motivo)
            .Include(d => d.Usuario)
            .Include(d => d.Compra)
            .Include(d => d.Movimientos)
            .ThenInclude(m => m.Producto)
            // La unidad de cada línea: sin esto salía vacía en el detalle.
            .ThenInclude(p => p!.UnidadBase)
            .Include(d => d.Movimientos)
            .ThenInclude(m => m.Presentacion)
            .Include(d => d.Movimientos)
            .ThenInclude(m => m.Almacen);

    public async Task<DocumentoInventario?> GetDocumentoAsync(int id) =>
        await DocumentosConDetalle().FirstOrDefaultAsync(d => d.Id == id);

    public async Task<IEnumerable<DocumentoInventario>> GetDocumentosAsync(string? familia = null) =>
        await DocumentosConDetalle()
            // Sin familia, todo. Con familia, el propio tipo o la anulacion
            // de un documento de esa familia: sin el segundo termino, anular
            // una transferencia la haria desaparecer de su propia pantalla.
            .Where(d => familia == null
                        || d.Tipo == familia
                        || (d.Tipo == TipoDocumentoInventario.Anulacion
                            && d.DocumentoAnulado!.Tipo == familia))
            .OrderByDescending(d => d.Fecha)
            .ThenByDescending(d => d.Id)
            .Take(300)
            .ToListAsync();

    /// <summary>Los documentos de una familia, sin ordenar ni paginar todavia.</summary>
    // Sin Include: el listado se proyecta y el resumen solo cuenta. El detalle
    // viene con el documento completo (DocumentosConDetalle) al abrirlo.
    private IQueryable<DocumentoInventario> DocumentosDe(string? familia) =>
        _context.DocumentosInventario
            .Where(d => familia == null
                        || d.Tipo == familia
                        || (d.Tipo == TipoDocumentoInventario.Anulacion
                            && d.DocumentoAnulado!.Tipo == familia))
            .AsNoTracking();

    public async Task<(List<DocumentoInventarioResponse> Items, int Total)> ListarDocumentosAsync(
        ConsultaTablaRequest consulta, string? familia)
    {
        var query = DocumentosDe(familia);

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(d =>
                EF.Functions.Like(d.Numero, $"%{texto}%")
                || (d.Almacen != null && EF.Functions.Like(d.Almacen.Nombre, $"%{texto}%"))
                || (d.Motivo != null && EF.Functions.Like(d.Motivo.Nombre, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
            query = query.Where(d => EF.Functions.Like(d.Numero, $"%{numero}%"));

        if (consulta.ValorDe("almacen") is string almacen)
            query = query.Where(d => d.Almacen != null && d.Almacen.Nombre == almacen);

        // Solo lo usa Transferencias: los demas documentos no tienen un segundo almacen.
        if (consulta.ValorDe("almacenDestino") is string almacenDestino)
            query = query.Where(d => d.AlmacenDestino != null && d.AlmacenDestino.Nombre == almacenDestino);

        // Solo lo usa Recepciones: los demas documentos no cuelgan de una compra.
        if (consulta.ValorDe("compra") is string compra)
            query = query.Where(d => d.Compra != null && d.Compra.Numero == compra);

        if (consulta.ValorDe("motivo") is string motivo)
            query = query.Where(d => d.Motivo != null && d.Motivo.Nombre == motivo);

        if (consulta.ValorDe("estado") is string estado)
            query = query.Where(d => d.Estado == estado);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(d => d.Fecha >= desde);
        if (hasta is not null) query = query.Where(d => d.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc ? query.OrderByDescending(d => d.Numero).ThenByDescending(d => d.Id)
                             : query.OrderBy(d => d.Numero).ThenBy(d => d.Id),
            "almacen" => desc ? query.OrderByDescending(d => d.Almacen!.Nombre).ThenByDescending(d => d.Id)
                              : query.OrderBy(d => d.Almacen!.Nombre).ThenBy(d => d.Id),
            "motivo" => desc ? query.OrderByDescending(d => d.Motivo!.Nombre).ThenByDescending(d => d.Id)
                             : query.OrderBy(d => d.Motivo!.Nombre).ThenBy(d => d.Id),
            "estado" => desc ? query.OrderByDescending(d => d.Estado).ThenByDescending(d => d.Id)
                             : query.OrderBy(d => d.Estado).ThenBy(d => d.Id),
            _ => desc ? query.OrderByDescending(d => d.Fecha).ThenByDescending(d => d.Id)
                      : query.OrderBy(d => d.Fecha).ThenBy(d => d.Id),
        };

        // El total y las líneas como subconsultas, y "anulado por" también: ni
        // se cargan los movimientos ni se hace una consulta por cada anulado.
        var documentos = _context.DocumentosInventario;
        return await query
            .Select(d => new DocumentoInventarioResponse
            {
                Id = d.Id,
                Numero = d.Numero,
                Tipo = d.Tipo,
                Fecha = d.Fecha,
                AlmacenId = d.AlmacenId,
                Almacen = d.Almacen != null ? d.Almacen.Nombre : string.Empty,
                AlmacenDestinoId = d.AlmacenDestinoId,
                AlmacenDestino = d.AlmacenDestino != null ? d.AlmacenDestino.Nombre : null,
                CompraId = d.CompraId,
                Compra = d.Compra != null ? d.Compra.Numero : null,
                MotivoId = d.MotivoId,
                Motivo = d.Motivo != null ? d.Motivo.Nombre : string.Empty,
                MotivoTipo = d.Motivo != null ? d.Motivo.Tipo : string.Empty,
                Estado = d.Estado,
                Observacion = d.Observacion,
                Usuario = d.Usuario != null ? d.Usuario.Nombre : null,
                AnuladoPor = d.Estado == EstadoDocumento.Anulado
                    ? documentos.Where(x => x.DocumentoAnuladoId == d.Id).Select(x => x.Numero).FirstOrDefault()
                    : null,
                Total = d.Movimientos.Sum(m => m.CostoTotal),
                Lineas = d.Movimientos.Count(),
            })
            .PaginarAsync(consulta);
    }

    public async Task<(int Total, int Confirmados, int Anulados)> ResumenDocumentosAsync(string? familia) => (
        await DocumentosDe(familia).CountAsync(),
        await DocumentosDe(familia).CountAsync(d => d.Estado == EstadoDocumento.Confirmado),
        await DocumentosDe(familia).CountAsync(d => d.Estado == EstadoDocumento.Anulado));

    public async Task<ResumenPrestamosResponse> ResumenPrestamosAsync() => new()
    {
        Total = await _context.Prestamos.CountAsync(),
        Pendientes = await _context.Prestamos.CountAsync(p => p.Estado == EstadoPrestamo.Pendiente),
        Devueltos = await _context.Prestamos.CountAsync(p => p.Estado == EstadoPrestamo.Devuelto),
    };

    public async Task<(List<PrestamoFilaResponse> Items, int Total)> ListarPrestamosAsync(ConsultaTablaRequest consulta)
    {
        // Sin Include: la fila se proyecta al final, sin detalle ni devoluciones.
        var query = _context.Prestamos.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(p => EF.Functions.Like(p.Numero, $"%{texto}%")
                                     || EF.Functions.Like(p.Contraparte, $"%{texto}%"));
        }

        if (consulta.ValorDe("numero") is string numero)
            query = query.Where(p => EF.Functions.Like(p.Numero, $"%{numero}%"));

        if (consulta.ValorDe("contraparte") is string contraparte)
            query = query.Where(p => EF.Functions.Like(p.Contraparte, $"%{contraparte}%"));

        if (consulta.ValorDe("estado") is string estado)
            query = query.Where(p => p.Estado == estado);

        if (consulta.ValorDe("tipo") is string tipo)
            query = query.Where(p => p.Tipo == tipo);

        // La tabla lo ofrece como filtro: sin esto se ignoraba.
        if (consulta.ValorDe("almacen") is string almacen)
            query = query.Where(p => p.Almacen != null && p.Almacen.Nombre == almacen);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(p => p.Fecha >= desde);
        if (hasta is not null) query = query.Where(p => p.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc ? query.OrderByDescending(p => p.Numero).ThenByDescending(p => p.Id)
                             : query.OrderBy(p => p.Numero).ThenBy(p => p.Id),
            "contraparte" => desc ? query.OrderByDescending(p => p.Contraparte).ThenByDescending(p => p.Id)
                                  : query.OrderBy(p => p.Contraparte).ThenBy(p => p.Id),
            "estado" => desc ? query.OrderByDescending(p => p.Estado).ThenByDescending(p => p.Id)
                             : query.OrderBy(p => p.Estado).ThenBy(p => p.Id),
            _ => desc ? query.OrderByDescending(p => p.Fecha).ThenByDescending(p => p.Id)
                      : query.OrderBy(p => p.Fecha).ThenBy(p => p.Id),
        };

        var pagina = await query
            .Select(p => new PrestamoFilaResponse
            {
                Id = p.Id,
                Numero = p.Numero,
                Tipo = p.Tipo,
                Contraparte = p.Contraparte,
                AlmacenId = p.AlmacenId,
                Almacen = p.Almacen != null ? p.Almacen.Nombre : string.Empty,
                Fecha = p.Fecha,
                Estado = p.Estado,
                Total = p.Detalle.Sum(d => d.Movimiento != null ? d.Movimiento.CostoTotal : 0),
                TieneDevolucion = p.Detalle.Any(d => d.CantidadDevuelta > 0),
            })
            .PaginarAsync(consulta);

        foreach (var f in pagina.Items) f.Total = Math.Round(f.Total, 2);
        return pagina;
    }

    public async Task UpdateDocumentoAsync(DocumentoInventario documento)
    {
        _context.DocumentosInventario.Update(documento);
        await _context.SaveChangesAsync();
    }

    public async Task<string?> GetNumeroAnulacionAsync(int documentoId) =>
        await _context.DocumentosInventario
            .Where(d => d.DocumentoAnuladoId == documentoId)
            .Select(d => d.Numero)
            .FirstOrDefaultAsync();

    public async Task AddDocumentoMovimientoAsync(MovimientoInventario movimiento) =>
        await _context.Movimientos.AddAsync(movimiento);

    public async Task<List<MovimientoInventario>> GetMovimientosDocumentoAsync(int documentoId) =>
        await _context.Movimientos
            .Where(m => m.DocumentoId == documentoId)
            .ToListAsync();

    /// <summary>El kardex del almacen elegido, sin ordenar ni paginar todavia.</summary>
    private IQueryable<MovimientoInventario> KardexBase(int? almacenId) =>
        _context.Movimientos
            .Where(m => almacenId == null || m.AlmacenId == almacenId)
            .AsNoTracking();

    /*
     * El kardex sale de dos sitios: los movimientos y lo que reservan los
     * pedidos.
     *
     * Cada uno se filtra y ordena SOBRE SU TABLA —el motor no sabe ordenar ni
     * filtrar por los campos de una proyeccion— y recien al final se dicen en
     * la misma forma, FilaKardex, para poder mezclarlos.
     */
    private IQueryable<MovimientoInventario> MovimientosFiltrados(
        int? almacenId, ConsultaTablaRequest consulta)
    {
        var query = _context.Movimientos
            .AsNoTracking()
            .Where(m => almacenId == null || m.AlmacenId == almacenId);

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(m =>
                EF.Functions.Like(m.Producto!.Nombre, $"%{texto}%")
                || EF.Functions.Like(m.Documento!.Numero, $"%{texto}%")
                || EF.Functions.Like(m.Motivo!.Nombre, $"%{texto}%")
                || EF.Functions.Like(m.Almacen!.Nombre, $"%{texto}%"));
        }

        if (consulta.ValorDe("producto") is string producto)
            query = query.Where(m => m.Producto!.Nombre == producto);

        if (consulta.ValorDe("motivo") is string motivo)
            query = query.Where(m => m.Motivo!.Nombre == motivo);

        if (consulta.ValorDe("almacen") is string almacen)
            query = query.Where(m => m.Almacen!.Nombre == almacen);

        if (consulta.ValorDe("documento") is string documento)
            query = query.Where(m => EF.Functions.Like(m.Documento!.Numero, $"%{documento}%"));

        if (consulta.ValorDe("tipoDocumento") is string tipoDocumento)
            query = query.Where(m => m.Documento!.Tipo == tipoDocumento);

        // Filtrar por RESERVA no deja ningun movimiento: son de la otra fuente.
        if (consulta.ValorDe("tipo") is string tipo)
            query = query.Where(m => m.Tipo == tipo);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(m => m.Fecha >= desde);
        if (hasta is not null) query = query.Where(m => m.Fecha <= hasta);

        return query;
    }

    /*
     * Lo que un pedido aparta, como un renglon mas del libro.
     *
     * No es un movimiento: la mercaderia sigue en el almacen y el saldo no se
     * toca. Pero esta comprometida, y quien lee el kardex tiene que ver por
     * que el disponible no cuadra con el stock. Salen los pedidos que pidieron
     * reserva, incluso los ya convertidos o anulados: es el historial de lo
     * que paso, no la foto de lo que sigue apartado.
     */
    private IQueryable<PedidoDetalle> ReservasFiltradas(
        int? almacenId, ConsultaTablaRequest consulta)
    {
        var query = _context.PedidoDetalles
            .AsNoTracking()
            .Where(d => d.Pedido!.ReservaStock
                        && !d.Anulado
                        && d.Pedido.AlmacenId != null
                        && (almacenId == null || d.Pedido.AlmacenId == almacenId));

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(d =>
                EF.Functions.Like(d.Producto!.Nombre, $"%{texto}%")
                || EF.Functions.Like(d.Pedido!.Numero, $"%{texto}%")
                || EF.Functions.Like(d.Pedido.Almacen!.Nombre, $"%{texto}%")
                || EF.Functions.Like("Reserva de pedido", $"%{texto}%"));
        }

        if (consulta.ValorDe("producto") is string producto)
            query = query.Where(d => d.Producto!.Nombre == producto);

        if (consulta.ValorDe("almacen") is string almacen)
            query = query.Where(d => d.Pedido!.Almacen!.Nombre == almacen);

        if (consulta.ValorDe("documento") is string documento)
            query = query.Where(d => EF.Functions.Like(d.Pedido!.Numero, $"%{documento}%"));

        // Una reserva no nace de ningun documento: si se filtra por tipo de
        // documento, ninguna reserva puede calzar.
        if (consulta.ValorDe("tipoDocumento") is string)
            query = query.Where(d => false);

        // El motivo de una reserva es siempre el mismo, y el tipo tambien: si
        // piden otro, esta fuente no aporta nada.
        if (consulta.ValorDe("motivo") is string motivo && motivo != "Reserva de pedido")
            query = query.Where(d => false);

        if (consulta.ValorDe("tipo") is string tipo && tipo != TipoKardex.Reserva)
            query = query.Where(d => false);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(d => d.Pedido!.Fecha >= desde);
        if (hasta is not null) query = query.Where(d => d.Pedido!.Fecha <= hasta);

        return query;
    }

    /*
     * Una pagina del kardex, mezclando las dos fuentes.
     *
     * Unirlas en SQL seria lo natural, pero el motor no sabe hacer un UNION de
     * dos consultas ya proyectadas —y proyectar es justo lo que las vuelve
     * comparables—. Asi que de cada una se traen las primeras `hasta` filas:
     * la ventana que la pagina necesita esta contenida ahi, porque ninguna
     * fuente puede aportar mas de esa cantidad antes del corte.
     */
    public async Task<(List<FilaKardex> Items, int Total, Dictionary<(int Producto, int Almacen), SaldoKardex> Aperturas,
            List<MovimientoSaldo> Intermedios)>
        ListarKardexAsync(ConsultaTablaRequest consulta, int? almacenId)
    {
        var movimientos = MovimientosFiltrados(almacenId, consulta);
        var reservas = ReservasFiltradas(almacenId, consulta);

        var total = await movimientos.CountAsync() + await reservas.CountAsync();

        // El kardex es un libro cronologico: el unico orden que admite es por
        // fecha. Ordenar por otra columna partiria la pagina en un tramo no
        // contiguo y el saldo acumulado dejaria de tener sentido.
        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);
        var saltar = (consulta.PaginaSegura - 1) * consulta.PorPaginaSegura;
        var hasta = saltar + consulta.PorPaginaSegura;

        var deMovimientos = await (desc
                ? movimientos.OrderByDescending(m => m.Fecha).ThenByDescending(m => m.Id)
                : movimientos.OrderBy(m => m.Fecha).ThenBy(m => m.Id))
            .Take(hasta)
            .Select(m => new FilaKardex(
                m.Id,
                m.Fecha,
                m.Documento!.Numero,
                m.Documento.Tipo,
                m.Documento.Estado == EstadoDocumento.Anulado,
                m.Motivo!.Nombre,
                m.Tipo,
                m.ProductoId,
                m.Producto!.Nombre,
                m.Producto.UnidadBase!.Codigo,
                m.AlmacenId,
                m.Almacen!.Nombre,
                m.Presentacion != null ? m.Presentacion.Nombre : null,
                m.CantidadPresentacion,
                m.Cantidad,
                m.CostoUnitario,
                m.CostoTotal))
            .ToListAsync();

        // El id de una reserva va en negativo para no chocar con el de un
        // movimiento: los dos conviven en la misma lista, y por eso tambien se
        // ordena por el negativo.
        var deReservas = await (desc
                ? reservas.OrderByDescending(d => d.Pedido!.Fecha).ThenByDescending(d => -d.Id)
                : reservas.OrderBy(d => d.Pedido!.Fecha).ThenBy(d => -d.Id))
            .Take(hasta)
            .Select(d => new FilaKardex(
                -d.Id,
                d.Pedido!.Fecha,
                d.Pedido.Numero,
                string.Empty,
                d.Pedido.Estado == EstadoPedido.Anulado,
                "Reserva de pedido",
                TipoKardex.Reserva,
                d.ProductoId,
                d.Producto!.Nombre,
                d.Producto.UnidadBase!.Codigo,
                d.Pedido.AlmacenId!.Value,
                d.Pedido.Almacen!.Nombre,
                d.Presentacion != null ? d.Presentacion.Nombre : null,
                d.CantidadPresentacion,
                d.Cantidad,
                0m,
                0m))
            .ToListAsync();

        var mezcla = deMovimientos.Concat(deReservas);
        var items = (desc
                ? mezcla.OrderByDescending(f => f.Fecha).ThenByDescending(f => f.Id)
                : mezcla.OrderBy(f => f.Fecha).ThenBy(f => f.Id))
            .Skip(saltar)
            .Take(consulta.PorPaginaSegura)
            .ToList();

        var aperturas = new Dictionary<(int, int), SaldoKardex>();
        var intermedios = new List<MovimientoSaldo>();
        if (items.Count > 0)
        {
            var cronologico = items.OrderBy(f => f.Fecha).ThenBy(f => f.Id).ToList();
            var primera = cronologico[0];
            var ultima = cronologico[^1];

            /*
             * El saldo es del libro entero, no de lo filtrado: si se filtra por
             * "salidas", el saldo de cada salida igual tiene que contar las
             * entradas de antes. Por eso se lee sin los filtros de la tabla,
             * pero SOLO para los productos y almacenes que aparecen en la
             * página: así no se recorre el historial de todo el catálogo.
             */
            var productos = items.Select(f => f.ProductoId).Distinct().ToList();
            var almacenes = items.Select(f => f.AlmacenId).Distinct().ToList();
            var libro = KardexBase(almacenId)
                .Where(m => productos.Contains(m.ProductoId) && almacenes.Contains(m.AlmacenId));

            // Los movimientos reales entre la primera y la última fila, estén o
            // no en la página: con ellos cada fila lleva el saldo verdadero.
            intermedios = await libro
                .Where(m => (m.Fecha > primera.Fecha || (m.Fecha == primera.Fecha && m.Id >= primera.Id))
                            && (m.Fecha < ultima.Fecha || (m.Fecha == ultima.Fecha && m.Id <= ultima.Id)))
                .Select(m => new MovimientoSaldo(m.Id, m.Fecha, m.ProductoId, m.AlmacenId, m.Tipo, m.Cantidad, m.CostoTotal))
                .ToListAsync();

            // Saldo con el que entra la pagina: todo lo anterior al renglon
            // mas viejo que se va a mostrar, sumado por producto y almacen.
            // Solo cuentan los movimientos: una reserva no mueve stock.
            var previos = await libro
                .Where(m => m.Fecha < primera.Fecha
                            || (m.Fecha == primera.Fecha && m.Id < primera.Id))
                .GroupBy(m => new { m.ProductoId, m.AlmacenId })
                .Select(g => new
                {
                    g.Key.ProductoId,
                    g.Key.AlmacenId,
                    Saldo = g.Sum(m => m.Tipo == TipoMovimiento.Entrada ? m.Cantidad : -m.Cantidad),
                    // Lo mismo en plata: entra por lo que costo, sale por lo
                    // que costaba la capa que se consumio.
                    Valor = g.Sum(m => m.Tipo == TipoMovimiento.Entrada
                        ? m.CostoTotal
                        : -m.CostoTotal),
                })
                .ToListAsync();

            foreach (var p in previos)
            {
                aperturas[(p.ProductoId, p.AlmacenId)] = new SaldoKardex(p.Saldo, p.Valor);
            }
        }

        return (items, total, aperturas, intermedios);
    }

    public async Task<(int Entradas, int Salidas)> ResumenKardexAsync(int? almacenId) => (
        await KardexBase(almacenId).CountAsync(m => m.Tipo == TipoMovimiento.Entrada),
        await KardexBase(almacenId).CountAsync(m => m.Tipo == TipoMovimiento.Salida));

    public async Task<Dictionary<(int Producto, int Almacen), SaldoKardex>> GetSaldosAntesAsync(
        DateTime antes, IEnumerable<int> productoIds, int? almacenId)
    {
        var ids = productoIds.ToList();
        var filas = await _context.Movimientos
            .Where(m => m.Fecha < antes && ids.Contains(m.ProductoId)
                        && (almacenId == null || m.AlmacenId == almacenId))
            .GroupBy(m => new { m.ProductoId, m.AlmacenId })
            .Select(g => new
            {
                g.Key.ProductoId,
                g.Key.AlmacenId,
                Cantidad = g.Sum(m => m.Tipo == TipoMovimiento.Entrada ? m.Cantidad : -m.Cantidad),
                Valor = g.Sum(m => m.Tipo == TipoMovimiento.Entrada ? m.CostoTotal : -m.CostoTotal),
            })
            .ToListAsync();
        return filas.ToDictionary(f => (f.ProductoId, f.AlmacenId), f => new SaldoKardex(f.Cantidad, f.Valor));
    }

    public async Task<List<MovimientoInventario>> GetKardexAsync(
        int? productoId, int? almacenId, DateTime? desde, DateTime? hasta) =>
        await _context.Movimientos
            .Include(m => m.Documento)
            .Include(m => m.Producto)
            .ThenInclude(p => p!.UnidadBase)
            .Include(m => m.Motivo)
            .Include(m => m.Almacen)
            .Include(m => m.Presentacion)
            .Where(m => (productoId == null || m.ProductoId == productoId)
                        && (almacenId == null || m.AlmacenId == almacenId)
                        && (desde == null || m.Fecha >= desde)
                        && (hasta == null || m.Fecha <= hasta))
            // De mas antiguo a mas nuevo: el saldo se acumula en ese orden.
            .OrderBy(m => m.Fecha)
            .ThenBy(m => m.Id)
            .ToListAsync();

    public async Task<MovimientoInventario?> GetMovimientoDeVentaAsync(int notaVentaDetalleId) =>
        await _context.Movimientos
            .Where(m => m.NotaVentaDetalleId == notaVentaDetalleId
                        && m.Tipo == TipoMovimiento.Salida)
            .OrderBy(m => m.Id)
            .FirstOrDefaultAsync();

    public async Task<List<ConsumoCapa>> GetConsumosAsync(int movimientoId) =>
        await _context.Consumos
            .Include(c => c.Capa)
            .Where(c => c.MovimientoId == movimientoId)
            .ToListAsync();

    public async Task<List<CapaCosto>> GetCapasConVencimientoAsync() =>
        await _context.CapasCosto
            .Include(c => c.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(c => c.Almacen)
            .Where(c => c.CantidadDisponible > 0 && c.FechaVencimiento != null)
            // La que vence primero, arriba: es la que urge revisar.
            .OrderBy(c => c.FechaVencimiento)
            .ThenBy(c => c.Id)
            .ToListAsync();

    public async Task AddConsumoAsync(ConsumoCapa consumo) =>
        await _context.Consumos.AddAsync(consumo);

    // -------------------------------------------------------------- Prestamos

    public async Task AddPrestamoAsync(Prestamo prestamo) =>
        await _context.Prestamos.AddAsync(prestamo);

    private IQueryable<Prestamo> PrestamosConDetalle() =>
        _context.Prestamos
            .Include(p => p.Almacen)
            .Include(p => p.Usuario)
            .Include(p => p.Detalle)
            .ThenInclude(d => d.Producto)
            .ThenInclude(pr => pr!.UnidadBase)
            .Include(p => p.Detalle)
            .ThenInclude(d => d.Presentacion)
            .Include(p => p.Detalle)
            .ThenInclude(d => d.Movimiento)
            .Include(p => p.Detalle)
            .ThenInclude(d => d.MovimientosDevolucion)
            .ThenInclude(m => m.Documento)
            .ThenInclude(doc => doc!.Usuario)
            .Include(p => p.Detalle)
            .ThenInclude(d => d.MovimientosDevolucion)
            .ThenInclude(m => m.Documento)
            .ThenInclude(doc => doc!.Almacen)
            .Include(p => p.Detalle)
            .ThenInclude(d => d.MovimientosDevolucion)
            .ThenInclude(m => m.Presentacion);

    public async Task<Prestamo?> GetPrestamoAsync(int id) =>
        await PrestamosConDetalle().FirstOrDefaultAsync(p => p.Id == id);

    /// <summary>Una línea de préstamo con su préstamo y hermanas cargadas, para recalcular el estado al anular una devolución.</summary>
    public async Task<PrestamoDetalle?> GetPrestamoDetalleConPrestamoAsync(int id) =>
        await _context.PrestamoDetalles
            .Include(d => d.Producto)
            .Include(d => d.Prestamo).ThenInclude(p => p!.Detalle)
            .FirstOrDefaultAsync(d => d.Id == id);

    public async Task<IEnumerable<Prestamo>> GetPrestamosAsync() =>
        await PrestamosConDetalle()
            .OrderByDescending(p => p.Fecha)
            .ThenByDescending(p => p.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdatePrestamoAsync(Prestamo prestamo)
    {
        _context.Prestamos.Update(prestamo);
        await _context.SaveChangesAsync();
    }

    public async Task AddPrestamoDetalleAsync(PrestamoDetalle detalle) =>
        await _context.PrestamoDetalles.AddAsync(detalle);

    public async Task<PrestamoDetalle?> GetPrestamoDetalleAsync(int id) =>
        await _context.PrestamoDetalles
            .Include(d => d.Prestamo)
            .Include(d => d.Movimiento)
            .FirstOrDefaultAsync(d => d.Id == id);
}
