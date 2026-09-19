using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class NovedadService : INovedadService
{
    private readonly AppDbContext _context;
    private readonly INotificador _notificador;

    public NovedadService(AppDbContext context, INotificador notificador)
    {
        _context = context;
        _notificador = notificador;
    }

    // ------------------------------------------------------------------
    // Motivos
    // ------------------------------------------------------------------

    public async Task<IEnumerable<MotivoNovedadResponse>> GetMotivosAsync() =>
        await _context.MotivosNovedad
            .AsNoTracking()
            .OrderByDescending(m => m.Activo)
            .ThenBy(m => m.Nombre)
            .Select(m => new MotivoNovedadResponse
            {
                Id = m.Id,
                Nombre = m.Nombre,
                Descripcion = m.Descripcion,
                RegresaAlAlmacen = m.RegresaAlAlmacen,
                Activo = m.Activo,
                Usos = _context.NovedadesEntrega.Count(n => n.MotivoId == m.Id),
            })
            .ToListAsync();

    public async Task<IEnumerable<MotivoNovedadOpcionResponse>> GetOpcionesAsync() =>
        await _context.MotivosNovedad
            .AsNoTracking()
            .Where(m => m.Activo)
            .OrderBy(m => m.Nombre)
            .Select(m => new MotivoNovedadOpcionResponse
            {
                Id = m.Id,
                Nombre = m.Nombre,
                Descripcion = m.Descripcion,
            })
            .ToListAsync();

    public async Task<MotivoNovedadResponse> CrearMotivoAsync(MotivoNovedadRequest request)
    {
        var nombre = Exigir(request.Nombre, "Ponle un nombre al motivo");

        if (await _context.MotivosNovedad.AnyAsync(m => m.Nombre == nombre))
            throw new ConflictException("Ya existe un motivo con ese nombre");

        var motivo = new MotivoNovedad
        {
            Nombre = nombre,
            Descripcion = Limpiar(request.Descripcion),
            RegresaAlAlmacen = request.RegresaAlAlmacen,
            Activo = request.Activo,
        };

        _context.MotivosNovedad.Add(motivo);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "motivoCreado", new { motivo.Id });

        return (await GetMotivosAsync()).First(m => m.Id == motivo.Id);
    }

    public async Task<MotivoNovedadResponse> ActualizarMotivoAsync(int id, MotivoNovedadRequest request)
    {
        var motivo = await _context.MotivosNovedad.FirstOrDefaultAsync(m => m.Id == id)
            ?? throw new NotFoundException("Motivo no encontrado");

        var nombre = Exigir(request.Nombre, "Ponle un nombre al motivo");

        if (await _context.MotivosNovedad.AnyAsync(m => m.Nombre == nombre && m.Id != id))
            throw new ConflictException("Ya existe un motivo con ese nombre");

        motivo.Nombre = nombre;
        motivo.Descripcion = Limpiar(request.Descripcion);
        motivo.RegresaAlAlmacen = request.RegresaAlAlmacen;
        motivo.Activo = request.Activo;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "motivoActualizado", new { motivo.Id });

        return (await GetMotivosAsync()).First(m => m.Id == id);
    }

    // ------------------------------------------------------------------
    // Listado y revisión
    // ------------------------------------------------------------------

    public async Task<PaginaResponse<NovedadResponse>> ListarAsync(ConsultaTablaRequest consulta)
    {
        var query = _context.NovedadesEntrega.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(consulta.Buscar))
        {
            var texto = consulta.Buscar.Trim();
            query = query.Where(n =>
                EF.Functions.Like(n.Producto!.Nombre, $"%{texto}%")
                || EF.Functions.Like(n.Producto!.Codigo, $"%{texto}%")
                || EF.Functions.Like(n.Pedido!.Numero, $"%{texto}%")
                || EF.Functions.Like(n.Pedido!.Cliente!.Nombre, $"%{texto}%")
                || EF.Functions.Like(n.Motivo!.Nombre, $"%{texto}%")
                || (n.Despacho != null && EF.Functions.Like(n.Despacho.Numero, $"%{texto}%")));
        }

        if (consulta.ValorDe("pedido") is string pedido)
            query = query.Where(n => EF.Functions.Like(n.Pedido!.Numero, $"%{pedido}%"));

        if (consulta.ValorDe("cliente") is string cliente)
            query = query.Where(n => EF.Functions.Like(n.Pedido!.Cliente!.Nombre, $"%{cliente}%"));

        if (consulta.ValorDe("despacho") is string despacho)
            query = query.Where(n => n.Despacho != null && EF.Functions.Like(n.Despacho.Numero, $"%{despacho}%"));

        if (consulta.ValorDe("producto") is string producto)
            query = query.Where(n => EF.Functions.Like(n.Producto!.Nombre, $"%{producto}%")
                                     || EF.Functions.Like(n.Producto!.Codigo, $"%{producto}%"));

        if (consulta.ValorDe("motivo") is string motivo)
            query = query.Where(n => n.Motivo!.Nombre == motivo);

        if (consulta.ValorDe("tipo") is string tipo)
            query = query.Where(n => n.Tipo == tipo);

        // Las anuladas no cuentan: solo salen si se piden expresamente.
        if (consulta.ValorDe("estado") is string estado)
            query = query.Where(n => n.Estado == estado);
        else
            query = query.Where(n => n.Estado != EstadoNovedad.Anulada);

        var (desde, hasta) = consulta.RangoFechas("fecha");
        if (desde is not null) query = query.Where(n => n.Fecha >= desde);
        if (hasta is not null) query = query.Where(n => n.Fecha <= hasta);

        var desc = !string.Equals(consulta.Sentido, "asc", StringComparison.OrdinalIgnoreCase);

        query = consulta.Orden switch
        {
            "pedido" => desc ? query.OrderByDescending(n => n.Pedido!.Numero).ThenByDescending(n => n.Id)
                             : query.OrderBy(n => n.Pedido!.Numero).ThenBy(n => n.Id),
            "cliente" => desc ? query.OrderByDescending(n => n.Pedido!.Cliente!.Nombre).ThenByDescending(n => n.Id)
                              : query.OrderBy(n => n.Pedido!.Cliente!.Nombre).ThenBy(n => n.Id),
            "producto" => desc ? query.OrderByDescending(n => n.Producto!.Nombre).ThenByDescending(n => n.Id)
                               : query.OrderBy(n => n.Producto!.Nombre).ThenBy(n => n.Id),
            "motivo" => desc ? query.OrderByDescending(n => n.Motivo!.Nombre).ThenByDescending(n => n.Id)
                             : query.OrderBy(n => n.Motivo!.Nombre).ThenBy(n => n.Id),
            "estado" => desc ? query.OrderByDescending(n => n.Estado).ThenByDescending(n => n.Id)
                             : query.OrderBy(n => n.Estado).ThenBy(n => n.Id),
            "importe" => desc ? query.OrderByDescending(n => n.Importe).ThenByDescending(n => n.Id)
                              : query.OrderBy(n => n.Importe).ThenBy(n => n.Id),
            _ => desc ? query.OrderByDescending(n => n.Fecha).ThenByDescending(n => n.Id)
                      : query.OrderBy(n => n.Fecha).ThenBy(n => n.Id),
        };

        var (items, total) = await Proyectar(query).PaginarAsync(consulta);

        return new PaginaResponse<NovedadResponse>
        {
            Items = items,
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    private static IQueryable<NovedadResponse> Proyectar(IQueryable<NovedadEntrega> query) =>
        query.Select(n => new NovedadResponse
        {
            Id = n.Id,
            Tipo = n.Tipo,
            Fecha = n.Fecha,
            Estado = n.Estado,
            PedidoId = n.PedidoId,
            Pedido = n.Pedido!.Numero,
            Cliente = n.Pedido.Cliente!.Nombre,
            DespachoId = n.DespachoId,
            Despacho = n.Despacho != null ? n.Despacho.Numero : null,
            NotaVentaId = n.NotaVentaId,
            NotaVenta = n.NotaVenta != null ? n.NotaVenta.Numero : null,
            ProductoId = n.ProductoId,
            Codigo = n.Producto!.Codigo,
            Producto = n.Producto.Nombre,
            Presentacion = n.Presentacion != null ? n.Presentacion.Nombre : null,
            Factor = n.Presentacion != null ? n.Presentacion.Factor : 1,
            UnidadBase = n.Producto.UnidadBase != null ? n.Producto.UnidadBase.Codigo : string.Empty,
            CantidadPedida = n.CantidadPedida,
            CantidadEntregada = n.CantidadEntregada,
            CantidadNoEntregada = n.CantidadPedida - n.CantidadEntregada,
            Importe = n.Importe,
            MotivoId = n.MotivoId,
            Motivo = n.Motivo!.Nombre,
            RegresaAlAlmacen = n.Motivo.RegresaAlAlmacen,
            Observacion = n.Observacion,
            Usuario = n.Usuario != null ? n.Usuario.Nombre : null,
            CantidadRegresada = n.CantidadRegresada,
            VerificadoPor = n.VerificadoPor != null ? n.VerificadoPor.Nombre : null,
            VerificadoEn = n.VerificadoEn,
            ObservacionVerificacion = n.ObservacionVerificacion,
        });

    private async Task<NovedadResponse> UnaAsync(int id) =>
        await Proyectar(_context.NovedadesEntrega.AsNoTracking().Where(n => n.Id == id)).FirstOrDefaultAsync()
        ?? throw new NotFoundException("Novedad no encontrada");

    public async Task<ResumenNovedadesResponse> ResumenAsync()
    {
        var vigentes = _context.NovedadesEntrega.Where(n => n.Estado != EstadoNovedad.Anulada);

        return new ResumenNovedadesResponse
        {
            Total = await vigentes.CountAsync(),
            PorRevisar = await vigentes.CountAsync(n => n.Estado == EstadoNovedad.Pendiente),
            Recibidas = await vigentes.CountAsync(n => n.Estado == EstadoNovedad.Recibida),
            Faltantes = await vigentes.CountAsync(n => n.Estado == EstadoNovedad.Faltante),
            Importe = await vigentes.SumAsync(n => (decimal?)n.Importe) ?? 0,
        };
    }

    public async Task<NovedadResponse> VerificarAsync(int id, VerificarNovedadRequest request, int? usuarioId)
    {
        var novedad = await _context.NovedadesEntrega.FirstOrDefaultAsync(n => n.Id == id)
            ?? throw new NotFoundException("Novedad no encontrada");

        if (novedad.Estado != EstadoNovedad.Pendiente)
        {
            throw new BadRequestException(novedad.Estado switch
            {
                EstadoNovedad.Anulada => "Esta novedad está anulada: ya no se revisa.",
                EstadoNovedad.SinRetorno => "Esa mercadería nunca salió del almacén: no hay nada que contar.",
                _ => "Esta novedad ya se revisó. Ábrela de nuevo si quieres corregirla.",
            });
        }

        var noEntregada = novedad.CantidadNoEntregada;

        switch (request.Estado)
        {
            case EstadoNovedad.Recibida:
                // Volvió todo lo que no se entregó.
                novedad.CantidadRegresada = noEntregada;
                break;

            case EstadoNovedad.Faltante:
                var regresada = Math.Round(request.CantidadRegresada ?? 0, 4);
                if (regresada < 0 || regresada >= noEntregada)
                {
                    throw new BadRequestException(
                        "Lo que volvió tiene que ser menos de lo que no se entregó. Si volvió todo, márcala como recibida.");
                }
                novedad.CantidadRegresada = regresada;
                break;

            default:
                throw new BadRequestException("Elige si la mercadería volvió (RECIBIDA) o faltó (FALTANTE).");
        }

        novedad.Estado = request.Estado;
        novedad.VerificadoPorId = usuarioId;
        novedad.VerificadoEn = DateTime.UtcNow;
        novedad.ObservacionVerificacion = Limpiar(request.Observacion);

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "verificada", new { novedad.Id });

        return await UnaAsync(id);
    }

    public async Task<NovedadResponse> ReabrirAsync(int id)
    {
        var novedad = await _context.NovedadesEntrega.FirstOrDefaultAsync(n => n.Id == id)
            ?? throw new NotFoundException("Novedad no encontrada");

        if (novedad.Estado is not (EstadoNovedad.Recibida or EstadoNovedad.Faltante))
            throw new BadRequestException("Solo se puede reabrir una novedad ya revisada.");

        novedad.Estado = EstadoNovedad.Pendiente;
        novedad.CantidadRegresada = null;
        novedad.VerificadoPorId = null;
        novedad.VerificadoEn = null;
        novedad.ObservacionVerificacion = null;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "reabierta", new { novedad.Id });

        return await UnaAsync(id);
    }

    // ------------------------------------------------------------------
    // Registro
    // ------------------------------------------------------------------

    public async Task<Dictionary<int, MotivoNovedad>> ExigirMotivosAsync(IEnumerable<int> ids)
    {
        var pedidos = ids.Distinct().ToList();
        var motivos = await _context.MotivosNovedad
            .Where(m => pedidos.Contains(m.Id))
            .ToDictionaryAsync(m => m.Id);

        foreach (var id in pedidos)
        {
            if (!motivos.TryGetValue(id, out var motivo))
                throw new BadRequestException("El motivo elegido ya no existe.");

            if (!motivo.Activo)
                throw new BadRequestException($"El motivo \"{motivo.Nombre}\" está desactivado. Elige otro.");
        }

        return motivos;
    }

    public async Task RegistrarLineasAsync(
        Pedido pedido, int notaVentaId, IReadOnlyList<CambioEntrega> cambios,
        IReadOnlyDictionary<int, MotivoNovedad> motivos, int? usuarioId)
    {
        if (cambios.Count == 0) return;

        var despachoId = await DespachoVigenteAsync(pedido.Id);
        var ahora = DateTime.UtcNow;

        foreach (var cambio in cambios)
        {
            var linea = cambio.Linea;
            _context.NovedadesEntrega.Add(new NovedadEntrega
            {
                Tipo = TipoNovedad.Linea,
                PedidoId = pedido.Id,
                PedidoDetalleId = linea.Id,
                NotaVentaId = notaVentaId,
                DespachoId = despachoId,
                ProductoId = linea.ProductoId,
                PresentacionId = linea.PresentacionId,
                CantidadPedida = linea.Cantidad,
                CantidadEntregada = cambio.Entregada,
                Importe = cambio.Importe,
                MotivoId = cambio.MotivoId,
                Observacion = Limpiar(cambio.Observacion),
                UsuarioId = usuarioId,
                Fecha = ahora,
                Estado = EstadoInicial(motivos[cambio.MotivoId]),
            });
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "registradas", new { PedidoId = pedido.Id, despachoId });
    }

    public async Task RegistrarNoEntregadoAsync(
        Pedido pedido, MotivoNovedad motivo, string? observacion, int? usuarioId)
    {
        var despachoId = await DespachoVigenteAsync(pedido.Id);

        // Una sola marca por pedido y camión: dos toques seguidos, o dos
        // personas a la vez, no deben duplicar lo que se tiene que revisar.
        var yaMarcado = await _context.NovedadesEntrega.AnyAsync(n =>
            n.PedidoId == pedido.Id
            && n.Tipo == TipoNovedad.Pedido
            && n.Estado != EstadoNovedad.Anulada
            && n.DespachoId == despachoId);

        if (yaMarcado)
            throw new ConflictException("Este pedido ya está marcado como no entregado.");

        var lineas = pedido.Detalle.Where(d => !d.Anulado).ToList();
        if (lineas.Count == 0)
            throw new BadRequestException("Este pedido no tiene productos.");

        var ahora = DateTime.UtcNow;

        foreach (var linea in lineas)
        {
            _context.NovedadesEntrega.Add(new NovedadEntrega
            {
                Tipo = TipoNovedad.Pedido,
                PedidoId = pedido.Id,
                PedidoDetalleId = linea.Id,
                DespachoId = despachoId,
                ProductoId = linea.ProductoId,
                PresentacionId = linea.PresentacionId,
                CantidadPedida = linea.Cantidad,
                CantidadEntregada = 0,
                Importe = Math.Round(linea.CantidadPresentacion * linea.PrecioPresentacion, 2),
                MotivoId = motivo.Id,
                Observacion = Limpiar(observacion),
                UsuarioId = usuarioId,
                Fecha = ahora,
                Estado = EstadoInicial(motivo),
            });
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "noEntregado", new { PedidoId = pedido.Id, despachoId });
    }

    public async Task<Dictionary<int, NoEntregadoInfo>> GetNoEntregadosAsync(IEnumerable<int> pedidoIds)
    {
        var ids = pedidoIds.Distinct().ToList();
        if (ids.Count == 0) return [];

        var marcas = await _context.NovedadesEntrega
            .AsNoTracking()
            .Where(n => ids.Contains(n.PedidoId)
                        && n.Tipo == TipoNovedad.Pedido
                        && n.Estado != EstadoNovedad.Anulada)
            .OrderByDescending(n => n.Id)
            .Select(n => new { n.PedidoId, Motivo = n.Motivo!.Nombre, n.Observacion })
            .ToListAsync();

        // Todas las líneas de una marca comparten motivo: basta la primera.
        return marcas
            .GroupBy(m => m.PedidoId)
            .ToDictionary(g => g.Key, g => new NoEntregadoInfo(g.First().Motivo, g.First().Observacion));
    }

    public async Task DeshacerNoEntregadoAsync(int pedidoId)
    {
        var marcas = await _context.NovedadesEntrega
            .Where(n => n.PedidoId == pedidoId
                        && n.Tipo == TipoNovedad.Pedido
                        && n.Estado != EstadoNovedad.Anulada)
            .ToListAsync();

        if (marcas.Count == 0)
            throw new BadRequestException("Este pedido no está marcado como no entregado.");

        // Ya contada por el encargado: deshacerla borraría un rastro que
        // alguien revisó. Si se marcó mal, se corrige desde la revisión.
        if (marcas.Any(n => n.Estado is EstadoNovedad.Recibida or EstadoNovedad.Faltante))
            throw new BadRequestException(
                "El encargado ya revisó esa mercadería: no se puede quitar la marca.");

        foreach (var marca in marcas) marca.Estado = EstadoNovedad.Anulada;

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("novedades", "noEntregadoQuitado", new { PedidoId = pedidoId });
    }

    public Task AnularDeVentaAsync(int notaVentaId) =>
        AnularAsync(_context.NovedadesEntrega.Where(n => n.NotaVentaId == notaVentaId));

    public Task AnularNoEntregadoAsync(int pedidoId) =>
        AnularAsync(_context.NovedadesEntrega.Where(n => n.PedidoId == pedidoId && n.Tipo == TipoNovedad.Pedido));

    public Task AnularDePedidoAsync(int pedidoId) =>
        AnularAsync(_context.NovedadesEntrega.Where(n => n.PedidoId == pedidoId));

    /// <summary>
    /// Deja sin efecto lo que sigue abierto. Lo que el encargado ya contó
    /// (recibida o faltante) se respeta: ahí hubo una revisión de verdad y no
    /// se reescribe por un cambio posterior en el documento.
    /// </summary>
    private async Task AnularAsync(IQueryable<NovedadEntrega> consulta)
    {
        var abiertas = await consulta
            .Where(n => n.Estado == EstadoNovedad.Pendiente || n.Estado == EstadoNovedad.SinRetorno)
            .ToListAsync();

        if (abiertas.Count == 0) return;

        foreach (var novedad in abiertas) novedad.Estado = EstadoNovedad.Anulada;
        await _context.SaveChangesAsync();
    }

    // ------------------------------------------------------------------
    // Auxiliares
    // ------------------------------------------------------------------

    /// <summary>
    /// El camión en el que va el pedido ahora, si va en uno: el despacho armado
    /// más reciente que lo lleva. Uno anulado ya no cuenta.
    /// </summary>
    private async Task<int?> DespachoVigenteAsync(int pedidoId) =>
        await _context.Despachos
            .Where(d => d.Estado == EstadoDespacho.Armado && d.Detalle.Any(x => x.PedidoId == pedidoId))
            .OrderByDescending(d => d.Id)
            .Select(d => (int?)d.Id)
            .FirstOrDefaultAsync();

    /// <summary>
    /// Si la mercadería tiene que volver, queda pendiente de que el encargado
    /// la cuente; si nunca salió del almacén, no hay nada que revisar.
    /// </summary>
    private static string EstadoInicial(MotivoNovedad motivo) =>
        motivo.RegresaAlAlmacen ? EstadoNovedad.Pendiente : EstadoNovedad.SinRetorno;

    private static string Exigir(string valor, string mensaje)
    {
        var limpio = valor.Trim();
        if (limpio.Length == 0) throw new BadRequestException(mensaje);
        return limpio;
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();
}
