using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Gestión y seguimiento de clientes: se elige un cliente y se ve su ficha, el historial de contactos que se le
/// hicieron y el siguiente que quedó programado.
///
/// Todo respeta el alcance de quien pregunta: quien solo ve "sus clientes" no gestiona los de otro.
/// </summary>
public interface ISeguimientoClienteService
{
    /// <summary>Los tipos de contacto y los resultados (con su guía de cuándo elegir cada uno).</summary>
    CatalogoSeguimientoResponse Catalogo();

    /// <summary>Clientes que coinciden con lo escrito (nombre, documento o código), para elegir uno.</summary>
    Task<List<ClienteBuscadoResponse>> BuscarAsync(string? texto);

    /// <summary>
    /// La ficha: datos, estado (por caída frente al mismo tramo del año anterior), tarjetas, productos principales,
    /// última gestión y próximo contacto.
    /// </summary>
    Task<FichaClienteResponse> FichaAsync(int clienteId, DateTime? desde, DateTime? hasta);

    Task<GestionesClienteResponse> GestionesAsync(int clienteId);

    /// <summary>
    /// Registra una gestión. Un cliente tiene un solo contacto programado a la vez: el que estaba programado pasa a
    /// cumplido (es el contacto que se acaba de hacer) y, si esta gestión deja uno nuevo, queda ese.
    /// </summary>
    Task<GestionResponse> RegistrarAsync(int clienteId, GuardarGestionRequest request);

    /// <summary>
    /// Corrige una gestión. Si su siguiente contacto ya se cumplió es historia: solo se puede retocar la acción.
    /// </summary>
    Task<GestionResponse> ActualizarAsync(int gestionId, GuardarGestionRequest request);

    /// <summary>Cambia el día y la hora de un contacto que sigue programado.</summary>
    Task<GestionResponse> ReprogramarAsync(int gestionId, ReprogramarGestionRequest request);

    /// <summary>Las ventas del cliente y qué productos dejó de comprar frente al mismo tramo del año anterior.</summary>
    Task<ComprasClienteResponse> ComprasAsync(int clienteId, DateTime? desde, DateTime? hasta);

    /// <summary>Sus pedidos y devoluciones.</summary>
    Task<DocumentosClienteResponse> DocumentosAsync(int clienteId);

    /// <summary>Cuántos contactos programados tiene una persona vencidos y para hoy. Alimenta la campanita.</summary>
    Task<ResumenSeguimientoResponse> ResumenDeAsync(int usuarioId);
}
