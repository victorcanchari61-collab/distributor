using Backend.Dtos.Responses;

namespace Backend.Service.Pdf;

/// <summary>Una línea de la tabla, ya resuelta: sin ids ni nada que el papel no muestre.</summary>
public sealed record LineaImprimible(
    string Codigo,
    string Producto,
    string? Presentacion,
    decimal Cantidad,
    string Unidad,
    decimal PrecioUnitario,
    decimal Importe);

/// <summary>Con qué se pagó y cuánto.</summary>
public sealed record PagoImprimible(string Metodo, decimal Monto);

/// <summary>Un dato suelto de la cabecera: "Forma de pago" → "Contado".</summary>
public sealed record DatoImprimible(string Etiqueta, string Valor);

/// <summary>
/// Un documento listo para imprimir, sin saber si es una venta o una compra.
///
/// Existe para no escribir ocho maquetaciones. Son cuatro documentos (pedido,
/// nota de venta, orden de compra, compra) por dos formatos (A4 y ticket), y
/// sin esta forma común cada combinación sería una plantilla propia: ocho
/// sitios donde corregir el mismo margen. Con esto son dos plantillas que
/// reciben esto mismo, y cuatro traducciones cortas que lo rellenan.
///
/// La diferencia real entre los cuatro es menor de lo que parece: a quién va
/// dirigido (cliente o proveedor), cómo se llama la columna del importe
/// (precio o costo) y si lleva pagos. Todo eso son campos de aquí, no ramas
/// dentro del dibujo.
/// </summary>
public sealed record DocumentoImprimible
{
    /// <summary>Lo que se lee arriba: "NOTA DE VENTA".</summary>
    public required string Titulo { get; init; }

    public required string Numero { get; init; }
    public required DateTime Fecha { get; init; }

    /// <summary>Si está anulado, el papel lo dice; si no, no se pinta nada.</summary>
    public bool Anulado { get; init; }

    /// <summary>"Cliente" o "Proveedor": el papel no habla de "la parte".</summary>
    public required string EtiquetaParte { get; init; }

    public required string ParteNombre { get; init; }
    public string? ParteDocumento { get; init; }
    public string? ParteDireccion { get; init; }
    public string? ParteTelefono { get; init; }

    /// <summary>Datos de cabecera propios de cada documento: almacén, forma de pago...</summary>
    public IReadOnlyList<DatoImprimible> Datos { get; init; } = [];

    /// <summary>"Precio" en una venta, "Costo" en una compra.</summary>
    public required string EtiquetaImporte { get; init; }

    /// <summary>
    /// Si la tabla lleva la columna del código del producto.
    ///
    /// El pedido no la lleva: lo firma el cliente en su puesto del mercado, y
    /// el código es nuestro — a él no le dice nada y le come el ancho de la
    /// descripción, que es lo único que sí reconoce. En los demás documentos
    /// sí está, porque los lee gente de la casa o el proveedor, que trabajan
    /// con ese código.
    /// </summary>
    public bool MostrarCodigo { get; init; } = true;

    public IReadOnlyList<LineaImprimible> Lineas { get; init; } = [];
    public decimal Total { get; init; }

    /// <summary>
    /// Desglose del IGV: Op. Gravada + Igv + Op. Exonerada = Total. Solo una
    /// nota de venta lo trae — los demás documentos lo dejan en cero y el
    /// papel no pinta esta fila.
    /// </summary>
    public decimal OpGravada { get; init; }
    public decimal Igv { get; init; }
    public decimal OpExonerada { get; init; }

    /// <summary>Vacío en un pedido y en una orden: ahí todavía no se paga nada.</summary>
    public IReadOnlyList<PagoImprimible> Pagos { get; init; } = [];

    public decimal TotalPagado { get; init; }
    public decimal Saldo => Total - TotalPagado;

    public string? Observacion { get; init; }
    public string? Usuario { get; init; }

    /// <summary>El celular de quien atendió: va como dato aparte, no pegado al nombre.</summary>
    public string? UsuarioTelefono { get; init; }

    /// <summary>
    /// Cómo se llama en el papel quien registró el documento.
    ///
    /// "VENDEDOR" en una venta, donde esa persona es la que atendió y a quien
    /// se le reclama. En un ajuste o una transferencia no hay vendedor ninguno:
    /// hay quien lo registró, y llamarlo vendedor es decir algo falso.
    /// </summary>
    public string EtiquetaUsuario { get; init; } = "REGISTRÓ";

    public required EmpresaResponse Empresa { get; init; }

    /// <summary>
    /// false cuando la fecha no trae hora real (un comprobante electrónico se emite en un día, no a una hora): el
    /// papel muestra solo el día en vez de un "00:00" que no significa nada.
    /// </summary>
    public bool FechaConHora { get; init; } = true;

    /// <summary>
    /// Franjas rojas bajo el membrete: lo que le quita validez al papel (documento de prueba, rechazado por SUNAT,
    /// sin respuesta todavía).
    /// </summary>
    public IReadOnlyList<string> Avisos { get; init; } = [];

    // --- Solo en un comprobante electrónico ---

    /// <summary>Lo que lleva el código QR (formato de SUNAT). Nulo en los demás documentos: no se dibuja nada.</summary>
    public string? QrTexto { get; init; }

    /// <summary>El resumen (hash) de la firma del XML.</summary>
    public string? Hash { get; init; }

    /// <summary>La leyenda de "representación impresa" y dónde consultar su validez.</summary>
    public string? PieLegal { get; init; }

    public string FechaTexto => Fecha.ToString(FechaConHora ? "dd/MM/yyyy HH:mm" : "dd/MM/yyyy");
}
