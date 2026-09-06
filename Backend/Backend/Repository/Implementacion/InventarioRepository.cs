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
    private IQueryable<DocumentoInventario> DocumentosDe(string? familia) =>
        DocumentosConDetalle()
            .Where(d => familia == null
                        || d.Tipo == familia
                        || (d.Tipo == TipoDocumentoInventario.Anulacion
                            && d.DocumentoAnulado!.Tipo == familia))
            .AsNoTracking();

    public async Task<(List<DocumentoInventario> Items, int Total)> ListarDocumentosAsync(
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

        return await query.PaginarAsync(consulta);
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

    public async Task<(List<Prestamo> Items, int Total)> ListarPrestamosAsync(ConsultaTablaRequest consulta)
    {
        var query = PrestamosConDetalle().AsNoTracking().AsQueryable();

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

        return await query.PaginarAsync(consulta);
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

    public async Task<(List<MovimientoInventario> Items, int Total, Dictionary<(int Producto, int Almacen), decimal> Aperturas)>
        ListarKardexAsync(ConsultaTablaRequest consulta, int? almacenId)
    {
        var query = KardexBase(almacenId)
            .Include(m => m.Documento)
            .Include(m => m.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(m => m.Motivo)
            .Include(m => m.Almacen)
            .Include(m => m.Presentacion)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(m =>
                (m.Producto != null && EF.Functions.Like(m.Producto.Nombre, $"%{texto}%"))
                || (m.Documento != null && EF.Functions.Like(m.Documento.Numero, $"%{texto}%"))
                || (m.Motivo != null && EF.Functions.Like(m.Motivo.Nombre, $"%{texto}%"))
                || (m.Almacen != null && EF.Functions.Like(m.Almacen.Nombre, $"%{texto}%")));
        }

        if (consulta.ValorDe("producto") is string producto)
        {
            query = query.Where(m => m.Producto != null && m.Producto.Nombre == producto);
        }

        if (consulta.ValorDe("motivo") is string motivo)
        {
            query = query.Where(m => m.Motivo != null && m.Motivo.Nombre == motivo);
        }

        if (consulta.ValorDe("tipo") is string tipo)
        {
            query = query.Where(m => m.Tipo == tipo);
        }

        if (consulta.ValorDe("almacen") is string almacen)
        {
            query = query.Where(m => m.Almacen != null && m.Almacen.Nombre == almacen);
        }

        if (consulta.ValorDe("documento") is string documento)
        {
            query = query.Where(m => m.Documento != null
                                     && EF.Functions.Like(m.Documento.Numero, $"%{documento}%"));
        }

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(m => m.Fecha >= desde);
        if (hasta is not null) query = query.Where(m => m.Fecha <= hasta);

        var total = await query.CountAsync();

        // El kardex es un libro cronologico: el unico orden que admite es por
        // fecha. Ordenar por otra columna partiria la pagina en un tramo no
        // contiguo y el saldo acumulado dejaria de tener sentido.
        var desc = string.Equals(consulta.Sentido, "desc", StringComparison.OrdinalIgnoreCase);
        query = desc
            ? query.OrderByDescending(m => m.Fecha).ThenByDescending(m => m.Id)
            : query.OrderBy(m => m.Fecha).ThenBy(m => m.Id);

        var items = await query
            .Skip((consulta.PaginaSegura - 1) * consulta.PorPaginaSegura)
            .Take(consulta.PorPaginaSegura)
            .ToListAsync();

        var aperturas = new Dictionary<(int, int), decimal>();
        if (items.Count > 0)
        {
            // Saldo con el que entra la pagina: todo lo anterior al movimiento
            // mas viejo que se va a mostrar, sumado por producto y almacen.
            var primera = items.OrderBy(m => m.Fecha).ThenBy(m => m.Id).First();

            var previos = await query
                .Where(m => m.Fecha < primera.Fecha
                            || (m.Fecha == primera.Fecha && m.Id < primera.Id))
                .GroupBy(m => new { m.ProductoId, m.AlmacenId })
                .Select(g => new
                {
                    g.Key.ProductoId,
                    g.Key.AlmacenId,
                    Saldo = g.Sum(m => m.Tipo == TipoMovimiento.Entrada ? m.Cantidad : -m.Cantidad),
                })
                .ToListAsync();

            foreach (var p in previos)
            {
                aperturas[(p.ProductoId, p.AlmacenId)] = p.Saldo;
            }
        }

        return (items, total, aperturas);
    }

    public async Task<(int Entradas, int Salidas)> ResumenKardexAsync(int? almacenId) => (
        await KardexBase(almacenId).CountAsync(m => m.Tipo == TipoMovimiento.Entrada),
        await KardexBase(almacenId).CountAsync(m => m.Tipo == TipoMovimiento.Salida));

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
            .ThenInclude(d => d.Movimiento);

    public async Task<Prestamo?> GetPrestamoAsync(int id) =>
        await PrestamosConDetalle().FirstOrDefaultAsync(p => p.Id == id);

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
