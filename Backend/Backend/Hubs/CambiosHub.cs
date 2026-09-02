using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Backend.Hubs;

/// <summary>
/// El canal de tiempo real: cuando alguien cambia algo en una PC, el resto de
/// PCs conectadas se enteran solas, sin recargar la página.
///
/// No hay grupos por tenant: este sistema opera con una sola empresa a la vez
/// (Empresa.Activa es única en toda la base), así que todo el que esta
/// conectado es del mismo negocio. Si el dia de mañana el sistema se vuelve
/// multi-tenant, ahi si hace falta separar por grupo — ver
/// docs/signalr-multitenant.md.
///
/// El Hub en si no expone metodos: solo recibe conexiones. Los avisos salen
/// del servidor hacia el cliente por <see cref="Backend.Service.Implementacion.NotificadorHub"/>,
/// nunca al reves.
/// </summary>
[Authorize]
public class CambiosHub : Hub;
