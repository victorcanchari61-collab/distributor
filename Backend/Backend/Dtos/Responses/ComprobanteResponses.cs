namespace Backend.Dtos.Responses;

/// <summary>Un comprobante electrónico para la lista y la ficha. No lleva el XML ni el CDR: esos se descargan.</summary>
public class ComprobanteResponse
{
    public int Id { get; set; }
    public string Tipo { get; set; } = string.Empty;
    public string TipoNombre { get; set; } = string.Empty;
    public string Serie { get; set; } = string.Empty;
    public int Numero { get; set; }
    public string NumeroCompleto { get; set; } = string.Empty;

    public int? NotaVentaId { get; set; }
    public string? NotaVentaNumero { get; set; }

    /// <summary>En una nota: el comprobante que corrige.</summary>
    public int? AfectadoId { get; set; }

    public string? AfectadoNumero { get; set; }

    public DateTime FechaEmision { get; set; }
    public string ClienteTipoDoc { get; set; } = string.Empty;
    public string ClienteDocumento { get; set; } = string.Empty;
    public string ClienteNombre { get; set; } = string.Empty;
    public string Moneda { get; set; } = string.Empty;
    public decimal OpGravada { get; set; }
    public decimal OpExonerada { get; set; }
    public decimal Igv { get; set; }
    public decimal Total { get; set; }

    public string? CodMotivo { get; set; }
    public string? DesMotivo { get; set; }

    public string Estado { get; set; } = string.Empty;
    public string? CodigoSunat { get; set; }
    public string? MensajeSunat { get; set; }
    public string? NotasSunat { get; set; }
    public string NombreArchivo { get; set; } = string.Empty;
    public string Hash { get; set; } = string.Empty;
    public string QrInfo { get; set; } = string.Empty;

    /// <summary>Hay constancia de recepción (CDR) para descargar.</summary>
    public bool TieneCdr { get; set; }

    public string Entorno { get; set; } = string.Empty;
    public string? Usuario { get; set; }
    public DateTime FechaCreacion { get; set; }
    public DateTime? EnviadoEn { get; set; }

    /// <summary>Las líneas con las que salió: de ahí se arma una nota de crédito.</summary>
    public List<LineaComprobanteResponse> Lineas { get; set; } = [];
}

public class LineaComprobanteResponse
{
    public string Descripcion { get; set; } = string.Empty;
    public decimal Cantidad { get; set; }
    public decimal Precio { get; set; }
    public bool AfectoIgv { get; set; }
}

public class SerieCpeResponse
{
    public int Id { get; set; }
    public string Tipo { get; set; } = string.Empty;
    public string Serie { get; set; } = string.Empty;
    public string? AplicaA { get; set; }
    public int UltimoNumero { get; set; }
    public bool Activa { get; set; }
}
