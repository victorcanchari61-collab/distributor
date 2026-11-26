using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Models;

namespace Backend.Service.Interfaces;

/// <summary>
/// Las cuentas del portal de clientes: el vendedor invita y el cliente crea su propio usuario y contraseña con el
/// enlace que le llega por WhatsApp. Si olvida la contraseña, pide otro enlace él mismo.
/// </summary>
public interface IPortalAccesoService
{
    // --- Desde el panel (el vendedor, en la ficha del cliente) ---

    Task<AccesoPortalResponse> EstadoAsync(int clienteId);

    /// <summary>
    /// Crea (o renueva) la invitación: un enlace de un solo uso que vence en 7 días, mandado por WhatsApp al teléfono
    /// del cliente. Se devuelve el enlace para copiarlo si el WhatsApp no salió. Reinvitar a quien ya tiene cuenta le
    /// deja elegir usuario y contraseña de nuevo (para cuando ya no se acuerda de nada).
    /// </summary>
    Task<InvitacionPortalResponse> InvitarAsync(int clienteId);

    /// <summary>Apagado no entra y sus sesiones abiertas dejan de valer.</summary>
    Task<AccesoPortalResponse> CambiarActivoAsync(int clienteId, bool activo);

    // --- Desde el portal, sin sesión ---

    /// <summary>Lo que se muestra al abrir un enlace; falla si no existe, ya se usó o venció.</summary>
    Task<EnlacePortalResponse> VerEnlaceAsync(string token);

    Task<PortalSesionResponse> ActivarAsync(PortalActivarRequest request);

    Task<PortalSesionResponse> RestablecerAsync(PortalRestablecerRequest request);

    Task<PortalSesionResponse> LoginAsync(PortalLoginRequest request);

    /// <summary>
    /// Manda por WhatsApp un enlace para elegir otra contraseña. No dice si la cuenta existe (siempre "listo"): si no,
    /// serviría para averiguar quién es cliente.
    /// </summary>
    Task OlvideAsync(PortalOlvideRequest request);

    // --- Con la sesión del portal ---

    /// <summary>La cuenta de la sesión, comprobada contra la base (activa y con la misma versión de sesión).</summary>
    Task<AccesoCliente> AccesoActualAsync();

    Task<PortalClienteResponse> YoAsync();
}
