namespace Backend.Dtos.Requests;

public abstract class AlmacenRequestBase
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
}

public class CreateAlmacenRequest : AlmacenRequestBase;

public class UpdateAlmacenRequest : AlmacenRequestBase
{
    public bool Activo { get; set; } = true;
}

public abstract class MotivoRequestBase
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    /// <summary>ENTRADA o SALIDA.</summary>
    public string Tipo { get; set; } = string.Empty;
}

public class CreateMotivoRequest : MotivoRequestBase;

public class UpdateMotivoRequest : MotivoRequestBase
{
    public bool Activo { get; set; } = true;
}

/// <summary>Una línea del ajuste.</summary>
public class LineaAjusteRequest
{
    public int ProductoId { get; set; }

    /// <summary>En qué presentación se cuenta. Vacío significa unidad base.</summary>
    public int? PresentacionId { get; set; }

    /// <summary>Cuántas presentaciones. Siempre positiva: el signo lo da el motivo.</summary>
    public decimal Cantidad { get; set; }

    /// <summary>
    /// Lo que costó UNA presentación completa: el saco entero, no el kilo.
    /// Solo se usa en motivos de entrada; en las salidas el costo lo hereda
    /// del stock que sale.
    /// </summary>
    public decimal? CostoPresentacion { get; set; }
}

/// <summary>Ajuste de inventario: el documento formal con su motivo.</summary>
public class CrearAjusteRequest
{
    public int AlmacenId { get; set; }
    public int MotivoId { get; set; }
    public DateTime? Fecha { get; set; }
    public string? Observacion { get; set; }

    /// <summary>Flete o gastos de toda la entrada, repartidos entre las líneas.</summary>
    public decimal Flete { get; set; }

    public List<LineaAjusteRequest> Detalle { get; set; } = [];
}
