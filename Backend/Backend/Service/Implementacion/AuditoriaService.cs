using System.Text.Json;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>Solo lectura: los registros los escribe el DbContext al guardar, no este servicio.</summary>
public class AuditoriaService : IAuditoriaService
{
    private readonly IAuditoriaRepository _repository;

    public AuditoriaService(IAuditoriaRepository repository)
    {
        _repository = repository;
    }

    public async Task<IEnumerable<AuditoriaResponse>> GetAsync(
        string? entidad, string? accion, int? usuarioId, DateTime? desde, DateTime? hasta)
    {
        var registros = await _repository.GetAsync(entidad, accion, usuarioId, desde, hasta);
        return registros.Select(Map);
    }

    public async Task<PaginaResponse<AuditoriaResponse>> ListarAsync(ConsultaTablaRequest consulta)
    {
        var (items, total) = await _repository.ListarAsync(consulta);

        return new PaginaResponse<AuditoriaResponse>
        {
            Items = items.Select(Map).ToList(),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura,
        };
    }

    public async Task<int> EliminarAsync(ConsultaTablaRequest consulta, int? usuarioId)
    {
        var eliminados = await _repository.EliminarAsync(consulta);
        if (eliminados == 0) return 0;

        // Queda un solo registro que dice qué se depuró. Va DESPUÉS del borrado:
        // si fuera antes, un borrado sin filtros se lo llevaría también.
        var valores = new Dictionary<string, object?>
        {
            ["Registros eliminados"] = eliminados,
            ["Búsqueda"] = string.IsNullOrWhiteSpace(consulta.Buscar) ? null : consulta.Buscar.Trim(),
            ["Filtros"] = DescribirFiltros(consulta),
        };

        await _repository.AgregarAsync(new RegistroAuditoria
        {
            UsuarioId = usuarioId,
            Entidad = "Auditoria",
            EntidadId = "depuración",
            Accion = AccionAuditoria.Eliminado,
            ValoresAnteriores = JsonSerializer.Serialize(valores),
        });

        return eliminados;
    }

    /// <summary>Los filtros puestos, en una línea legible; "Ninguno" si se borró todo.</summary>
    private static string DescribirFiltros(ConsultaTablaRequest consulta)
    {
        var partes = consulta.Filtros
            .Where(f => !string.IsNullOrWhiteSpace(f.Valor))
            .Select(f =>
            {
                var nombre = f.Columna switch
                {
                    "fecha" => "Fecha",
                    "usuario" => "Usuario",
                    "entidad" => "Entidad",
                    "accion" => "Acción",
                    "entidadId" => "Registro",
                    var otra => otra,
                };

                return string.IsNullOrWhiteSpace(f.ValorHasta)
                    ? $"{nombre}: {f.Valor}"
                    : $"{nombre}: {f.Valor} → {f.ValorHasta}";
            })
            .ToList();

        return partes.Count == 0 ? "Ninguno" : string.Join(" · ", partes);
    }

    public Task<ResumenAuditoriaResponse> GetResumenAsync() => _repository.ResumenAsync();

    public Task<IEnumerable<string>> GetEntidadesAsync() => _repository.GetEntidadesAsync();

    public async Task<IEnumerable<AuditoriaResponse>> GetHistorialDocumentoAsync(
        string entidadPrincipal, int id, string entidadDetalle, IEnumerable<int> idsDetalleActuales)
    {
        var registros = await _repository.GetHistorialDocumentoAsync(
            entidadPrincipal, id, entidadDetalle, idsDetalleActuales);
        return registros.Select(Map);
    }

    private static AuditoriaResponse Map(RegistroAuditoria r) => new()
    {
        Id = r.Id,
        Fecha = r.Fecha,
        UsuarioId = r.UsuarioId,
        Usuario = r.Usuario?.Nombre ?? "Sistema",
        Entidad = r.Entidad,
        EntidadId = r.EntidadId,
        Accion = r.Accion,
        ValoresAnteriores = Deserializar(r.ValoresAnteriores),
        ValoresNuevos = Deserializar(r.ValoresNuevos)
    };

    private static Dictionary<string, object?>? Deserializar(string? json) =>
        string.IsNullOrWhiteSpace(json)
            ? null
            : JsonSerializer.Deserialize<Dictionary<string, object?>>(json);
}
