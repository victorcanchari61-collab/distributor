using Backend.Data;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// La agenda del seguimiento: las próximas acciones que se anotaron al registrar una gestión y que
/// nadie dio por hechas. No guarda nada propio: es una lectura de <see cref="GestionCliente"/>.
///
/// El alcance es el de la cartera (crm.cartera): un vendedor acotado ve las acciones de sus
/// clientes, no las de toda la empresa.
/// </summary>
public class CrmAgendaService : ICrmAgendaService
{
    private readonly AppDbContext _context;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;

    public CrmAgendaService(AppDbContext context, IPermisoService permisos, IUsuarioActual usuarioActual)
    {
        _context = context;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
    }

    public async Task<CrmAgendaResponse> TareasAsync(string? quien, string? estado)
    {
        var de = string.IsNullOrWhiteSpace(quien) ? "mias" : quien.Trim().ToLowerInvariant();
        if (de is not ("mias" or "todas"))
            throw new BadRequestException("Elige las acciones mias o todas.");

        var filtro = string.IsNullOrWhiteSpace(estado) ? null : estado.Trim().ToLowerInvariant();
        if (filtro is not null && filtro is not ("vencidas" or "hoy" or "proximas"))
            throw new BadRequestException("El estado es vencidas, hoy o proximas.");

        var uid = _usuarioActual.Id ?? throw new UnauthorizedException("Inicia sesión para ver tu agenda.");
        var (tareas, soloPropios) = await AbiertasAsync(uid, soloMias: de == "mias");

        var resumen = Resumir(tareas);
        if (filtro is not null)
        {
            var elegido = filtro switch { "vencidas" => "VENCIDA", "hoy" => "HOY", _ => "PROXIMA" };
            tareas = tareas.Where(t => t.Estado == elegido).ToList();
        }

        return new CrmAgendaResponse
        {
            Quien = de,
            SoloPropios = soloPropios,
            Resumen = resumen,
            Items = tareas,
        };
    }

    public async Task<CrmAgendaResumenResponse> ResumenDeAsync(int usuarioId)
    {
        var (tareas, _) = await AbiertasAsync(usuarioId, soloMias: true);
        return Resumir(tareas);
    }

    private static CrmAgendaResumenResponse Resumir(List<CrmTareaResponse> tareas)
    {
        var vencidas = tareas.Where(t => t.Estado == "VENCIDA").ToList();
        return new CrmAgendaResumenResponse
        {
            Vencidas = vencidas.Count,
            Hoy = tareas.Count(t => t.Estado == "HOY"),
            Proximas = tareas.Count(t => t.Estado == "PROXIMA"),
            VencidaDesde = vencidas.Count > 0 ? vencidas.Min(t => t.Fecha) : null,
        };
    }

    /// <summary>
    /// Las acciones abiertas que esa persona puede ver, ordenadas: vencidas (la más atrasada
    /// primero), hoy, y después las próximas por día.
    /// </summary>
    private async Task<(List<CrmTareaResponse> Tareas, bool SoloPropios)> AbiertasAsync(int uid, bool soloMias)
    {
        var alcance = await _permisos.AlcanceFiltroAsync(uid, "crm.cartera");
        var misRutas = alcance.RutaIds;

        var gestiones = _context.GestionesCliente.AsNoTracking()
            .Where(g => !g.Cumplida && g.ProximaFecha != null);

        // El alcance de la cartera: a quien está acotado solo le llegan los clientes que tiene asignados
        // o que están en sus rutas.
        if (!alcance.SinRestriccion)
        {
            gestiones = gestiones.Where(g => g.Cliente!.VendedorId == uid
                                             || (g.Cliente.RutaId != null && misRutas.Contains(g.Cliente.RutaId.Value)));
        }

        if (soloMias)
        {
            gestiones = gestiones.Where(g => g.UsuarioId == uid
                                             || g.Cliente!.VendedorId == uid
                                             || (g.Cliente.RutaId != null && misRutas.Contains(g.Cliente.RutaId.Value)));
        }

        var filas = await gestiones
            .Select(g => new
            {
                g.Id,
                g.ClienteId,
                Cliente = g.Cliente!.Nombre,
                Telefono = g.Cliente.Telefono,
                Mercado = g.Cliente.Mercado != null ? g.Cliente.Mercado.Nombre : null,
                Ruta = g.Cliente.Ruta != null ? g.Cliente.Ruta.Nombre : null,
                g.ProximaAccion,
                g.ProximaFecha,
                g.Nota,
                g.Tipo,
                g.Resultado,
                Usuario = g.Usuario != null ? g.Usuario.Nombre : null,
            })
            .ToListAsync();

        var hoy = Zona.Hoy;
        var tareas = filas.Select(f =>
        {
            var dia = f.ProximaFecha!.Value.Date;
            return new CrmTareaResponse
            {
                GestionId = f.Id,
                ClienteId = f.ClienteId,
                Codigo = $"CLI{f.ClienteId:D5}",
                Cliente = f.Cliente,
                Telefono = f.Telefono,
                Mercado = f.Mercado,
                Ruta = f.Ruta,
                Accion = f.ProximaAccion ?? string.Empty,
                Fecha = dia,
                Estado = dia < hoy ? "VENCIDA" : dia == hoy ? "HOY" : "PROXIMA",
                DiasAtraso = dia < hoy ? (int)(hoy - dia).TotalDays : 0,
                Nota = f.Nota,
                Tipo = f.Tipo,
                Resultado = f.Resultado,
                RegistradaPor = f.Usuario,
            };
        })
        .OrderBy(t => t.Fecha)
        .ThenBy(t => t.Cliente)
        .ToList();

        return (tareas, !alcance.SinRestriccion);
    }
}
