namespace Backend.Service.Interfaces;

/// <summary>
/// Avisa a las demás PCs conectadas que algo cambió, para que actualicen su
/// pantalla solas.
///
/// Cada servicio lo llama DESPUÉS de guardar con éxito — nunca antes, porque
/// si la escritura falla no hay nada que avisar. Es "olvida y sigue": si el
/// aviso en si fallara (nadie conectado, por ejemplo) no debe tumbar la
/// operación que sí se guardó.
/// </summary>
public interface INotificador
{
    /// <summary>Avisa que algo cambió en un módulo.</summary>
    /// <param name="modulo">
    /// La pantalla a la que le importa: "clientes", "productos", "stock"...
    /// El frontend se suscribe por este nombre para saber cuándo recargar.
    /// </param>
    /// <param name="accion">Qué pasó: "creado", "actualizado", "eliminado", "estado"...</param>
    /// <param name="datos">
    /// Opcional. Lo mínimo para que el frontend actualice sin pedir de nuevo
    /// toda la lista, cuando tiene sentido (un id, la fila completa).
    /// </param>
    Task AvisarAsync(string modulo, string accion, object? datos = null);
}
