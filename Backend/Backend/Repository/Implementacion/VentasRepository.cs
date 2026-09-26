using System.Linq.Expressions;
using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Implementacion;

public class VentasRepository : IVentasRepository
{
    private readonly AppDbContext _context;

    public VentasRepository(AppDbContext context)
    {
        _context = context;
    }

    public Task<IDbContextTransaction> IniciarTransaccionAsync() =>
        _context.Database.BeginTransactionAsync();

    public Task GuardarAsync() => _context.SaveChangesAsync();

    // --------------------------------------------------------------- Pedidos

    public async Task<string> SiguienteNumeroPedidoAsync()
    {
        var ultimo = await _context.Pedidos
            .OrderByDescending(p => p.Id)
            .Select(p => p.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"PD-{correlativo:D4}";
    }

    public async Task<Pedido> AddPedidoAsync(Pedido pedido)
    {
        await _context.Pedidos.AddAsync(pedido);
        await _context.SaveChangesAsync();
        return pedido;
    }

    private IQueryable<Pedido> PedidosConDetalle() =>
        _context.Pedidos
            .Include(p => p.Cliente).ThenInclude(c => c!.Ruta)
            .Include(p => p.ListaPrecio)
            .Include(p => p.Almacen)
            .Include(p => p.Usuario)
            // Para saber si ya se convirtio, y a que venta.
            .Include(p => p.Ventas)
            .Include(p => p.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(p => p.Detalle).ThenInclude(d => d.Presentacion)
            // Ventas y líneas en consultas separadas: juntas se multiplicaban.
            .AsSplitQuery();


    /*
     * El recorte por alcance.
     *
     * Va aqui, dentro de la consulta, y no despues en memoria: filtrar las
     * filas ya paginadas daria paginas a medias y un total que no cuadra con
     * lo que se ve.
     *
     * "Mis clientes" incluye ADEMAS lo que registro la persona: si toma un
     * pedido de un cliente que no es suyo y no lo incluyera, lo perderia de
     * vista al guardarlo y no podria ni corregirlo ni anularlo.
     */
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

    public async Task<int?> RutaDeClienteAsync(int clienteId) =>
        await _context.Clientes.AsNoTracking().Where(c => c.Id == clienteId).Select(c => c.RutaId).FirstOrDefaultAsync();

    public async Task<Pedido?> GetPedidoAsync(int id, AlcanceFiltro? alcance = null) =>
        await Acotar(PedidosConDetalle(), alcance).FirstOrDefaultAsync(p => p.Id == id);

    public async Task<IEnumerable<Pedido>> GetPedidosAsync(string? estado = null, AlcanceFiltro? alcance = null) =>
        await Acotar(PedidosConDetalle(), alcance)
            .Where(p => estado == null || p.Estado == estado)
            .OrderByDescending(p => p.Fecha)
            .ThenByDescending(p => p.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdatePedidoAsync(Pedido pedido)
    {
        _context.Pedidos.Update(pedido);
        await _context.SaveChangesAsync();
    }

    public async Task<(List<PedidoFilaResponse> Items, int Total)> ListarPedidosAsync(
        ConsultaTablaRequest consulta, AlcanceFiltro? alcance = null)
    {
        // Sin Include: la fila se proyecta al final, sin líneas ni ventas.
        var query = Acotar(_context.Pedidos.AsNoTracking(), alcance);

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(p =>
                EF.Functions.Like(p.Numero, $"%{texto}%")
                || (p.Cliente != null && EF.Functions.Like(p.Cliente.Nombre, $"%{texto}%"))
                || (p.Cliente != null && EF.Functions.Like(p.Cliente.Documento, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
        {
            query = query.Where(p => EF.Functions.Like(p.Numero, $"%{numero}%"));
        }

        if (consulta.ValorDe("cliente") is string cliente)
        {
            query = query.Where(p => p.Cliente != null && EF.Functions.Like(p.Cliente.Nombre, $"%{cliente}%"));
        }

        if (consulta.ValorDe("estado") is string estado)
        {
            query = query.Where(p => p.Estado == estado);
        }

        // La ruta y el dia de visita son del CLIENTE del pedido: es lo que separa el reparto de un dia.
        if (consulta.ValorDe("ruta") is string ruta)
        {
            query = query.Where(p => p.Cliente != null && p.Cliente.Ruta != null && p.Cliente.Ruta.Nombre == ruta);
        }

        if (consulta.ValorDe("diaVisita") is string diaVisita)
        {
            var dia = DiaSemana.Normalizar(diaVisita);
            query = query.Where(p => p.Cliente != null && p.Cliente.DiaVisita == dia);
        }

        // El filtro viaja con el nombre de la columna: "notaVentaNumero".
        // No importa cuál, solo si ya nació una venta vigente de este pedido.
        if (consulta.ValorDe("notaVentaNumero") is string convertido)
        {
            query = convertido.Equals("Convertido", StringComparison.OrdinalIgnoreCase)
                ? query.Where(p => p.Ventas.Any(v => v.Estado != EstadoNotaVenta.Anulada))
                : query.Where(p => !p.Ventas.Any(v => v.Estado != EstadoNotaVenta.Anulada));
        }

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(p => p.Fecha >= desde);
        if (hasta is not null) query = query.Where(p => p.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc
                ? query.OrderByDescending(p => p.Numero).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Numero).ThenBy(p => p.Id),
            "cliente" => desc
                ? query.OrderByDescending(p => p.Cliente!.Nombre).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Cliente!.Nombre).ThenBy(p => p.Id),
            "estado" => desc
                ? query.OrderByDescending(p => p.Estado).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Estado).ThenBy(p => p.Id),
            // El total no es una columna: se suma del detalle, sin las lineas
            // anuladas, igual que lo hace la respuesta.
            "total" => desc
                ? query.OrderByDescending(p => p.Detalle.Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario)).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Detalle.Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario)).ThenBy(p => p.Id),
            _ => desc
                ? query.OrderByDescending(p => p.Fecha).ThenByDescending(p => p.Id)
                : query.OrderBy(p => p.Fecha).ThenBy(p => p.Id),
        };

        var pagina = await query.Select(p => new PedidoFilaResponse
            {
                Id = p.Id,
                Numero = p.Numero,
                ClienteId = p.ClienteId,
                Cliente = p.Cliente != null ? p.Cliente.Nombre : string.Empty,
                Ruta = p.Cliente != null && p.Cliente.Ruta != null ? p.Cliente.Ruta.Nombre : null,
                DiaVisita = p.Cliente != null ? p.Cliente.DiaVisita : null,
                Fecha = p.Fecha,
                Estado = p.Estado,
                CondicionPago = p.CondicionPago,
                Usuario = p.Usuario != null ? p.Usuario.Nombre : null,
                ReservaStock = p.ReservaStock,
                AlmacenId = p.AlmacenId,
                Almacen = p.Almacen != null ? p.Almacen.Nombre : null,
                // La venta vigente: la que no se anuló. Una subconsulta, no todas las ventas.
                NotaVentaId = p.Ventas.Where(v => v.Estado != EstadoNotaVenta.Anulada).Select(v => (int?)v.Id).FirstOrDefault(),
                NotaVentaNumero = p.Ventas.Where(v => v.Estado != EstadoNotaVenta.Anulada).Select(v => v.Numero).FirstOrDefault(),
                Total = p.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion),
            })
            .PaginarAsync(consulta);

        foreach (var f in pagina.Items) f.Total = Math.Round(f.Total, 2);
        return pagina;
    }

    // Los contadores se acotan igual que la lista: si no, arriba diria "40
    // pedidos" y abajo se verian tres, y el numero pareceria un error.
    public async Task<ResumenPedidosResponse> ResumenPedidosAsync(AlcanceFiltro? alcance = null)
    {
        var pedidos = Acotar(_context.Pedidos.AsNoTracking(), alcance);

        return new ResumenPedidosResponse
        {
            Total = await pedidos.CountAsync(),
            Pendientes = await pedidos.CountAsync(p => p.Estado == EstadoPedido.Pendiente),
            Confirmados = await pedidos.CountAsync(p => p.Estado == EstadoPedido.Confirmado),
        };
    }

    /// <summary>
    /// Actualiza línea por línea en vez de borrar todo y recrearlo: así una
    /// edición de cantidad queda en la auditoría como "cantidad: 2 → 5" sobre
    /// la misma fila, no como un ELIMINADO + CREADO. Una línea que ya no
    /// viene en la lista nueva tampoco se borra — queda Anulada, para no
    /// perder su historial (regla del negocio: nunca se elimina, se anula).
    /// </summary>
    public async Task ReemplazarDetallePedidoAsync(int pedidoId, IEnumerable<PedidoDetalle> detalle)
    {
        var actuales = await _context.PedidoDetalles
            .Where(d => d.PedidoId == pedidoId)
            .ToListAsync();
        var actualesPorId = actuales.ToDictionary(d => d.Id);

        var conservadas = new HashSet<int>();

        foreach (var linea in detalle)
        {
            if (linea.Id > 0 && actualesPorId.TryGetValue(linea.Id, out var existente))
            {
                existente.ProductoId = linea.ProductoId;
                existente.PresentacionId = linea.PresentacionId;
                existente.CantidadPresentacion = linea.CantidadPresentacion;
                existente.Cantidad = linea.Cantidad;
                existente.PrecioUnitario = linea.PrecioUnitario;
                existente.Anulado = linea.Anulado;
                conservadas.Add(existente.Id);
            }
            else
            {
                linea.PedidoId = pedidoId;
                linea.Id = 0;
                await _context.PedidoDetalles.AddAsync(linea);
            }
        }

        foreach (var quitada in actuales.Where(d => !conservadas.Contains(d.Id)))
        {
            quitada.Anulado = true;
        }

        await _context.SaveChangesAsync();
    }

    public async Task<Dictionary<int, decimal>> GetReservadoPorProductoAsync(
        int? almacenId, IEnumerable<int>? productoIds = null)
    {
        var ids = productoIds?.ToList();
        return await _context.PedidoDetalles
            .Where(d => d.Pedido!.Estado == EstadoPedido.Pendiente
                        && d.Pedido.ReservaStock
                        && !d.Anulado
                        && (almacenId == null || d.Pedido.AlmacenId == almacenId)
                        && (ids == null || ids.Contains(d.ProductoId)))
            .GroupBy(d => d.ProductoId)
            .Select(g => new { ProductoId = g.Key, Cantidad = g.Sum(d => d.Cantidad) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Cantidad);
    }

    // ---------------------------------------------------------- Notas de venta

    public async Task<string> SiguienteNumeroNotaVentaAsync()
    {
        var ultimo = await _context.NotasVenta
            .OrderByDescending(n => n.Id)
            .Select(n => n.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n))
        {
            correlativo = n + 1;
        }

        return $"NV-{correlativo:D4}";
    }

    public async Task<NotaVenta> AddNotaVentaAsync(NotaVenta notaVenta)
    {
        await _context.NotasVenta.AddAsync(notaVenta);
        await _context.SaveChangesAsync();
        return notaVenta;
    }

    private IQueryable<NotaVenta> NotasVentaConDetalle() =>
        _context.NotasVenta
            .Include(n => n.Cliente).ThenInclude(c => c!.Ruta)
            .Include(n => n.Cliente).ThenInclude(c => c!.Mercado)
            .Include(n => n.Pedido)
            .Include(n => n.Almacen)
            .Include(n => n.Usuario)
            .Include(n => n.Pagos).ThenInclude(p => p.MetodoPago)
            .Include(n => n.Devoluciones).ThenInclude(d => d.Usuario)
            .Include(n => n.Devoluciones).ThenInclude(d => d.AprobadoPor)
            .Include(n => n.Devoluciones).ThenInclude(d => d.Detalle)
                .ThenInclude(l => l.NotaVentaDetalle!).ThenInclude(v => v.Producto!)
                .ThenInclude(p => p.UnidadBase)
            .Include(n => n.Devoluciones).ThenInclude(d => d.Detalle)
                .ThenInclude(l => l.NotaVentaDetalle!).ThenInclude(v => v.Presentacion)
            .Include(n => n.Pagos).ThenInclude(p => p.Usuario)
            .Include(n => n.Detalle).ThenInclude(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(n => n.Detalle).ThenInclude(d => d.Presentacion)
            .Include(n => n.Recojos).ThenInclude(r => r.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(n => n.Recojos).ThenInclude(r => r.Presentacion)
            .Include(n => n.Recojos).ThenInclude(r => r.Almacen)
            .Include(n => n.Recojos).ThenInclude(r => r.Motivo)
            .Include(n => n.Recojos).ThenInclude(r => r.Usuario)
            // Cuatro colecciones (detalle, pagos, devoluciones, recojos): en una
            // sola consulta se multiplicaban entre sí. Así va una por colección.
            .AsSplitQuery();

    public async Task<NotaVenta?> GetNotaVentaAsync(int id, AlcanceFiltro? alcance = null) =>
        await Acotar(NotasVentaConDetalle(), alcance).FirstOrDefaultAsync(n => n.Id == id);

    public async Task<IEnumerable<NotaVenta>> GetNotasVentaAsync(string? estado = null, AlcanceFiltro? alcance = null) =>
        await Acotar(NotasVentaConDetalle(), alcance)
            .Where(n => estado == null || n.Estado == estado)
            .OrderByDescending(n => n.Fecha)
            .ThenByDescending(n => n.Id)
            .Take(300)
            .ToListAsync();

    public async Task UpdateNotaVentaAsync(NotaVenta notaVenta)
    {
        _context.NotasVenta.Update(notaVenta);
        await _context.SaveChangesAsync();
    }

    public async Task<(List<NotaVentaFilaResponse> Items, int Total)> ListarNotasVentaAsync(
        ConsultaTablaRequest consulta, AlcanceFiltro? alcance = null)
    {
        // Sin Include: la fila se proyecta al final, así la base lee solo las
        // columnas que muestra la tabla y no el detalle, pagos ni devoluciones.
        var query = Acotar(_context.NotasVenta.AsNoTracking(), alcance);

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(n =>
                EF.Functions.Like(n.Numero, $"%{texto}%")
                || (n.Cliente != null && EF.Functions.Like(n.Cliente.Nombre, $"%{texto}%"))
                || (n.Cliente != null && EF.Functions.Like(n.Cliente.Documento, $"%{texto}%"))
                || (n.Pedido != null && EF.Functions.Like(n.Pedido.Numero, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
        {
            query = query.Where(n => EF.Functions.Like(n.Numero, $"%{numero}%"));
        }

        if (consulta.ValorDe("cliente") is string cliente)
        {
            query = query.Where(n => n.Cliente != null && EF.Functions.Like(n.Cliente.Nombre, $"%{cliente}%"));
        }

        if (consulta.ValorDe("estado") is string estado)
        {
            query = query.Where(n => n.Estado == estado);
        }

        if (consulta.ValorDe("formaPago") is string formaPago)
        {
            query = query.Where(n => n.FormaPago == formaPago);
        }

        if (consulta.ValorDe("usuario") is string usuario)
        {
            query = query.Where(n => n.Usuario != null && n.Usuario.Nombre == usuario);
        }

        // El filtro viaja con el nombre de la columna: "pedidoNumero".
        // "Directa" es la que no viene de confirmar un pedido.
        if (consulta.ValorDe("pedidoNumero") is string origen)
        {
            query = origen.Equals("Directa", StringComparison.OrdinalIgnoreCase)
                ? query.Where(n => n.PedidoId == null)
                : query.Where(n => n.PedidoId != null);
        }

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(n => n.Fecha >= desde);
        if (hasta is not null) query = query.Where(n => n.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc
                ? query.OrderByDescending(n => n.Numero).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Numero).ThenBy(n => n.Id),
            "cliente" => desc
                ? query.OrderByDescending(n => n.Cliente!.Nombre).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Cliente!.Nombre).ThenBy(n => n.Id),
            "estado" => desc
                ? query.OrderByDescending(n => n.Estado).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Estado).ThenBy(n => n.Id),
            "total" => desc
                ? query.OrderByDescending(n => n.Detalle.Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario)).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Detalle.Where(d => !d.Anulado)
                        .Sum(d => d.Cantidad * d.PrecioUnitario)).ThenBy(n => n.Id),
            _ => desc
                ? query.OrderByDescending(n => n.Fecha).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Fecha).ThenBy(n => n.Id),
        };

        return Redondear(await query.Select(AFila).PaginarAsync(consulta));
    }

    /// <summary>
    /// La fila de un listado de notas, resuelta por la base: las sumas van como
    /// subconsultas, así no viaja ni una línea de detalle.
    /// </summary>
    private static readonly Expression<Func<NotaVenta, NotaVentaFilaResponse>> AFila = n => new NotaVentaFilaResponse
    {
        Id = n.Id,
        Numero = n.Numero,
        ClienteId = n.ClienteId,
        Cliente = n.Cliente != null ? n.Cliente.Nombre : string.Empty,
        Ruta = n.Cliente != null && n.Cliente.Ruta != null ? n.Cliente.Ruta.Nombre : null,
        Mercado = n.Cliente != null && n.Cliente.Mercado != null ? n.Cliente.Mercado.Nombre : null,
        PedidoId = n.PedidoId,
        PedidoNumero = n.Pedido != null ? n.Pedido.Numero : null,
        Fecha = n.Fecha,
        Estado = n.Estado,
        FormaPago = n.FormaPago,
        Usuario = n.Usuario != null ? n.Usuario.Nombre : null,
        Total = n.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion)
                - n.Recojos.Where(r => r.Estado != EstadoRecojo.Anulado).Sum(r => r.Importe),
        TotalPagado = n.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto),
    };

    private static (List<NotaVentaFilaResponse> Items, int Total) Redondear(
        (List<NotaVentaFilaResponse> Items, int Total) pagina)
    {
        foreach (var f in pagina.Items)
        {
            f.Total = Math.Round(f.Total, 2);
            f.TotalPagado = Math.Round(f.TotalPagado, 2);
        }
        return pagina;
    }

    public async Task<ResumenNotasVentaResponse> ResumenNotasVentaAsync(AlcanceFiltro? alcance = null)
    {
        var notas = Acotar(_context.NotasVenta.AsNoTracking(), alcance);
        var confirmadas = notas.Where(n => n.Estado == EstadoNotaVenta.Confirmada);

        return new ResumenNotasVentaResponse
        {
            Total = await notas.CountAsync(),
            Confirmadas = await confirmadas.CountAsync(),
            TotalVendido = await confirmadas
                .SelectMany(n => n.Detalle)
                .Where(d => !d.Anulado)
                .SumAsync(d => (decimal?)(d.Cantidad * d.PrecioUnitario)) ?? 0m,
            Vendedores = await notas
                .Where(n => n.Usuario != null)
                .Select(n => n.Usuario!.Nombre)
                .Distinct()
                .OrderBy(v => v)
                .ToListAsync(),
        };
    }

    /*
     * Las notas a credito que todavia deben algo.
     *
     * El saldo NO es una columna: es la suma del detalle vigente menos la de
     * los pagos no anulados. Se expresa como subconsultas para que el filtro
     * "debe algo" lo resuelva la base y no haya que traerse todo.
     */
    private IQueryable<NotaVenta> CuentasPorCobrarBase() =>
        _context.NotasVenta
            // El detalle ya trae descontado lo devuelto: al aprobar una
            // devolucion se le baja la cantidad a la linea, asi que restarlo
            // otra vez aqui seria restarlo dos veces.
            // Con la misma cuenta que el total de la nota: líneas menos recojos,
            // redondeado a centavos. Sin el redondeo, una nota pagada exacta
            // seguía "debiendo" fracciones de céntimo; sin restar los recojos,
            // seguía debiendo lo que el cliente devolvió al recoger.
            .Where(n => n.Estado == EstadoNotaVenta.Confirmada
                        && n.FormaPago == FormaPagoVenta.Credito
                        && Math.Round(n.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion)
                                      - n.Recojos.Where(r => r.Estado != EstadoRecojo.Anulado).Sum(r => r.Importe), 2)
                           > n.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto))
            .AsNoTracking();

    public async Task<(List<NotaVentaFilaResponse> Items, int Total)> ListarCuentasPorCobrarAsync(
        ConsultaTablaRequest consulta)
    {
        var query = CuentasPorCobrarBase();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(n =>
                EF.Functions.Like(n.Numero, $"%{texto}%")
                || (n.Cliente != null && EF.Functions.Like(n.Cliente.Nombre, $"%{texto}%"))
                || (n.Cliente != null && EF.Functions.Like(n.Cliente.Documento, $"%{texto}%")));
        }

        if (consulta.ValorDe("numero") is string numero)
            query = query.Where(n => EF.Functions.Like(n.Numero, $"%{numero}%"));

        if (consulta.ValorDe("cliente") is string cliente)
            query = query.Where(n => n.Cliente != null && EF.Functions.Like(n.Cliente.Nombre, $"%{cliente}%"));

        // La ruta y el mercado son del CLIENTE de la venta, igual que en Pedidos.
        if (consulta.ValorDe("ruta") is string ruta)
            query = query.Where(n => n.Cliente != null && n.Cliente.Ruta != null && n.Cliente.Ruta.Nombre == ruta);

        if (consulta.ValorDe("mercado") is string mercado)
            query = query.Where(n => n.Cliente != null && n.Cliente.Mercado != null && n.Cliente.Mercado.Nombre == mercado);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(n => n.Fecha >= desde);
        if (hasta is not null) query = query.Where(n => n.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "numero" => desc ? query.OrderByDescending(n => n.Numero).ThenByDescending(n => n.Id)
                             : query.OrderBy(n => n.Numero).ThenBy(n => n.Id),
            "cliente" => desc ? query.OrderByDescending(n => n.Cliente!.Nombre).ThenByDescending(n => n.Id)
                              : query.OrderBy(n => n.Cliente!.Nombre).ThenBy(n => n.Id),
            "saldo" => desc
                ? query.OrderByDescending(n => n.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion)
                        - n.Recojos.Where(r => r.Estado != EstadoRecojo.Anulado).Sum(r => r.Importe)
                        - n.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto)).ThenByDescending(n => n.Id)
                : query.OrderBy(n => n.Detalle.Where(d => !d.Anulado).Sum(d => d.CantidadPresentacion * d.PrecioPresentacion)
                        - n.Recojos.Where(r => r.Estado != EstadoRecojo.Anulado).Sum(r => r.Importe)
                        - n.Pagos.Where(p => !p.Anulado).Sum(p => p.Monto)).ThenBy(n => n.Id),
            // Por defecto la mas vieja primero: es la que lleva mas tiempo sin cobrarse.
            _ => desc ? query.OrderByDescending(n => n.Fecha).ThenByDescending(n => n.Id)
                      : query.OrderBy(n => n.Fecha).ThenBy(n => n.Id),
        };

        return Redondear(await query.Select(AFila).PaginarAsync(consulta));
    }

    public async Task<ResumenCuentasResponse> ResumenCuentasPorCobrarAsync()
    {
        // Una fila por cuenta abierta, con los totales ya como en la tabla: así
        // el resumen suma lo mismo que se ve, centavo por centavo.
        var cuentas = await CuentasPorCobrarBase().Select(AFila).ToListAsync();
        var facturado = cuentas.Sum(c => Math.Round(c.Total, 2));
        var cubierto = cuentas.Sum(c => Math.Round(c.TotalPagado, 2));

        return new ResumenCuentasResponse
        {
            Cuentas = cuentas.Count,
            TotalFacturado = facturado,
            TotalCubierto = cubierto,
            TotalPendiente = facturado - cubierto,
        };
    }

    public async Task<NotaVentaDetalle?> GetNotaVentaDetalleConNotaVentaAsync(int id) =>
        await _context.NotaVentaDetalles
            .Include(d => d.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(d => d.NotaVenta)
            .FirstOrDefaultAsync(d => d.Id == id);

    public async Task<RecojoVenta?> GetRecojoConNotaVentaAsync(int id) =>
        await _context.RecojosVenta
            .Include(r => r.Producto)
            .Include(r => r.NotaVenta)
            .FirstOrDefaultAsync(r => r.Id == id);

    public async Task<List<RecojoVenta>> GetRecojosPendientesAsync() =>
        await _context.RecojosVenta
            .AsNoTracking()
            .Where(r => r.Estado == EstadoRecojo.Pendiente)
            .Include(r => r.Producto).ThenInclude(p => p!.UnidadBase)
            .Include(r => r.Presentacion)
            .Include(r => r.Motivo)
            .Include(r => r.Usuario)
            .Include(r => r.NotaVenta).ThenInclude(n => n!.Cliente)
            .OrderBy(r => r.Fecha)
            .ToListAsync();

    public async Task ReemplazarDetalleNotaVentaAsync(int notaVentaId, IEnumerable<NotaVentaDetalle> detalle)
    {
        var actuales = await _context.NotaVentaDetalles
            .Where(d => d.NotaVentaId == notaVentaId)
            .ToListAsync();
        var actualesPorId = actuales.ToDictionary(d => d.Id);

        var conservadas = new HashSet<int>();

        foreach (var linea in detalle)
        {
            if (linea.Id > 0 && actualesPorId.TryGetValue(linea.Id, out var existente))
            {
                existente.ProductoId = linea.ProductoId;
                existente.PresentacionId = linea.PresentacionId;
                existente.CantidadPresentacion = linea.CantidadPresentacion;
                existente.Cantidad = linea.Cantidad;
                existente.PrecioUnitario = linea.PrecioUnitario;
                existente.Anulado = linea.Anulado;
                conservadas.Add(existente.Id);
            }
            else
            {
                linea.NotaVentaId = notaVentaId;
                linea.Id = 0;
                await _context.NotaVentaDetalles.AddAsync(linea);
            }
        }

        foreach (var quitada in actuales.Where(d => !conservadas.Contains(d.Id)))
        {
            quitada.Anulado = true;
        }

        await _context.SaveChangesAsync();
    }
}
