namespace Backend.Models;

/// <summary>
/// La persona que trabaja en el negocio: el repartidor, el de almacén, el vendedor.
///
/// Es un MAESTRO y no una cuenta de acceso. Existe aunque nunca entre al sistema —el estibador no
/// necesita usuario— y se conserva cuando deja de trabajar (se desactiva, con su fecha de cese),
/// porque los documentos que registró siguen apuntando a él.
///
/// Quien además usa el sistema tiene un <see cref="Usuario"/> enlazado a su ficha, pero ese enlace
/// es opcional en los dos sentidos: hay empleados sin usuario, y usuarios sin empleado (el de
/// soporte, la cuenta del dueño).
/// </summary>
public class Empleado
{
    public int Id { get; set; }

    /// <summary>DNI casi siempre; un código interno si es extranjero sin DNI. No se repite.</summary>
    public string Documento { get; set; } = string.Empty;

    /// <summary>DNI o CODIGO. Ver <see cref="TipoDocumento"/>.</summary>
    public string TipoDoc { get; set; } = TipoDocumento.Dni;

    public string Nombres { get; set; } = string.Empty;
    public string Apellidos { get; set; } = string.Empty;

    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? Direccion { get; set; }

    /// <summary>Qué hace: "Repartidor", "Vendedor", "Almacenero". Texto libre: cada negocio los llama a su manera.</summary>
    public string? Cargo { get; set; }

    /// <summary>Dónde: "Reparto", "Almacén", "Ventas".</summary>
    public string? Area { get; set; }

    public DateTime? FechaIngreso { get; set; }

    /// <summary>Cuándo dejó de trabajar. Con fecha de cese la ficha queda como histórico.</summary>
    public DateTime? FechaCese { get; set; }

    /// <summary>Lo que cobra por una semana completa (lunes a sábado). Sin sueldo no entra en la planilla.</summary>
    public decimal? SueldoSemanal { get; set; }

    public string? Observacion { get; set; }

    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    /// <summary>"Juan Carlos Quispe Mamani", que es como se lo nombra en una lista.</summary>
    public string NombreCompleto => $"{Nombres} {Apellidos}".Trim();
}
