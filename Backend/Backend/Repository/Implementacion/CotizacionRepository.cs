using Backend.Data;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class CotizacionRepository : ICotizacionRepository
{
    private readonly AppDbContext _context;

    public CotizacionRepository(AppDbContext context)
    {
        _context = context;
    }

    // ------------------------------------------------------------ Accesos

    private IQueryable<AccesoCliente> Accesos() =>
        _context.AccesosCliente
            .Include(a => a.Cliente).ThenInclude(c => c!.Vendedor)
            .Include(a => a.InvitadoPor);

    public Task<AccesoCliente?> GetAccesoDeClienteAsync(int clienteId) =>
        Accesos().FirstOrDefaultAsync(a => a.ClienteId == clienteId);

    public Task<AccesoCliente?> GetAccesoAsync(int id) =>
        Accesos().FirstOrDefaultAsync(a => a.Id == id);

    public Task<AccesoCliente?> GetAccesoPorTokenAsync(string tokenHash) =>
        Accesos().FirstOrDefaultAsync(a => a.TokenHash == tokenHash);

    public async Task<AccesoCliente?> GetAccesoPorIdentificadorAsync(string identificador)
    {
        var porUsuario = await Accesos().FirstOrDefaultAsync(a => a.Usuario == identificador);
        if (porUsuario is not null) return porUsuario;

        // Con su DNI o RUC también entra: es lo que nunca olvida.
        return await Accesos().FirstOrDefaultAsync(a =>
            a.Usuario != null && a.Cliente != null
            && (a.Cliente.Documento == identificador || a.Cliente.DocumentoAlterno == identificador));
    }

    public Task<bool> UsuarioTomadoAsync(string usuario, int excluirAccesoId) =>
        _context.AccesosCliente.AnyAsync(a => a.Usuario == usuario && a.Id != excluirAccesoId);

    public async Task AddAccesoAsync(AccesoCliente acceso)
    {
        await _context.AccesosCliente.AddAsync(acceso);
        await _context.SaveChangesAsync();
    }

    public Task<List<Usuario>> VendedoresDeRutaAsync(int rutaId) =>
        _context.UsuarioRutas.AsNoTracking()
            .Where(r => r.RutaId == rutaId && r.Usuario!.Activo)
            .Select(r => r.Usuario!)
            .OrderBy(u => u.Nombre)
            .ToListAsync();

    // ---------------------------------------------------------- Favoritos

    public Task<List<int>> FavoritosAsync(int clienteId) =>
        _context.ClienteFavoritos.AsNoTracking()
            .Where(f => f.ClienteId == clienteId)
            .OrderBy(f => f.Fecha).ThenBy(f => f.Id)
            .Select(f => f.PresentacionId)
            .ToListAsync();

    public async Task MarcarFavoritoAsync(int clienteId, int productoId, int presentacionId, bool favorito)
    {
        var existente = await _context.ClienteFavoritos
            .FirstOrDefaultAsync(f => f.ClienteId == clienteId && f.PresentacionId == presentacionId);
        if (favorito && existente is null)
        {
            await _context.ClienteFavoritos.AddAsync(new ClienteFavorito
            {
                ClienteId = clienteId,
                ProductoId = productoId,
                PresentacionId = presentacionId,
            });
        }
        else if (!favorito && existente is not null)
        {
            _context.ClienteFavoritos.Remove(existente);
        }
        else
        {
            return;
        }

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException) when (favorito)
        {
            // Dos toques seguidos al corazón: el otro ya lo marcó. El resultado es el que se quería.
        }
    }

    // ------------------------------------------------------- Cotizaciones

    public async Task<string> SiguienteNumeroAsync()
    {
        var ultimo = await _context.Cotizaciones
            .OrderByDescending(c => c.Id)
            .Select(c => c.Numero)
            .FirstOrDefaultAsync();

        var correlativo = 1;
        if (ultimo is not null && int.TryParse(ultimo.Split('-').Last(), out var n)) correlativo = n + 1;
        return $"CT-{correlativo:D4}";
    }

    public async Task AddAsync(Cotizacion cotizacion)
    {
        await _context.Cotizaciones.AddAsync(cotizacion);
        await _context.SaveChangesAsync();
    }

    private IQueryable<Cotizacion> ConDetalle() =>
        _context.Cotizaciones
            .Include(c => c.Cliente).ThenInclude(c => c!.Ruta)
            .Include(c => c.Vendedor)
            .Include(c => c.CerradaPor)
            .Include(c => c.Detalle).ThenInclude(d => d.Producto)
            .Include(c => c.Detalle).ThenInclude(d => d.Presentacion)
            .AsSplitQuery();

    public Task<Cotizacion?> GetAsync(int id) => ConDetalle().FirstOrDefaultAsync(c => c.Id == id);

    public async Task<List<Cotizacion>> GetListaAsync(string? estado, int? clienteId, AlcanceFiltro? alcance)
    {
        var query = ConDetalle().AsNoTracking();
        if (!string.IsNullOrWhiteSpace(estado)) query = query.Where(c => c.Estado == estado);
        if (clienteId is int id) query = query.Where(c => c.ClienteId == id);

        // Quien no ve todo ve las de los clientes de sus rutas (el cliente es de quien atiende su ruta) y las que le
        // llegaron a él, aunque después el cliente haya cambiado de ruta. Una cotización no la "registra" el vendedor,
        // así que "propios" se trata igual que "mis clientes".
        if (alcance is not null && !alcance.SinRestriccion)
        {
            var rutas = alcance.RutaIds;
            var usuarioId = alcance.UsuarioId;
            query = query.Where(c => c.VendedorId == usuarioId
                                     || (c.Cliente != null && c.Cliente.RutaId != null && rutas.Contains(c.Cliente.RutaId.Value)));
        }

        // Tope sano: es una bandeja de trabajo, no un histórico. Las en espera van todas.
        return await query.OrderByDescending(c => c.Fecha).ThenByDescending(c => c.Id).Take(500).ToListAsync();
    }

    public Task<List<Cotizacion>> GetDeClienteAsync(int clienteId) =>
        ConDetalle().AsNoTracking()
            .Where(c => c.ClienteId == clienteId)
            .OrderByDescending(c => c.Fecha).ThenByDescending(c => c.Id)
            .Take(100)
            .ToListAsync();

    public Task<int> ContarEnEsperaAsync(int clienteId) =>
        _context.Cotizaciones.CountAsync(c => c.ClienteId == clienteId && c.Estado == EstadoCotizacion.EnEspera);

    public async Task<Dictionary<int, (int Id, string Numero)>> PedidosDeAsync(IReadOnlyCollection<int> cotizacionIds)
    {
        if (cotizacionIds.Count == 0) return [];
        var ids = cotizacionIds.ToList();
        var filas = await _context.Pedidos.AsNoTracking()
            .Where(p => p.CotizacionId != null && ids.Contains(p.CotizacionId.Value))
            .Select(p => new { CotizacionId = p.CotizacionId!.Value, p.Id, p.Numero })
            .ToListAsync();
        return filas.ToDictionary(f => f.CotizacionId, f => (f.Id, f.Numero));
    }

    public Task SaveAsync() => _context.SaveChangesAsync();
}
