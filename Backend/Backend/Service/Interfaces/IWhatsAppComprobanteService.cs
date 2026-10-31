using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Manda por WhatsApp el enlace de descarga de un comprobante electrónico. El enlace es público y, al abrirlo,
/// baja el PDF directamente: no hay página que cargar ni visor que mantener abierto.
/// </summary>
public interface IWhatsAppComprobanteService
{
    /// <summary>
    /// Envío a mano (botón del comprobante). Sin <paramref name="telefono"/> usa el del cliente. Puede repetirse: es la
    /// forma de reenviar, o de mandarlo a otro número.
    /// </summary>
    Task<ComprobanteResponse> EnviarAsync(int comprobanteId, string? telefono);

    /// <summary>
    /// Envío automático al aceptarse el comprobante. Solo si la empresa lo tiene activado y todavía no se mandó. Nunca
    /// lanza: la emisión ya terminó bien y un fallo de WhatsApp no debe tumbarla.
    /// </summary>
    Task EnviarAutomaticoAsync(int comprobanteId);

    /// <summary>El estado del servicio de WhatsApp, con el QR de vinculación como imagen si está esperando uno.</summary>
    Task<EstadoWhatsAppResponse> EstadoAsync();

    Task<bool> DesvincularAsync();
}

public class EstadoWhatsAppResponse
{
    /// <summary>conectado, esperando-qr, desconectado o sin-servicio.</summary>
    public string Estado { get; set; } = string.Empty;

    public int EnCola { get; set; }

    /// <summary>El QR a escanear con el celular de la empresa, como imagen (data URL). Nulo si no hace falta.</summary>
    public string? QrImagen { get; set; }

    public string? Error { get; set; }

    /// <summary>Falta el token en la configuración del servidor: sin él no se puede enviar.</summary>
    public bool FaltaToken { get; set; }
}
