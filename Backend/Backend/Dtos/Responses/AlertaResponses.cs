namespace Backend.Dtos.Responses;

public static class SeveridadAlerta
{
    public const string Critica = "CRITICA";
    public const string Advertencia = "ADVERTENCIA";

    /// <summary>Buena noticia, no algo por corregir: llegó mercadería.</summary>
    public const string Info = "INFO";
}

public static class TipoAlerta
{
    public const string StockBajo = "STOCK_BAJO";
    public const string LotePorVencer = "LOTE_POR_VENCER";
    public const string CompraPendiente = "COMPRA_PENDIENTE";
    public const string CreditoPendiente = "CREDITO_PENDIENTE";
    public const string ReservaVencida = "RESERVA_VENCIDA";

    /// <summary>Entró mercadería nueva o se repuso stock: para que ventas sepa que ya puede ofrecerlo.</summary>
    public const string StockRepuesto = "STOCK_REPUESTO";
}

/// <summary>
/// Algo que conviene que alguien mire: no se guarda en ningún lado, se calcula
/// al vuelo cada vez que se pide — así nunca queda desactualizada ni hay que
/// marcarla como leída.
/// </summary>
public class AlertaResponse
{
    public string Id { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;
    public string Severidad { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public string Detalle { get; set; } = string.Empty;

    /// <summary>Id de vista del menú web ("inv.stock") para navegar al hacer clic.</summary>
    public string? Ruta { get; set; }

    public DateTime? Fecha { get; set; }
}
