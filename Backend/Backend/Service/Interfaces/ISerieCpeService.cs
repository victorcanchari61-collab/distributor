using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Las series de comprobantes de una empresa y su numeración. Quien ya venía facturando con otro sistema registra
/// aquí sus series y el último número que usó, para continuar desde ahí.
/// </summary>
public interface ISerieCpeService
{
    Task<List<SerieCpeResponse>> ListarAsync(int empresaId);

    Task<SerieCpeResponse> CrearAsync(int empresaId, GuardarSerieRequest request);

    Task<SerieCpeResponse> ActualizarAsync(int empresaId, int id, GuardarSerieRequest request);

    /// <summary>Quita una serie que nunca se usó. Si ya tiene comprobantes solo se puede desactivar.</summary>
    Task EliminarAsync(int empresaId, int id);

    /// <summary>Crea las seis series de siempre (F001, B001 y las de notas) que a la empresa le falten.</summary>
    Task<List<SerieCpeResponse>> CrearEstandarAsync(int empresaId);
}
