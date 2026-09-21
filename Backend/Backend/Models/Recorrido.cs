namespace Backend.Models;

/// <summary>
/// Qué rutas recorre un vehículo cada día de la semana.
///
/// Una fila por vehículo, día y ruta: el camión 1 los lunes con las rutas 1 y 7 son dos filas. Es el
/// dato que el sistema anterior tenía escrito en el código (camión → día → rutas) y que aquí se edita
/// desde la pantalla, porque cambia cuando el negocio cambia sus salidas y nadie debería necesitar un
/// programador para moverle una ruta al martes.
///
/// Solo PROPONE: al armar un despacho las rutas se llenan desde aquí, pero se pueden corregir para ese
/// día concreto.
/// </summary>
public class RecorridoVehiculo
{
    public int Id { get; set; }

    public int VehiculoId { get; set; }
    public Vehiculo? Vehiculo { get; set; }

    /// <summary>LUNES … DOMINGO, tal como <see cref="DiaSemana"/>.</summary>
    public string Dia { get; set; } = string.Empty;

    public int RutaId { get; set; }
    public Ruta? Ruta { get; set; }
}
