using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Repository.Implementacion;

public class ClienteRepository : Repository<Cliente>, IClienteRepository
{
    public ClienteRepository(AppDbContext context) : base(context)
    {
    }

    public override async Task<Cliente?> GetByIdAsync(int id) =>
        await DbSet.Include(c => c.Mercado).Include(c => c.Ruta)
            .Include(c => c.Distrito!).ThenInclude(d => d.Provincia!).ThenInclude(p => p.Departamento)
            .FirstOrDefaultAsync(c => c.Id == id);

    public override async Task<IEnumerable<Cliente>> GetAllAsync() =>
        await DbSet.Include(c => c.Mercado).Include(c => c.Ruta)
            .Include(c => c.Distrito!).ThenInclude(d => d.Provincia!).ThenInclude(p => p.Departamento)
            .ToListAsync();

    public async Task<Cliente?> GetByDocumentoAsync(string documento)
    {
        return await DbSet.FirstOrDefaultAsync(c => c.Documento == documento);
    }

    public async Task<bool> ExistsByDocumentoAsync(string documento, int? excludeId = null)
    {
        return await DbSet.AnyAsync(c => c.Documento == documento && c.Id != excludeId);
    }

    public async Task DeleteAsync(Cliente entidad)
    {
        DbSet.Remove(entidad);
        await Context.SaveChangesAsync();
    }

    // ------------------------------------------------------- Listado paginado

    public async Task<(List<Cliente> Items, int Total)> ListarAsync(ConsultaTablaRequest consulta)
    {
        var query = DbSet
            .Include(c => c.Mercado)
            .Include(c => c.Ruta)
            .Include(c => c.Distrito!).ThenInclude(d => d.Provincia!).ThenInclude(p => p.Departamento)
            .AsNoTracking()
            .AsQueryable();

        query = AplicarBusqueda(query, consulta.Buscar);

        foreach (var filtro in consulta.Filtros)
        {
            query = AplicarFiltro(query, filtro);
        }

        // El total se cuenta ANTES de paginar: es cuántas filas hay en todo el
        // listado filtrado, que es lo que dice cuántas páginas dibujar.
        var total = await query.CountAsync();

        query = Ordenar(query, consulta.Orden, consulta.Sentido);

        var items = await query
            .Skip((consulta.PaginaSegura - 1) * consulta.PorPaginaSegura)
            .Take(consulta.PorPaginaSegura)
            .ToListAsync();

        return (items, total);
    }

    /// <summary>
    /// El buscador general: cae sobre las columnas de texto que alguien
    /// escribiría para encontrar a un cliente. No incluye las numéricas ni las
    /// fechas — para eso están los filtros de columna.
    /// </summary>
    private static IQueryable<Cliente> AplicarBusqueda(IQueryable<Cliente> query, string? buscar)
    {
        if (string.IsNullOrWhiteSpace(buscar)) return query;

        var texto = buscar.Trim();

        return query.Where(c =>
            EF.Functions.Like(c.Documento, $"%{texto}%")
            || EF.Functions.Like(c.Nombre, $"%{texto}%")
            || (c.Direccion != null && EF.Functions.Like(c.Direccion, $"%{texto}%"))
            || (c.Telefono != null && EF.Functions.Like(c.Telefono, $"%{texto}%"))
            || (c.Email != null && EF.Functions.Like(c.Email, $"%{texto}%"))
            || (c.Distrito != null && EF.Functions.Like(c.Distrito.Nombre, $"%{texto}%"))
            || (c.Ruta != null && EF.Functions.Like(c.Ruta.Nombre, $"%{texto}%"))
            || (c.Mercado != null && EF.Functions.Like(c.Mercado.Nombre, $"%{texto}%")));
    }

    /// <summary>
    /// Un filtro de columna. Las columnas que no están acá se ignoran a
    /// propósito: la lista es la whitelist de lo que se puede filtrar, para
    /// que un nombre de columna inventado no llegue nunca a la consulta.
    /// </summary>
    private static IQueryable<Cliente> AplicarFiltro(IQueryable<Cliente> query, FiltroTablaRequest filtro)
    {
        var valor = filtro.Valor?.Trim();

        // La fecha es el único filtro de rango, y trae sus dos extremos.
        if (filtro.Columna == "fechaCreacion")
        {
            if (DateTime.TryParse(valor, out var desde))
            {
                query = query.Where(c => c.FechaCreacion >= desde);
            }

            if (DateTime.TryParse(filtro.ValorHasta, out var hasta))
            {
                // El "hasta" incluye todo ese día: quien filtra hasta el 5 no
                // espera perder lo registrado el 5 a las 3 de la tarde.
                var finDelDia = hasta.Date.AddDays(1).AddTicks(-1);
                query = query.Where(c => c.FechaCreacion <= finDelDia);
            }

            return query;
        }

        if (string.IsNullOrWhiteSpace(valor)) return query;

        var exacto = filtro.Operador == "equals";

        return filtro.Columna switch
        {
            "documento" => query.Where(c =>
                exacto ? c.Documento == valor : EF.Functions.Like(c.Documento, $"%{valor}%")),
            "tipoDoc" => query.Where(c => c.TipoDoc == valor),
            "nombre" => query.Where(c =>
                exacto ? c.Nombre == valor : EF.Functions.Like(c.Nombre, $"%{valor}%")),
            "direccion" => query.Where(c => c.Direccion != null &&
                (exacto ? c.Direccion == valor : EF.Functions.Like(c.Direccion, $"%{valor}%"))),
            "telefono" => query.Where(c => c.Telefono != null &&
                (exacto ? c.Telefono == valor : EF.Functions.Like(c.Telefono, $"%{valor}%"))),
            "email" => query.Where(c => c.Email != null &&
                (exacto ? c.Email == valor : EF.Functions.Like(c.Email, $"%{valor}%"))),
            "diaVisita" => query.Where(c => c.DiaVisita == valor),
            "distrito" => query.Where(c => c.Distrito != null &&
                (exacto ? c.Distrito.Nombre == valor : EF.Functions.Like(c.Distrito.Nombre, $"%{valor}%"))),
            "ruta" => query.Where(c => c.Ruta != null &&
                (exacto ? c.Ruta.Nombre == valor : EF.Functions.Like(c.Ruta.Nombre, $"%{valor}%"))),
            "mercado" => query.Where(c => c.Mercado != null &&
                (exacto ? c.Mercado.Nombre == valor : EF.Functions.Like(c.Mercado.Nombre, $"%{valor}%"))),
            // En pantalla el estado se lee "Activo" / "Inactivo", no true/false.
            "activo" => query.Where(c => c.Activo == valor.Equals("Activo", StringComparison.OrdinalIgnoreCase)),
            _ => query
        };
    }

    /// <summary>
    /// El orden pedido por la tabla. Sin orden explícito se mantiene el de
    /// siempre: primero los activos, después por nombre — si no, paginar sobre
    /// un orden indefinido repetiría o saltearía filas entre páginas.
    /// </summary>
    private static IQueryable<Cliente> Ordenar(IQueryable<Cliente> query, string? orden, string? sentido)
    {
        var desc = string.Equals(sentido, "desc", StringComparison.OrdinalIgnoreCase);

        var ordenada = orden switch
        {
            "documento" => desc ? query.OrderByDescending(c => c.Documento) : query.OrderBy(c => c.Documento),
            "tipoDoc" => desc ? query.OrderByDescending(c => c.TipoDoc) : query.OrderBy(c => c.TipoDoc),
            "nombre" => desc ? query.OrderByDescending(c => c.Nombre) : query.OrderBy(c => c.Nombre),
            "direccion" => desc ? query.OrderByDescending(c => c.Direccion) : query.OrderBy(c => c.Direccion),
            "telefono" => desc ? query.OrderByDescending(c => c.Telefono) : query.OrderBy(c => c.Telefono),
            "diaVisita" => desc ? query.OrderByDescending(c => c.DiaVisita) : query.OrderBy(c => c.DiaVisita),
            "distrito" => desc
                ? query.OrderByDescending(c => c.Distrito!.Nombre)
                : query.OrderBy(c => c.Distrito!.Nombre),
            "ruta" => desc ? query.OrderByDescending(c => c.Ruta!.Nombre) : query.OrderBy(c => c.Ruta!.Nombre),
            "mercado" => desc
                ? query.OrderByDescending(c => c.Mercado!.Nombre)
                : query.OrderBy(c => c.Mercado!.Nombre),
            "fechaCreacion" => desc
                ? query.OrderByDescending(c => c.FechaCreacion)
                : query.OrderBy(c => c.FechaCreacion),
            "activo" => desc ? query.OrderByDescending(c => c.Activo) : query.OrderBy(c => c.Activo),
            _ => query.OrderByDescending(c => c.Activo).ThenBy(c => c.Nombre)
        };

        // Desempate por Id: dos clientes con el mismo nombre podrían cambiar de
        // lugar entre una página y la siguiente, y aparecer dos veces o ninguna.
        return ordenada.ThenBy(c => c.Id);
    }

    public async Task<ResumenClientesResponse> ResumenAsync()
    {
        var activos = DbSet.Where(c => c.Activo);

        return new ResumenClientesResponse
        {
            Activos = await activos.CountAsync(),
            Desactivados = await DbSet.CountAsync(c => !c.Activo),
            ConRuta = await activos.CountAsync(c => c.RutaId != null),
            Rutas = await activos.Where(c => c.RutaId != null).Select(c => c.RutaId).Distinct().CountAsync(),

            Direcciones = await ValoresDistintos(DbSet.Select(c => c.Direccion)),
            Distritos = await ValoresDistintos(DbSet.Select(c => c.Distrito!.Nombre)),
            RutasNombres = await ValoresDistintos(DbSet.Select(c => c.Ruta!.Nombre)),
            Mercados = await ValoresDistintos(DbSet.Select(c => c.Mercado!.Nombre))
        };
    }

    /// <summary>Los valores que de verdad existen en una columna, sin repetir ni vacíos.</summary>
    private static async Task<List<string>> ValoresDistintos(IQueryable<string?> columna) =>
        await columna
            .Where(v => v != null && v != "")
            .Distinct()
            .OrderBy(v => v)
            .Select(v => v!)
            .ToListAsync();
}
