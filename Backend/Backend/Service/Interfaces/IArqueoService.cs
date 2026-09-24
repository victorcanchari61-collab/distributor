using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// El cuadre de caja de los días de reparto, persona por persona.
/// </summary>
public interface IArqueoService
{
    // --- Motivos de gasto ---
    Task<IEnumerable<MotivoGastoResponse>> GetMotivosAsync();
    Task<MotivoGastoResponse> CrearMotivoAsync(MotivoGastoRequest request);
    Task<MotivoGastoResponse> ActualizarMotivoAsync(int id, MotivoGastoRequest request);
    Task EliminarMotivoAsync(int id);

    /// <summary>
    /// Quién cobró qué entre dos fechas, una fila por día y persona, con su
    /// estado de cuadre.
    /// </summary>
    Task<IEnumerable<CuadrePendienteResponse>> GetCuadresAsync(DateTime desde, DateTime hasta);

    /// <summary>Todo lo necesario para cuadrar a una persona en un día.</summary>
    Task<DetalleCuadreResponse> GetDetalleAsync(DateTime fecha, int usuarioId);

    /// <summary>
    /// El dueño le entrega efectivo a alguien para gastos de ruta, antes de
    /// que salga. Trazable: postea el Egreso en la Caja General ahí mismo.
    /// </summary>
    Task<ArqueoCajaResponse> EntregarFondoAsync(EntregarFondoRequest request, int? entregadoPorId);

    /// <summary>Registra o corrige el cuadre de esa persona y ese día.</summary>
    Task<ArqueoCajaResponse> RegistrarAsync(RegistrarArqueoRequest request, int? registradoPorId);

    /// <summary>Deja sin efecto un cuadre mal registrado, conservándolo.</summary>
    Task<ArqueoCajaResponse> AnularAsync(int id, int? usuarioId);

    /// <summary>Una página del historial de cuadres ya registrados.</summary>
    Task<PaginaResponse<ArqueoCajaResponse>> ListarAsync(ConsultaTablaRequest consulta);

    Task<ArqueoCajaResponse> GetAsync(int id);

    /// <summary>Lo que cada persona debe por faltantes, para descontárselo.</summary>
    Task<IEnumerable<DeudaUsuarioResponse>> GetDeudasAsync();

    /// <summary>Marca el faltante de un cuadre como descontado o repuesto.</summary>
    Task<ArqueoCajaResponse> SaldarFaltanteAsync(int id);
}
