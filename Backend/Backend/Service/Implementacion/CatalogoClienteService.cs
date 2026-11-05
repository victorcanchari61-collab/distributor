using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// El catálogo para mostrarle al cliente. Solo consulta, y solo lo que es seguro enseñar:
///
///   - Productos activos que se venden: con alguna presentación de venta activa y con precio.
///   - El precio de una presentación sale de la lista elegida (el escalón de cantidad 1); si la lista
///     no la tiene, del precio de referencia del producto por su factor. Igual que al vender.
///   - Nunca costos ni stock.
/// </summary>
public class CatalogoClienteService : ICatalogoClienteService
{
    private readonly ICatalogoClienteRepository _repository;

    private readonly IEmpresaRepository _empresas;

    public CatalogoClienteService(ICatalogoClienteRepository repository, IEmpresaRepository empresas)
    {
        _repository = repository;
        _empresas = empresas;
    }

    public async Task<CatalogoPublicoResponse> GetPublicoAsync()
    {
        // Siempre la lista predeterminada: quien abre el enlace no elige lista ni ve cuáles hay.
        var catalogo = await GetAsync(null);
        var empresa = await _empresas.GetActivaAsync();

        return new CatalogoPublicoResponse
        {
            Empresa = empresa?.NombreComercial is { Length: > 0 } comercial ? comercial : empresa?.RazonSocial ?? string.Empty,
            Telefono = string.IsNullOrWhiteSpace(empresa?.Telefono) ? null : empresa!.Telefono!.Trim(),
            Categorias = catalogo.Categorias,
            Marcas = catalogo.Marcas,
            Productos = catalogo.Productos.Select(p => new CatalogoPublicoProductoResponse
            {
                Nombre = p.Nombre,
                Descripcion = p.Descripcion,
                Categoria = p.Categoria,
                Marca = p.Marca,
                Foto = p.Foto,
                UnidadBase = p.UnidadBase,
                Contenido = p.Contenido,
                PrecioDesde = p.PrecioDesde,
                Presentaciones = p.Presentaciones,
            }).ToList(),
        };
    }

    public async Task<CatalogoClienteResponse> GetAsync(int? listaId)
    {
        var listas = await _repository.GetListasActivasAsync();

        ListaPrecio? lista;
        if (listaId is int id)
        {
            lista = listas.FirstOrDefault(l => l.Id == id)
                ?? throw new NotFoundException($"No existe la lista de precios {id}");
        }
        else
        {
            lista = listas.FirstOrDefault(l => l.EsPredeterminada) ?? listas.FirstOrDefault();
        }

        var precios = lista is null
            ? new Dictionary<int, List<PrecioProducto>>()
            : (await _repository.GetPreciosActivosAsync(lista.Id))
                .GroupBy(p => p.PresentacionId)
                .ToDictionary(g => g.Key, g => g.OrderBy(p => p.CantidadMinima).ToList());

        var productos = new List<CatalogoProductoResponse>();
        foreach (var producto in await _repository.GetProductosActivosAsync())
        {
            var item = Mapear(producto, precios);
            if (item is not null) productos.Add(item);
        }

        return new CatalogoClienteResponse
        {
            Listas = listas.Select(l => new CatalogoListaResponse
            {
                Id = l.Id,
                Nombre = l.Nombre,
                EsPredeterminada = l.EsPredeterminada,
            }).ToList(),
            ListaId = lista?.Id,
            Categorias = Distintos(productos.Select(p => p.Categoria)),
            Marcas = Distintos(productos.Select(p => p.Marca)),
            Productos = productos,
        };
    }

    private static CatalogoProductoResponse? Mapear(
        Producto producto, Dictionary<int, List<PrecioProducto>> precios)
    {
        var presentaciones = new List<CatalogoPresentacionResponse>();

        var filas = producto.Presentaciones.Where(p => DisponibilidadPresentacion.SeVende(producto, p)).ToList();

        foreach (var presentacion in filas.OrderBy(p => p.Factor).ThenBy(p => p.Nombre))
        {
            var deLista = precios.GetValueOrDefault(presentacion.Id) ?? [];
            var normal = deLista.FirstOrDefault(p => p.CantidadMinima <= 1m);

            decimal precio;
            if (normal is not null && normal.Precio > 0)
            {
                precio = normal.Precio;
            }
            else if (producto.PrecioReferencia is decimal porBase && porBase > 0)
            {
                precio = Math.Round(porBase * presentacion.Factor, 2);
            }
            else
            {
                continue;
            }

            presentaciones.Add(new CatalogoPresentacionResponse
            {
                Nombre = presentacion.Nombre,
                Unidad = presentacion.Unidad?.Nombre ?? string.Empty,
                Factor = presentacion.Factor,
                Precio = precio,
                PrecioUnidadBase = presentacion.Factor > 0 ? Math.Round(precio / presentacion.Factor, 2) : precio,
                Escalones = deLista
                    .Where(p => p.CantidadMinima > 1m && p.Precio > 0 && p.Precio < precio)
                    .Select(p => new CatalogoEscalonResponse { CantidadMinima = p.CantidadMinima, Precio = p.Precio })
                    .ToList(),
            });
        }

        // Un producto que no se vende en ninguna presentación, o sin precio, no es de catálogo.
        if (presentaciones.Count == 0) return null;

        return new CatalogoProductoResponse
        {
            Id = producto.Id,
            Codigo = producto.Codigo,
            Nombre = producto.Nombre,
            Descripcion = string.IsNullOrWhiteSpace(producto.Descripcion) ? null : producto.Descripcion.Trim(),
            Categoria = producto.Categoria?.Nombre,
            Marca = producto.Marca?.Nombre,
            Foto = string.IsNullOrWhiteSpace(producto.Foto) ? null : producto.Foto,
            UnidadBase = producto.UnidadBase?.Nombre ?? string.Empty,
            Contenido = producto is { Contenido: decimal c, ContenidoUnidad: { } u } ? $"{c:0.##} {u.Codigo}" : null,
            PrecioDesde = presentaciones.Min(p => p.Precio),
            Presentaciones = presentaciones,
        };
    }

    private static List<string> Distintos(IEnumerable<string?> valores) =>
        valores
            .Where(v => !string.IsNullOrWhiteSpace(v))
            .Select(v => v!)
            .Distinct()
            .Order(StringComparer.CurrentCultureIgnoreCase)
            .ToList();
}
