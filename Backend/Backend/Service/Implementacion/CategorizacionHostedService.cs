using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// Revisa cada pocas horas si empezó un ciclo nuevo y, si es así, recalcula la categoría de los
/// clientes. Es lo que hace que el resultado cambie solo el día que dice la pantalla de
/// Categorización (el 1 de enero, en un ciclo trimestral que va de octubre a diciembre).
///
/// No arranca nada por su cuenta: mientras nadie haya calculado la primera vez desde la pantalla,
/// no hace nada. Y cualquier fallo se anota y se reintenta a la siguiente vuelta: un error aquí nunca
/// debe tumbar la API.
/// </summary>
public class CategorizacionHostedService : BackgroundService
{
    private static readonly TimeSpan Cada = TimeSpan.FromHours(6);

    /// <summary>Un respiro al arrancar: que la API termine de levantar antes de consultar nada.</summary>
    private static readonly TimeSpan Espera = TimeSpan.FromSeconds(45);

    private readonly IServiceScopeFactory _scopes;
    private readonly ILogger<CategorizacionHostedService> _log;

    public CategorizacionHostedService(IServiceScopeFactory scopes, ILogger<CategorizacionHostedService> log)
    {
        _scopes = scopes;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await Task.Delay(Espera, stoppingToken);

            using var reloj = new PeriodicTimer(Cada);
            do
            {
                await RevisarAsync(stoppingToken);
            }
            while (await reloj.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException)
        {
            // La API se está apagando.
        }
    }

    private async Task RevisarAsync(CancellationToken cancelacion)
    {
        try
        {
            // Un scope por vuelta: los servicios usan el DbContext, que es por petición.
            using var scope = _scopes.CreateScope();
            var servicio = scope.ServiceProvider.GetRequiredService<ICategorizacionService>();

            if (await servicio.CalcularSiCorrespondeAsync())
                _log.LogInformation("Categorización de clientes recalculada por cambio de ciclo.");
        }
        catch (Exception ex) when (!cancelacion.IsCancellationRequested)
        {
            // Típico antes de aplicar la migración: la tabla todavía no existe.
            _log.LogWarning(ex, "No se pudo revisar la categorización de clientes; se reintenta más tarde.");
        }
    }
}
