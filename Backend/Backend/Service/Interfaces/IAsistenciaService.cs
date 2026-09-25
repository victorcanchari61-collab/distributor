using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>Quién vino, quién faltó, quién llegó tarde. Ver <see cref="Models.Asistencia"/>.</summary>
public interface IAsistenciaService
{
    Task<IEnumerable<AsistenciaResponse>> ListarAsync(DateTime desde, DateTime hasta, int? empleadoId);
    Task<ResumenAsistenciaResponse> ResumenAsync(DateTime desde, DateTime hasta, int? empleadoId);

    Task<AsistenciaResponse> CrearAsync(CrearAsistenciaRequest request, int? usuarioId);
    Task<AsistenciaResponse> EditarAsync(int id, EditarAsistenciaRequest request);

    /// <summary>
    /// El pase de lista de un día, todo o nada: registra a quien no tiene marca
    /// y corrige a quien ya la tiene — esto último solo con <paramref name="puedeCorregir"/>.
    /// </summary>
    Task<MarcarDiaAsistenciaResponse> MarcarDiaAsync(MarcarDiaAsistenciaRequest request, int? usuarioId, bool puedeCorregir);

    /// <summary>Deja sin efecto una marca hecha por error. No se borra: queda el historial.</summary>
    Task<AsistenciaResponse> AnularAsync(int id);
}
