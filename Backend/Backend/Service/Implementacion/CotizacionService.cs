using System.Globalization;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

public class CotizacionService : ICotizacionService
{
    /// <summary>Líneas por cotización: un carrito de bodega, no un inventario.</summary>
    private const int MaximoLineas = 80;

    /// <summary>Cuántas puede tener un cliente esperando a la vez: frena el spam sin estorbar a nadie de verdad.</summary>
    private const int MaximoEnEspera = 10;

    private readonly ICotizacionRepository _repository;
    private readonly IPortalAccesoService _accesos;
    private readonly ICatalogoClienteService _catalogo;
    private readonly IWhatsAppClient _whatsApp;
    private readonly INotificador _notificador;
    private readonly IUsuarioActual _usuarioActual;
    private readonly IPermisoService _permisos;
    private readonly ILogger<CotizacionService> _logger;

    public CotizacionService(
        ICotizacionRepository repository,
        IPortalAccesoService accesos,
        ICatalogoClienteService catalogo,
        IWhatsAppClient whatsApp,
        INotificador notificador,
        IUsuarioActual usuarioActual,
        IPermisoService permisos,
        ILogger<CotizacionService> logger)
    {
        _repository = repository;
        _accesos = accesos;
        _catalogo = catalogo;
        _whatsApp = whatsApp;
        _notificador = notificador;
        _usuarioActual = usuarioActual;
        _permisos = permisos;
        _logger = logger;
    }

    // ============================================================ El cliente

    public async Task<CatalogoClienteResponse> CatalogoAsync()
    {
        var acceso = await _accesos.AccesoActualAsync();
        var catalogo = await CatalogoDeAsync(acceso.Cliente!.ListaPrecioId);
        // Las demás listas no son asunto del cliente.
        catalogo.Listas = [];
        return catalogo;
    }

    public async Task<List<CotizacionResponse>> MisCotizacionesAsync()
    {
        var acceso = await _accesos.AccesoActualAsync();
        return await MapearAsync(await _repository.GetDeClienteAsync(acceso.ClienteId));
    }

    public async Task<List<int>> FavoritosAsync()
    {
        var acceso = await _accesos.AccesoActualAsync();
        return await _repository.FavoritosAsync(acceso.ClienteId);
    }

    public async Task<List<int>> MarcarFavoritoAsync(int presentacionId, bool favorito)
    {
        var acceso = await _accesos.AccesoActualAsync();
        // Solo se marca lo que el cliente puede ver: una presentación del catálogo (activa, que se vende y con precio).
        // Desmarcar no lo exige: una que dejó de venderse también se tiene que poder quitar.
        var catalogo = await CatalogoDeAsync(acceso.Cliente!.ListaPrecioId);
        var producto = catalogo.Productos.FirstOrDefault(p => p.Presentaciones.Any(pr => pr.Id == presentacionId));
        if (producto is null && favorito) throw new NotFoundException("Esa presentación no está en el catálogo.");

        await _repository.MarcarFavoritoAsync(acceso.ClienteId, producto?.Id ?? 0, presentacionId, favorito);
        return await _repository.FavoritosAsync(acceso.ClienteId);
    }

    public async Task<CotizacionResponse> CrearAsync(CrearCotizacionRequest request)
    {
        var acceso = await _accesos.AccesoActualAsync();
        var cliente = acceso.Cliente!;

        // Varias líneas de la misma presentación se juntan: el carrito puede mandar el mismo saco dos veces.
        var pedidas = request.Detalle
            .Where(l => l.Cantidad > 0)
            .GroupBy(l => l.PresentacionId)
            .Select(g => (PresentacionId: g.Key, Cantidad: g.Sum(l => l.Cantidad)))
            .ToList();
        if (pedidas.Count == 0) throw new BadRequestException("Agrega al menos un producto a tu cotización.");
        if (pedidas.Count > MaximoLineas)
        {
            throw new BadRequestException($"Una cotización puede tener hasta {MaximoLineas} productos distintos.");
        }
        if (pedidas.Any(l => l.Cantidad > 100_000)) throw new BadRequestException("Revisa las cantidades: hay una demasiado grande.");

        var nota = string.IsNullOrWhiteSpace(request.Nota) ? null : request.Nota.Trim();
        if (nota is { Length: > 300 }) throw new BadRequestException("La nota puede tener hasta 300 caracteres.");

        if (await _repository.ContarEnEsperaAsync(cliente.Id) >= MaximoEnEspera)
        {
            throw new BadRequestException(
                $"Ya tienes {MaximoEnEspera} cotizaciones en espera. Espera a que tu vendedor las atienda o cancela alguna.");
        }

        // Los precios los pone el catálogo con la lista del cliente, igual que lo que ve en pantalla.
        var catalogo = await CatalogoDeAsync(cliente.ListaPrecioId);
        var porPresentacion = catalogo.Productos
            .SelectMany(p => p.Presentaciones.Where(pr => pr.Id is not null).Select(pr => (Producto: p, Presentacion: pr)))
            .ToDictionary(x => x.Presentacion.Id!.Value);

        var detalle = new List<CotizacionDetalle>();
        foreach (var (presentacionId, cantidad) in pedidas)
        {
            if (!porPresentacion.TryGetValue(presentacionId, out var item))
            {
                throw new BadRequestException("Un producto de tu cotización ya no está disponible. Actualiza el catálogo e inténtalo de nuevo.");
            }
            var precio = PrecioPorCantidad(item.Presentacion, cantidad);
            detalle.Add(new CotizacionDetalle
            {
                ProductoId = item.Producto.Id,
                PresentacionId = presentacionId,
                Cantidad = cantidad,
                PrecioPresentacion = precio,
                Subtotal = Math.Round(cantidad * precio, 2),
            });
        }

        // A quien atiende la ruta del cliente (el cliente ya no guarda vendedor propio).
        var vendedores = cliente.RutaId is int ruta ? await _repository.VendedoresDeRutaAsync(ruta) : [];

        var cotizacion = new Cotizacion
        {
            Numero = await _repository.SiguienteNumeroAsync(),
            ClienteId = cliente.Id,
            VendedorId = vendedores.FirstOrDefault()?.Id,
            ListaPrecioId = catalogo.ListaId,
            Fecha = DateTime.UtcNow,
            Estado = EstadoCotizacion.EnEspera,
            Nota = nota,
            Total = detalle.Sum(d => d.Subtotal),
            Detalle = detalle,
        };
        await _repository.AddAsync(cotizacion);

        var creada = await GetMapeadaAsync(cotizacion.Id);
        await _notificador.AvisarAsync("cotizaciones", "creada", creada);
        await AvisarVendedoresAsync(vendedores, creada);
        return creada;
    }

    public async Task<CotizacionResponse> CancelarAsync(int id)
    {
        var acceso = await _accesos.AccesoActualAsync();
        var cotizacion = await _repository.GetAsync(id);
        // De otro cliente es como si no existiera.
        if (cotizacion is null || cotizacion.ClienteId != acceso.ClienteId)
        {
            throw new NotFoundException("No encontramos esa cotización.");
        }
        if (cotizacion.Estado != EstadoCotizacion.EnEspera)
        {
            throw new BadRequestException("Solo se puede cancelar una cotización que sigue en espera.");
        }

        cotizacion.Estado = EstadoCotizacion.Cancelada;
        cotizacion.FechaCierre = DateTime.UtcNow;
        await _repository.SaveAsync();

        var cancelada = await GetMapeadaAsync(id);
        await _notificador.AvisarAsync("cotizaciones", "cancelada", cancelada);
        return cancelada;
    }

    // ============================================================== El panel

    public async Task<List<CotizacionResponse>> GetAllAsync(string? estado, int? clienteId) =>
        await MapearAsync(await _repository.GetListaAsync(estado, clienteId, await AlcanceAsync()));

    public async Task<CotizacionResponse> GetAsync(int id)
    {
        var cotizacion = await _repository.GetAsync(id) ?? throw new NotFoundException($"No existe la cotización {id}");
        await ExigirVisibleAsync(cotizacion);
        return (await MapearAsync([cotizacion]))[0];
    }

    public async Task<CotizacionResponse> DescartarAsync(int id, DescartarCotizacionRequest request)
    {
        var motivo = request.Motivo?.Trim() ?? string.Empty;
        if (motivo.Length == 0) throw new BadRequestException("Escribe por qué no se atiende: lo verá el cliente.");
        if (motivo.Length > 250) throw new BadRequestException("El motivo puede tener hasta 250 caracteres.");

        var cotizacion = await _repository.GetAsync(id) ?? throw new NotFoundException($"No existe la cotización {id}");
        await ExigirVisibleAsync(cotizacion);
        if (cotizacion.Estado != EstadoCotizacion.EnEspera)
        {
            throw new BadRequestException("Solo se puede descartar una cotización en espera.");
        }

        cotizacion.Estado = EstadoCotizacion.Descartada;
        cotizacion.MotivoDescarte = motivo;
        cotizacion.FechaCierre = DateTime.UtcNow;
        cotizacion.CerradaPorId = _usuarioActual.Id;
        await _repository.SaveAsync();

        var descartada = await GetMapeadaAsync(id);
        await _notificador.AvisarAsync("cotizaciones", "descartada", descartada);
        return descartada;
    }

    // ================================================================ Apoyo

    /// <summary>El catálogo con la lista del cliente; si su lista ya no está activa, con la predeterminada.</summary>
    private async Task<CatalogoClienteResponse> CatalogoDeAsync(int? listaId)
    {
        try
        {
            return await _catalogo.GetAsync(listaId);
        }
        catch (NotFoundException) when (listaId is not null)
        {
            return await _catalogo.GetAsync(null);
        }
    }

    /// <summary>El precio de una presentación por esa cantidad: el del escalón más alto que alcanza, o el normal.</summary>
    private static decimal PrecioPorCantidad(CatalogoPresentacionResponse presentacion, decimal cantidad) =>
        presentacion.Escalones
            .Where(e => e.CantidadMinima <= cantidad)
            .OrderByDescending(e => e.CantidadMinima)
            .Select(e => (decimal?)e.Precio)
            .FirstOrDefault() ?? presentacion.Precio;

    /// <summary>Hasta dónde ve quien pregunta: el mismo alcance que en Pedidos.</summary>
    private async Task<AlcanceFiltro?> AlcanceAsync() =>
        _usuarioActual.Id is int id ? await _permisos.AlcanceFiltroAsync(id, "fact.pedidos") : null;

    private async Task ExigirVisibleAsync(Cotizacion cotizacion)
    {
        var alcance = await AlcanceAsync();
        if (alcance is null || alcance.SinRestriccion) return;
        var visible = cotizacion.VendedorId == alcance.UsuarioId || alcance.EsDeMisRutas(cotizacion.Cliente?.RutaId);
        if (!visible) throw new NotFoundException($"No existe la cotización {cotizacion.Id}");
    }

    /// <summary>
    /// Un WhatsApp a cada vendedor de la ruta con teléfono. Si no sale, no importa: la cotización ya está guardada y
    /// aparece en su bandeja y en el aviso en tiempo real.
    /// </summary>
    private async Task AvisarVendedoresAsync(List<Usuario> vendedores, CotizacionResponse cotizacion)
    {
        var productos = cotizacion.Detalle.Count == 1 ? "1 producto" : $"{cotizacion.Detalle.Count} productos";
        var total = cotizacion.Total.ToString("N2", CultureInfo.GetCultureInfo("es-PE"));
        var mensaje =
            $"Nueva cotización {cotizacion.Numero} de {cotizacion.Cliente}: {productos}, S/ {total}." +
            (cotizacion.Nota is { } nota ? $"\nNota: {nota}" : string.Empty) +
            "\n\nPara atenderla: Pedidos › Nuevo pedido › Jalar cotización.";

        foreach (var vendedor in vendedores)
        {
            var telefono = new string((vendedor.Telefono ?? string.Empty).Where(char.IsDigit).ToArray());
            if (telefono.Length < 9) continue;
            try
            {
                var (ok, error) = await _whatsApp.EnviarAsync(telefono, mensaje);
                if (!ok) _logger.LogWarning("Cotización {Numero}: no salió el aviso a {Vendedor}: {Error}", cotizacion.Numero, vendedor.Id, error);
            }
            catch (Exception e)
            {
                _logger.LogWarning(e, "Cotización {Numero}: falló el aviso por WhatsApp", cotizacion.Numero);
            }
        }
    }

    private async Task<CotizacionResponse> GetMapeadaAsync(int id) =>
        (await MapearAsync([(await _repository.GetAsync(id))!]))[0];

    private async Task<List<CotizacionResponse>> MapearAsync(List<Cotizacion> cotizaciones)
    {
        var atendidas = cotizaciones.Where(c => c.Estado == EstadoCotizacion.Atendida).Select(c => c.Id).ToList();
        var pedidos = await _repository.PedidosDeAsync(atendidas);
        return cotizaciones.Select(c => Map(c, pedidos.TryGetValue(c.Id, out var p) ? p : null)).ToList();
    }

    private static CotizacionResponse Map(Cotizacion c, (int Id, string Numero)? pedido) => new()
    {
        Id = c.Id,
        Numero = c.Numero,
        Fecha = c.Fecha,
        Estado = c.Estado,
        ClienteId = c.ClienteId,
        Cliente = c.Cliente?.Nombre ?? string.Empty,
        ClienteDocumento = c.Cliente?.Documento ?? string.Empty,
        Ruta = c.Cliente?.Ruta?.Nombre,
        VendedorId = c.VendedorId,
        Vendedor = c.Vendedor?.Nombre,
        ListaPrecioId = c.ListaPrecioId,
        Nota = c.Nota,
        Total = c.Total,
        PedidoId = pedido?.Id,
        PedidoNumero = pedido?.Numero,
        FechaCierre = c.FechaCierre,
        CerradaPor = c.CerradaPor?.Nombre,
        MotivoDescarte = c.MotivoDescarte,
        Detalle = c.Detalle.OrderBy(d => d.Id).Select(d => new CotizacionLineaResponse
        {
            Id = d.Id,
            ProductoId = d.ProductoId,
            Codigo = d.Producto?.Codigo ?? string.Empty,
            Producto = d.Producto?.Nombre ?? string.Empty,
            PresentacionId = d.PresentacionId,
            Presentacion = d.Presentacion?.Nombre ?? string.Empty,
            Factor = d.Presentacion?.Factor ?? 1,
            Cantidad = d.Cantidad,
            PrecioPresentacion = d.PrecioPresentacion,
            Subtotal = d.Subtotal,
        }).ToList(),
    };
}
