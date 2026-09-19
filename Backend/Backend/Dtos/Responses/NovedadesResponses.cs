namespace Backend.Dtos.Responses;

public class MotivoNovedadResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }

    /// <summary>Salió en el camión y hay que esperarlo de vuelta.</summary>
    public bool RegresaAlAlmacen { get; set; }

    public bool Activo { get; set; }

    /// <summary>En cuántas novedades se usó: si hay alguna, solo se desactiva.</summary>
    public int Usos { get; set; }
}

/// <summary>Lo justo para elegir el motivo al entregar: sin contadores ni los desactivados.</summary>
public class MotivoNovedadOpcionResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
}
