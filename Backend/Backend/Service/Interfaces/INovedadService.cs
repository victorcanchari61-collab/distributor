using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;

namespace Backend.Service.Interfaces;

/// <summary>
/// Lo que no se entregó completo: por qué, cuánto, y qué pasó con esa
/// mercadería después.
/// </summary>
public interface INovedadService
{
    // --- Motivos ---
    Task<IEnumerable<MotivoNovedadResponse>> GetMotivosAsync();

    /// <summary>Solo los activos y sin contadores: para elegir al entregar.</summary>
    Task<IEnumerable<MotivoNovedadOpcionResponse>> GetOpcionesAsync();

    Task<MotivoNovedadResponse> CrearMotivoAsync(MotivoNovedadRequest request);
    Task<MotivoNovedadResponse> ActualizarMotivoAsync(int id, MotivoNovedadRequest request);

    // --- Listado y revisión ---

    /// <summary>Una página de novedades, ya buscada, filtrada y ordenada en el servidor.</summary>
    Task<PaginaResponse<NovedadResponse>> ListarAsync(ConsultaTablaRequest consulta);

    Task<ResumenNovedadesResponse> ResumenAsync();

    /// <summary>El encargado cuenta lo que volvió: llegó completo o faltó algo.</summary>
    Task<NovedadResponse> VerificarAsync(int id, VerificarNovedadRequest request, int? usuarioId);

    /// <summary>Deshace una revisión: se contó mal y vuelve a quedar pendiente.</summary>
    Task<NovedadResponse> ReabrirAsync(int id);

    // --- Registro (lo llama Ventas al entregar) ---

    /// <summary>
    /// Comprueba que los motivos existan y estén activos. Se llama ANTES de
    /// crear la venta, para no dejar una venta hecha con un motivo inválido.
    /// </summary>
    Task<Dictionary<int, MotivoNovedad>> ExigirMotivosAsync(IEnumerable<int> ids);

    /// <summary>Guarda una novedad por cada línea que se entregó en menos.</summary>
    Task RegistrarLineasAsync(
        Pedido pedido, int notaVentaId, IReadOnlyList<CambioEntrega> cambios,
        IReadOnlyDictionary<int, MotivoNovedad> motivos, int? usuarioId);

    /// <summary>Marca todo el pedido como no entregado: una novedad por cada línea.</summary>
    Task RegistrarNoEntregadoAsync(Pedido pedido, MotivoNovedad motivo, string? observacion, int? usuarioId);

    /// <summary>De esos pedidos, los que están marcados como no entregados y por qué.</summary>
    Task<Dictionary<int, NoEntregadoInfo>> GetNoEntregadosAsync(IEnumerable<int> pedidoIds);

    /// <summary>Quita la marca de "no entregado" de un pedido: se marcó por error.</summary>
    Task DeshacerNoEntregadoAsync(int pedidoId);

    /// <summary>
    /// Deja de valer lo pendiente de una venta que se anuló: la mercadería
    /// que no se entregó ya no forma parte de nada.
    /// </summary>
    Task AnularDeVentaAsync(int notaVentaId);

    /// <summary>El pedido terminó entregándose: el "no entregado" anterior ya no aplica.</summary>
    Task AnularNoEntregadoAsync(int pedidoId);

    /// <summary>El pedido se anuló: todo lo pendiente suyo pierde sentido.</summary>
    Task AnularDePedidoAsync(int pedidoId);
}

/// <summary>Una línea del pedido que se entregó en menos de lo pedido.</summary>
public sealed record CambioEntrega(
    PedidoDetalle Linea,
    decimal Entregada,
    decimal Importe,
    int MotivoId,
    string? Observacion);

/// <summary>Por qué un pedido se marcó entero como no entregado.</summary>
public sealed record NoEntregadoInfo(string Motivo, string? Observacion);
