namespace Backend.Dtos.Responses;

/// <summary>Una próxima acción de seguimiento que sigue abierta.</summary>
public class CrmTareaResponse
{
    /// <summary>La gestión que dejó anotada esta acción.</summary>
    public int GestionId { get; set; }

    public int ClienteId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Cliente { get; set; } = string.Empty;
    public string? Telefono { get; set; }
    public string? Mercado { get; set; }
    public string? Ruta { get; set; }

    /// <summary>Qué hay que hacer.</summary>
    public string Accion { get; set; } = string.Empty;

    /// <summary>El día en que toca.</summary>
    public DateTime Fecha { get; set; }

    /// <summary>VENCIDA, HOY o PROXIMA.</summary>
    public string Estado { get; set; } = string.Empty;

    /// <summary>Cuántos días lleva vencida (0 si no lo está).</summary>
    public int DiasAtraso { get; set; }

    /// <summary>Lo que se habló cuando se anotó esta acción.</summary>
    public string Nota { get; set; } = string.Empty;

    public string Tipo { get; set; } = string.Empty;
    public string Resultado { get; set; } = string.Empty;

    /// <summary>Quién la anotó.</summary>
    public string? RegistradaPor { get; set; }
}

public class CrmAgendaResumenResponse
{
    public int Vencidas { get; set; }
    public int Hoy { get; set; }
    public int Proximas { get; set; }

    /// <summary>El día de la acción vencida más antigua, si hay alguna.</summary>
    public DateTime? VencidaDesde { get; set; }
}

public class CrmAgendaResponse
{
    /// <summary>mias o todas.</summary>
    public string Quien { get; set; } = string.Empty;

    /// <summary>Quien pregunta ve solo parte de la cartera (según su alcance).</summary>
    public bool SoloPropios { get; set; }

    /// <summary>De todas las acciones de "quien", antes de elegir un estado.</summary>
    public CrmAgendaResumenResponse Resumen { get; set; } = new();

    /// <summary>Primero las vencidas (la más atrasada arriba), luego hoy y después las próximas.</summary>
    public List<CrmTareaResponse> Items { get; set; } = [];
}
