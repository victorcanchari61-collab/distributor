namespace Backend.Models;

/// <summary>
/// Los tipos de comprobante de pago electrónico (Catálogo 01 de SUNAT) que se emiten: factura, boleta y las
/// notas que las corrigen.
/// </summary>
public static class TipoCpe
{
    public const string Factura = "01";
    public const string Boleta = "03";
    public const string NotaCredito = "07";
    public const string NotaDebito = "08";

    public static readonly string[] Todos = [Factura, Boleta, NotaCredito, NotaDebito];

    public static bool EsNota(string tipo) => tipo is NotaCredito or NotaDebito;

    public static string Nombre(string tipo) => tipo switch
    {
        Factura => "Factura electrónica",
        Boleta => "Boleta de venta electrónica",
        NotaCredito => "Nota de crédito electrónica",
        NotaDebito => "Nota de débito electrónica",
        _ => tipo,
    };

    /// <summary>El submódulo de permisos de cada tipo (los mismos ids del menú).</summary>
    public static string Submodulo(string tipo) => tipo switch
    {
        Factura => "fact.facturas",
        Boleta => "fact.boletas",
        NotaCredito => "fact.notascredito",
        NotaDebito => "fact.notasdebito",
        _ => throw new ArgumentOutOfRangeException(nameof(tipo), tipo, "Tipo de comprobante desconocido"),
    };

    /// <summary>La palabra con la que la API de facturación llama a cada tipo.</summary>
    public static string ParaApi(string tipo) => tipo switch
    {
        Factura => "factura",
        Boleta => "boleta",
        NotaCredito => "credito",
        NotaDebito => "debito",
        _ => tipo,
    };
}

/// <summary>En qué quedó un comprobante frente a SUNAT.</summary>
public static class EstadoCpe
{
    /// <summary>El XML está firmado pero todavía no llegó a SUNAT (o no se supo si llegó).</summary>
    public const string Generado = "GENERADO";

    /// <summary>SUNAT lo aceptó: hay CDR.</summary>
    public const string Aceptado = "ACEPTADO";

    /// <summary>SUNAT lo rechazó (códigos 2000 a 3999): hay CDR con el motivo.</summary>
    public const string Rechazado = "RECHAZADO";

    /// <summary>El envío falló antes de tener respuesta (red, caída de SUNAT): se puede reintentar.</summary>
    public const string Error = "ERROR";
}

/// <summary>En qué quedó el envío por WhatsApp de un comprobante.</summary>
public static class EstadoWhatsApp
{
    /// <summary>El servicio de WhatsApp lo aceptó y lo manda en su turno (entre mensajes hay una pausa de unos segundos).</summary>
    public const string Encolado = "ENCOLADO";

    /// <summary>No se pudo entregar al servicio (caído, sin vincular, teléfono inválido): se puede reintentar.</summary>
    public const string Error = "ERROR";

    /// <summary>El cliente no tiene teléfono: se puede mandar escribiendo uno.</summary>
    public const string SinTelefono = "SIN_TELEFONO";
}

/// <summary>
/// Una serie de comprobantes y su correlativo. Las series de las notas dependen de lo que corrigen: SUNAT exige
/// que empiecen con F si corrigen una factura y con B si corrigen una boleta (FF01, BB01).
/// </summary>
public class SerieCpe
{
    public int Id { get; set; }

    /// <summary>La empresa dueña de la serie: cada RUC lleva sus propias series y su numeración.</summary>
    public int EmpresaId { get; set; }
    public Empresa? Empresa { get; set; }

    /// <summary>01, 03, 07 u 08.</summary>
    public string Tipo { get; set; } = TipoCpe.Factura;

    /// <summary>Cuatro caracteres: F001, B001, FF01, BB01.</summary>
    public string Serie { get; set; } = string.Empty;

    /// <summary>Solo para notas: el tipo del comprobante que corrigen (01 o 03). Nulo en factura y boleta.</summary>
    public string? AplicaA { get; set; }

    /// <summary>
    /// El último número usado. El siguiente es este más uno. Se puede fijar a mano: quien ya venía facturando con
    /// otro sistema continúa desde donde iba.
    /// </summary>
    public int UltimoNumero { get; set; }

    public bool Activa { get; set; } = true;
}

/// <summary>
/// Un comprobante electrónico emitido: lo que se mandó, el XML firmado y lo que SUNAT respondió (el CDR).
///
/// Se guarda copia de los datos del cliente y de las líneas tal como salieron: un comprobante emitido no cambia
/// aunque después se edite el cliente o el producto.
/// </summary>
public class ComprobanteElectronico
{
    public int Id { get; set; }

    public string Tipo { get; set; } = TipoCpe.Factura;
    public string Serie { get; set; } = string.Empty;
    public int Numero { get; set; }

    /// <summary>F001-10: como se nombra en la pantalla.</summary>
    public string NumeroCompleto => $"{Serie}-{Numero}";

    /// <summary>La venta de la que sale. Nula en una nota de crédito o débito, que cuelga de otro comprobante.</summary>
    public int? NotaVentaId { get; set; }
    public NotaVenta? NotaVenta { get; set; }

    /// <summary>Solo en notas: el comprobante que corrigen.</summary>
    public int? AfectadoId { get; set; }
    public ComprobanteElectronico? Afectado { get; set; }

    /// <summary>El día de emisión (hora de Perú, sin hora).</summary>
    public DateTime FechaEmision { get; set; }

    // --- El cliente, como salió ---
    public int? ClienteId { get; set; }

    /// <summary>1 DNI, 6 RUC, 0 sin documento (Catálogo 06 de SUNAT).</summary>
    public string ClienteTipoDoc { get; set; } = "0";

    public string ClienteDocumento { get; set; } = "-";
    public string ClienteNombre { get; set; } = string.Empty;
    public string? ClienteDireccion { get; set; }

    public string Moneda { get; set; } = "PEN";
    public decimal OpGravada { get; set; }
    public decimal OpExonerada { get; set; }
    public decimal Igv { get; set; }
    public decimal Total { get; set; }

    // --- Solo en notas ---
    /// <summary>Catálogo 09 (crédito) o 10 (débito) de SUNAT: 01 anulación de la operación, etc.</summary>
    public string? CodMotivo { get; set; }

    public string? DesMotivo { get; set; }

    /// <summary>Las líneas que salieron, en JSON: de ahí se arma una nota de crédito sin volver a la venta.</summary>
    public string DetalleJson { get; set; } = "[]";

    // --- Respuesta de SUNAT ---
    public string Estado { get; set; } = EstadoCpe.Generado;

    /// <summary>El código del CDR: 0 aceptado, 2xxx-3xxx rechazado, 4xxx aceptado con observaciones.</summary>
    public string? CodigoSunat { get; set; }

    public string? MensajeSunat { get; set; }

    /// <summary>Notas (observaciones) que SUNAT devolvió con el CDR, separadas por salto de línea.</summary>
    public string? NotasSunat { get; set; }

    // --- Lo que se descarga ---
    /// <summary>10706671817-01-F001-10: el nombre de los archivos (sin extensión).</summary>
    public string NombreArchivo { get; set; } = string.Empty;

    public string Hash { get; set; } = string.Empty;

    /// <summary>Lo que va en el código QR de la representación impresa.</summary>
    public string QrInfo { get; set; } = string.Empty;

    /// <summary>El XML firmado, tal cual salió de la firma.</summary>
    public string XmlFirmado { get; set; } = string.Empty;

    /// <summary>El zip del CDR (constancia de recepción). Nulo mientras SUNAT no responda.</summary>
    public byte[]? CdrZip { get; set; }

    /// <summary>beta (pruebas) o produccion.</summary>
    public string Entorno { get; set; } = "beta";

    public int? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    /// <summary>
    /// Lo que va en el enlace público del comprobante: 32 caracteres aleatorios, no el número (que es de dominio
    /// público y se adivina). Quien tiene el enlace baja el PDF; nada más.
    /// </summary>
    public string TokenPublico { get; set; } = Guid.NewGuid().ToString("N");

    // --- Envío por WhatsApp ---

    /// <summary>Nulo: nunca se mandó. Ver <see cref="EstadoWhatsApp"/>.</summary>
    public string? WhatsAppEstado { get; set; }

    /// <summary>A qué número se mandó la última vez.</summary>
    public string? WhatsAppTelefono { get; set; }

    public DateTime? WhatsAppEnviadoEn { get; set; }
    public string? WhatsAppError { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;

    /// <summary>Cuándo se mandó por última vez a SUNAT.</summary>
    public DateTime? EnviadoEn { get; set; }
}
