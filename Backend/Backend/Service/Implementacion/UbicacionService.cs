using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// Pisos, cuartos y estantes de un almacén, y dónde está cada producto.
///
/// Es un árbol de profundidad libre (hasta <see cref="MaximoNivel"/> escalones) donde cada punto lleva su
/// código; la "ruta" —los códigos de arriba hacia abajo unidos con guion— es como se nombra el lugar.
/// </summary>
public class UbicacionService : IUbicacionService
{
    /// <summary>Piso, cuarto y estante, y margen de sobra: más profundo que esto ya no se encuentra.</summary>
    private const int MaximoNivel = 6;

    private readonly AppDbContext _context;
    private readonly IValidator<CrearUbicacionRequest> _crear;
    private readonly IValidator<ActualizarUbicacionRequest> _actualizar;
    private readonly IValidator<GenerarUbicacionesRequest> _generar;
    private readonly IValidator<AsignarProductoUbicacionRequest> _asignar;
    private readonly IValidator<AsignarProductosUbicacionRequest> _asignarVarios;
    private readonly IValidator<QuitarProductosUbicacionRequest> _quitarVarios;
    private readonly INotificador _notificador;

    public UbicacionService(
        AppDbContext context,
        IValidator<CrearUbicacionRequest> crear,
        IValidator<ActualizarUbicacionRequest> actualizar,
        IValidator<GenerarUbicacionesRequest> generar,
        IValidator<AsignarProductoUbicacionRequest> asignar,
        IValidator<AsignarProductosUbicacionRequest> asignarVarios,
        IValidator<QuitarProductosUbicacionRequest> quitarVarios,
        INotificador notificador)
    {
        _context = context;
        _crear = crear;
        _actualizar = actualizar;
        _generar = generar;
        _asignar = asignar;
        _asignarVarios = asignarVarios;
        _quitarVarios = quitarVarios;
        _notificador = notificador;
    }

    // ------------------------------------------------------------- Lectura

    public async Task<List<UbicacionResponse>> ListarAsync(int almacenId)
    {
        await ExigirAlmacenAsync(almacenId);

        var filas = await _context.UbicacionesAlmacen.AsNoTracking()
            .Where(u => u.AlmacenId == almacenId)
            .ToListAsync();

        var productos = await _context.ProductosUbicacion.AsNoTracking()
            .Where(p => p.Ubicacion!.AlmacenId == almacenId)
            .GroupBy(p => p.UbicacionId)
            .Select(g => new { UbicacionId = g.Key, Total = g.Count() })
            .ToDictionaryAsync(x => x.UbicacionId, x => x.Total);

        return EnOrdenDeArbol(filas, productos);
    }

    /// <summary>
    /// Arma la lista con la ruta y el nivel de cada punto, recorriendo el árbol de arriba hacia abajo: cada lugar
    /// sale seguido de lo que tiene adentro, y los hermanos por código. Así quien dibuja solo tiene que
    /// sangrar por el nivel.
    /// </summary>
    private static List<UbicacionResponse> EnOrdenDeArbol(List<UbicacionAlmacen> filas, Dictionary<int, int> productos)
    {
        var porPadre = filas.ToLookup(u => u.PadreId);
        var resultado = new List<UbicacionResponse>(filas.Count);

        void Recorrer(int? padreId, string rutaPadre, int nivel)
        {
            foreach (var u in porPadre[padreId].OrderBy(x => x.Codigo, StringComparer.OrdinalIgnoreCase))
            {
                var ruta = rutaPadre.Length == 0 ? u.Codigo : $"{rutaPadre}-{u.Codigo}";
                resultado.Add(new UbicacionResponse
                {
                    Id = u.Id,
                    AlmacenId = u.AlmacenId,
                    PadreId = u.PadreId,
                    Tipo = u.Tipo,
                    TipoEtiqueta = TipoUbicacion.Etiqueta(u.Tipo),
                    Codigo = u.Codigo,
                    Nombre = u.Nombre,
                    Ruta = ruta,
                    Nivel = nivel,
                    Activo = u.Activo,
                    Hijos = porPadre[u.Id].Count(),
                    Productos = productos.GetValueOrDefault(u.Id),
                });
                Recorrer(u.Id, ruta, nivel + 1);
            }
        }

        Recorrer(null, string.Empty, 0);
        return resultado;
    }

    // ------------------------------------------------------------- Altas y cambios

    public async Task<UbicacionResponse> CrearAsync(int almacenId, CrearUbicacionRequest request)
    {
        await _crear.ValidateAndThrowAsync(request);
        await ExigirAlmacenAsync(almacenId);
        await ExigirPadreAsync(almacenId, request.PadreId);

        var codigo = Normalizar(request.Codigo);
        if (await _context.UbicacionesAlmacen.AnyAsync(
                u => u.AlmacenId == almacenId && u.PadreId == request.PadreId && u.Codigo == codigo))
            throw new ConflictException($"Ya hay un lugar con el código {codigo} en ese mismo nivel");

        var ubicacion = new UbicacionAlmacen
        {
            AlmacenId = almacenId,
            PadreId = request.PadreId,
            Tipo = request.Tipo,
            Codigo = codigo,
            Nombre = Limpiar(request.Nombre),
        };

        _context.UbicacionesAlmacen.Add(ubicacion);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "creada", new { almacenId });
        return await UnaAsync(almacenId, ubicacion.Id);
    }

    public async Task<List<UbicacionResponse>> GenerarAsync(int almacenId, GenerarUbicacionesRequest request)
    {
        await _generar.ValidateAndThrowAsync(request);
        await ExigirAlmacenAsync(almacenId);
        await ExigirPadreAsync(almacenId, request.PadreId);

        var prefijo = Normalizar(request.Prefijo ?? string.Empty);
        var codigos = Enumerable.Range(request.Desde, request.Hasta - request.Desde + 1)
            .Select(n => prefijo + n.ToString().PadLeft(request.Digitos, '0'))
            .ToList();

        // Un código más largo que el máximo (prefijo largo con muchos dígitos) no cabe en la columna.
        if (codigos.Any(c => c.Length > 20))
            throw new BadRequestException("Los códigos quedan demasiado largos: acorta el prefijo");

        var existentes = await _context.UbicacionesAlmacen.AsNoTracking()
            .Where(u => u.AlmacenId == almacenId && u.PadreId == request.PadreId && codigos.Contains(u.Codigo))
            .Select(u => u.Codigo)
            .ToListAsync();
        if (existentes.Count > 0)
            throw new ConflictException(
                $"Ya existen en ese nivel: {string.Join(", ", existentes.Take(5))}{(existentes.Count > 5 ? "…" : "")}. No se creó ninguno");

        _context.UbicacionesAlmacen.AddRange(codigos.Select(c => new UbicacionAlmacen
        {
            AlmacenId = almacenId,
            PadreId = request.PadreId,
            Tipo = request.Tipo,
            Codigo = c,
        }));
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "creada", new { almacenId });

        var creados = codigos.ToHashSet();
        return (await ListarAsync(almacenId))
            .Where(u => u.PadreId == request.PadreId && creados.Contains(u.Codigo))
            .ToList();
    }

    public async Task<UbicacionResponse> ActualizarAsync(int id, ActualizarUbicacionRequest request)
    {
        await _actualizar.ValidateAndThrowAsync(request);

        var ubicacion = await _context.UbicacionesAlmacen.FirstOrDefaultAsync(u => u.Id == id)
            ?? throw new NotFoundException("Lugar no encontrado");

        var codigo = Normalizar(request.Codigo);
        if (await _context.UbicacionesAlmacen.AnyAsync(
                u => u.Id != id && u.AlmacenId == ubicacion.AlmacenId && u.PadreId == ubicacion.PadreId && u.Codigo == codigo))
            throw new ConflictException($"Ya hay un lugar con el código {codigo} en ese mismo nivel");

        // Un lugar inactivo con cosas activas adentro dejaría productos en un sitio que no se puede usar.
        if (ubicacion.Activo && !request.Activo
            && await _context.UbicacionesAlmacen.AnyAsync(u => u.PadreId == id && u.Activo))
            throw new BadRequestException("Desactiva primero los lugares que tiene adentro");

        ubicacion.Tipo = request.Tipo;
        ubicacion.Codigo = codigo;
        ubicacion.Nombre = Limpiar(request.Nombre);
        ubicacion.Activo = request.Activo;
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "actualizada", new { almacenId = ubicacion.AlmacenId });
        return await UnaAsync(ubicacion.AlmacenId, id);
    }

    public async Task EliminarAsync(int id)
    {
        var ubicacion = await _context.UbicacionesAlmacen.FirstOrDefaultAsync(u => u.Id == id)
            ?? throw new NotFoundException("Lugar no encontrado");

        if (await _context.UbicacionesAlmacen.AnyAsync(u => u.PadreId == id))
            throw new BadRequestException("Tiene lugares adentro: bórralos primero, o desactívalo.");
        if (await _context.ProductosUbicacion.AnyAsync(p => p.UbicacionId == id))
            throw new BadRequestException("Tiene productos puestos: quítalos primero, o desactívalo.");

        _context.UbicacionesAlmacen.Remove(ubicacion);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "eliminada", new { almacenId = ubicacion.AlmacenId });
    }

    // ------------------------------------------------------------- Productos

    public async Task<List<UbicacionProductoResponse>> ProductosAsync(int id)
    {
        if (!await _context.UbicacionesAlmacen.AnyAsync(u => u.Id == id))
            throw new NotFoundException("Lugar no encontrado");

        return await _context.ProductosUbicacion.AsNoTracking()
            .Where(p => p.UbicacionId == id)
            .OrderBy(p => p.Producto!.Nombre)
            .Select(p => new UbicacionProductoResponse
            {
                ProductoId = p.ProductoId,
                Codigo = p.Producto!.Codigo,
                Producto = p.Producto.Nombre,
                Categoria = p.Producto.Categoria != null ? p.Producto.Categoria.Nombre : null,
                UnidadBase = p.Producto.UnidadBase != null ? p.Producto.UnidadBase.Codigo : string.Empty,
            })
            .ToListAsync();
    }

    public async Task<List<UbicacionProductoResponse>> AsignarProductoAsync(int id, AsignarProductoUbicacionRequest request)
    {
        await _asignar.ValidateAndThrowAsync(request);

        var ubicacion = await _context.UbicacionesAlmacen.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id)
            ?? throw new NotFoundException("Lugar no encontrado");
        if (!ubicacion.Activo)
            throw new BadRequestException("Ese lugar está desactivado");

        if (!await _context.Productos.AnyAsync(p => p.Id == request.ProductoId && p.Activo))
            throw new BadRequestException("Ese producto no existe o está inactivo");
        if (await _context.ProductosUbicacion.AnyAsync(p => p.UbicacionId == id && p.ProductoId == request.ProductoId))
            throw new ConflictException("Ese producto ya está en este lugar");

        _context.ProductosUbicacion.Add(new ProductoUbicacion { UbicacionId = id, ProductoId = request.ProductoId });
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "productos", new { almacenId = ubicacion.AlmacenId });
        return await ProductosAsync(id);
    }

    public async Task<List<UbicacionProductoResponse>> QuitarProductoAsync(int id, int productoId)
    {
        var fila = await _context.ProductosUbicacion
            .Include(p => p.Ubicacion)
            .FirstOrDefaultAsync(p => p.UbicacionId == id && p.ProductoId == productoId)
            ?? throw new NotFoundException("Ese producto no está en este lugar");

        var almacenId = fila.Ubicacion!.AlmacenId;
        _context.ProductosUbicacion.Remove(fila);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "productos", new { almacenId });
        return await ProductosAsync(id);
    }

    // ------------------------------------------------------------- Ubicación de productos (trabajo en lote)

    public async Task<ProductosUbicadosResponse> ProductosDelAlmacenAsync(int almacenId)
    {
        await ExigirAlmacenAsync(almacenId);

        // Los lugares con su ruta, para decir "P1-A-E03" y no solo "E03".
        var lugares = await ListarAsync(almacenId);
        var rutas = lugares.ToDictionary(l => l.Id);

        var stock = await _context.CapasCosto.AsNoTracking()
            .Where(c => c.AlmacenId == almacenId && c.CantidadDisponible > 0)
            .GroupBy(c => c.ProductoId)
            .Select(g => new { ProductoId = g.Key, Stock = g.Sum(c => c.CantidadDisponible) })
            .ToDictionaryAsync(x => x.ProductoId, x => x.Stock);

        var puestos = (await _context.ProductosUbicacion.AsNoTracking()
                .Where(p => p.Ubicacion!.AlmacenId == almacenId)
                .Select(p => new { p.ProductoId, p.UbicacionId })
                .ToListAsync())
            .ToLookup(p => p.ProductoId, p => p.UbicacionId);

        // Entran los que tienen stock ahí y los que ya se pusieron en un lugar (aunque hoy no tengan stock).
        var ids = stock.Keys.Concat(puestos.Select(g => g.Key)).Distinct().ToList();

        var productos = await _context.Productos.AsNoTracking()
            .Where(p => p.Activo && ids.Contains(p.Id))
            .OrderBy(p => p.Nombre)
            .Select(p => new
            {
                p.Id,
                p.Codigo,
                p.Nombre,
                Categoria = p.Categoria != null ? p.Categoria.Nombre : null,
                Marca = p.Marca != null ? p.Marca.Nombre : null,
                UnidadBase = p.UnidadBase != null ? p.UnidadBase.Codigo : string.Empty,
            })
            .ToListAsync();

        var items = productos.Select(p => new ProductoUbicadoResponse
        {
            ProductoId = p.Id,
            Codigo = p.Codigo,
            Producto = p.Nombre,
            Categoria = p.Categoria,
            Marca = p.Marca,
            UnidadBase = p.UnidadBase,
            Stock = stock.GetValueOrDefault(p.Id),
            Lugares = puestos[p.Id]
                .Where(rutas.ContainsKey)
                .Select(u => new LugarDeProductoResponse { UbicacionId = u, Ruta = rutas[u].Ruta, Nombre = rutas[u].Nombre })
                .OrderBy(l => l.Ruta, StringComparer.OrdinalIgnoreCase)
                .ToList(),
        }).ToList();

        return new ProductosUbicadosResponse
        {
            AlmacenId = almacenId,
            Lugares = lugares.Count,
            SinLugar = items.Count(i => i.Lugares.Count == 0),
            Items = items,
        };
    }

    public async Task<ProductosUbicadosResponse> AsignarVariosAsync(AsignarProductosUbicacionRequest request)
    {
        await _asignarVarios.ValidateAndThrowAsync(request);

        var lugar = await _context.UbicacionesAlmacen.AsNoTracking().FirstOrDefaultAsync(u => u.Id == request.UbicacionId)
            ?? throw new NotFoundException("Lugar no encontrado");
        if (!lugar.Activo)
            throw new BadRequestException("Ese lugar está desactivado");

        var ids = request.ProductoIds.Distinct().ToList();
        var validos = await _context.Productos.Where(p => p.Activo && ids.Contains(p.Id)).Select(p => p.Id).ToListAsync();
        if (validos.Count != ids.Count)
            throw new BadRequestException("Alguno de los productos no existe o está inactivo");

        await using var transaccion = await _context.Database.BeginTransactionAsync();

        // Mover: se les quita el lugar que tuvieran en este almacén, menos el de destino.
        if (request.Reemplazar)
        {
            var anteriores = await _context.ProductosUbicacion
                .Where(p => ids.Contains(p.ProductoId)
                            && p.Ubicacion!.AlmacenId == lugar.AlmacenId
                            && p.UbicacionId != lugar.Id)
                .ToListAsync();
            _context.ProductosUbicacion.RemoveRange(anteriores);
        }

        var yaAhi = (await _context.ProductosUbicacion
                .Where(p => p.UbicacionId == lugar.Id && ids.Contains(p.ProductoId))
                .Select(p => p.ProductoId)
                .ToListAsync())
            .ToHashSet();
        _context.ProductosUbicacion.AddRange(
            ids.Where(id => !yaAhi.Contains(id)).Select(id => new ProductoUbicacion { ProductoId = id, UbicacionId = lugar.Id }));

        await _context.SaveChangesAsync();
        await transaccion.CommitAsync();

        await _notificador.AvisarAsync("ubicaciones", "productos", new { almacenId = lugar.AlmacenId });
        return await ProductosDelAlmacenAsync(lugar.AlmacenId);
    }

    public async Task<ProductosUbicadosResponse> QuitarVariosAsync(QuitarProductosUbicacionRequest request)
    {
        await _quitarVarios.ValidateAndThrowAsync(request);

        var lugar = await _context.UbicacionesAlmacen.AsNoTracking().FirstOrDefaultAsync(u => u.Id == request.UbicacionId)
            ?? throw new NotFoundException("Lugar no encontrado");

        var ids = request.ProductoIds.Distinct().ToList();
        var filas = await _context.ProductosUbicacion
            .Where(p => p.UbicacionId == lugar.Id && ids.Contains(p.ProductoId))
            .ToListAsync();
        _context.ProductosUbicacion.RemoveRange(filas);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "productos", new { almacenId = lugar.AlmacenId });
        return await ProductosDelAlmacenAsync(lugar.AlmacenId);
    }

    // ------------------------------------------------------------- Ayudas

    private async Task ExigirAlmacenAsync(int almacenId)
    {
        if (!await _context.Almacenes.AnyAsync(a => a.Id == almacenId))
            throw new NotFoundException("Almacén no encontrado");
    }

    /// <summary>El padre existe, es de este almacén, está activo y todavía deja bajar un escalón más.</summary>
    private async Task ExigirPadreAsync(int almacenId, int? padreId)
    {
        if (padreId is not int id) return;

        var padre = await _context.UbicacionesAlmacen.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id)
            ?? throw new BadRequestException("Ese lugar de arriba no existe");
        if (padre.AlmacenId != almacenId)
            throw new BadRequestException("Ese lugar es de otro almacén");
        if (!padre.Activo)
            throw new BadRequestException("Ese lugar de arriba está desactivado");

        // Se cuenta cuántos escalones tiene el padre para no pasar del máximo.
        var nivel = 1;
        var actual = padre;
        while (actual.PadreId is int arriba)
        {
            actual = await _context.UbicacionesAlmacen.AsNoTracking().FirstAsync(u => u.Id == arriba);
            nivel++;
            if (nivel >= MaximoNivel)
                throw new BadRequestException($"Los lugares llegan hasta {MaximoNivel} niveles de profundidad");
        }

        if (nivel >= MaximoNivel)
            throw new BadRequestException($"Los lugares llegan hasta {MaximoNivel} niveles de profundidad");
    }

    private async Task<UbicacionResponse> UnaAsync(int almacenId, int id) =>
        (await ListarAsync(almacenId)).First(u => u.Id == id);

    private static string Normalizar(string codigo) => codigo.Trim().ToUpperInvariant();

    private static string? Limpiar(string? texto) => string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();
}
