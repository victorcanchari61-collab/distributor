# SignalR en tiempo real con aislamiento por tenant

Decisión sobre cómo notificar cambios en vivo en una plataforma multi-tenant, y
cuándo hace falta un backplane de Redis.

## Resumen

**Groups por tenant: sí, desde el día uno.** Es arquitectura, no infraestructura,
y cuesta más cambiarlo después que ponerlo desde el inicio.

**Redis backplane: no necesariamente desde el día uno.** Depende de cómo se
despliegue. Se agrega después sin tocar la lógica de negocio.

## Groups por tenant

La combinación SignalR + Groups por tenant se recomienda siempre en este caso,
se necesite escalar horizontalmente o no.

Al conectar, se mete la conexión en el grupo de su tenant:

```csharp
public override async Task OnConnectedAsync()
{
    var tenantId = Context.User?.FindFirst("tenant_id")?.Value;
    await Groups.AddToGroupAsync(Context.ConnectionId, $"tenant-{tenantId}");
    await base.OnConnectedAsync();
}
```

Y las notificaciones se emiten solo a ese grupo:

```csharp
await _hub.Clients.Group($"tenant-{product.TenantId}")
    .SendAsync("ProductCreated", product);
```

Así se garantiza aislamiento entre tenants a nivel de mensajería en tiempo real,
que para una plataforma multi-tenant es básicamente obligatorio: no se quiere ni
por accidente que un evento de un tenant le llegue a otro.

## Redis backplane: depende del despliegue

| Escenario | ¿Necesitas Redis backplane? |
|---|---|
| Un solo servidor/instancia del backend | No — SignalR maneja los grupos en memoria, funciona perfecto |
| Múltiples instancias (load balancer, Kubernetes con varios pods, escalado horizontal) | Sí — sin esto, un usuario conectado al pod A no recibe eventos generados en el pod B |
| Azure App Service con auto-scaling | Sí, o alternativamente Azure SignalR Service (managed, evita correr Redis uno mismo) |

## Plan práctico

Estando en fase de construcción de la plataforma:

1. **Ahora:** implementar Groups por tenant.
2. **Después:** dejar el backplane de Redis para cuando se defina cómo se
   despliega en producción. Si se termina con múltiples instancias, se agrega
   sin tocar la lógica de negocio — solo una línea en `Program.cs`:

```csharp
builder.Services.AddSignalR().AddStackExchangeRedis("redis-connection-string");
```
