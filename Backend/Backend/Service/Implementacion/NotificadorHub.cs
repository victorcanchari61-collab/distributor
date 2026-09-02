using Backend.Hubs;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.SignalR;

namespace Backend.Service.Implementacion;

/// <summary>
/// Empuja el aviso por SignalR a todas las PCs conectadas.
///
/// El evento se llama "cambio" en minuscula porque el cliente JS lo escucha
/// tal cual: connection.on("cambio", ...). Cambiar el nombre aqui rompe el
/// frontend si no se cambia alla tambien.
/// </summary>
public class NotificadorHub : INotificador
{
    private readonly IHubContext<CambiosHub> _hub;

    public NotificadorHub(IHubContext<CambiosHub> hub)
    {
        _hub = hub;
    }

    public async Task AvisarAsync(string modulo, string accion, object? datos = null)
    {
        try
        {
            await _hub.Clients.All.SendAsync("cambio", new
            {
                modulo,
                accion,
                datos,
                fecha = DateTime.UtcNow
            });
        }
        catch
        {
            // El aviso es informativo: si SignalR no pudo entregarlo (nadie
            // conectado, un cliente se cayo a mitad de envio), la operacion
            // que SI se guardo en la base no debe fallar por esto.
        }
    }
}
