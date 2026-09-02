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

/// <summary>
/// Entrada de mercadería con su costo. Sirve para el saldo inicial y, más
/// adelante, para cada recepción de compra.
/// </summary>
public class EntradaRequest
{
    public int ProductoId { get; set; }

    /// <summary>Vacío usa el almacén principal.</summary>
    public int? AlmacenId { get; set; }

    /// <summary>
    /// En qué presentación entró: un saco, una caja. Vacío significa que la
    /// cantidad ya viene en unidad base.
    /// </summary>
    public int? PresentacionId { get; set; }

    /// <summary>Cuántas presentaciones (o unidades base si no se indicó una).</summary>
    public decimal Cantidad { get; set; }

    /// <summary>
    /// Lo que costó UNA presentación completa: el saco entero, no el kilo. El
    /// backend lo divide entre el factor para guardar el costo por unidad base.
    /// </summary>
    public decimal CostoTotal { get; set; }

    /// <summary>Flete de toda la entrada. Se reparte entre lo que entró.</summary>
    public decimal Flete { get; set; }

    public string? Referencia { get; set; }

    /// <summary>
    /// SALDO_INICIAL para lo que ya había el día que arrancó el sistema,
    /// COMPRA para una recepción, AJUSTE para una corrección de inventario.
    /// </summary>
    public string Origen { get; set; } = "COMPRA";

    /// <summary>Vacío usa la fecha de hoy.</summary>
    public DateTime? Fecha { get; set; }
}

/// <summary>Salida de mercadería: consume las capas más antiguas primero.</summary>
public class SalidaRequest
{
    public int ProductoId { get; set; }
    public int? AlmacenId { get; set; }
    public int? PresentacionId { get; set; }
    public decimal Cantidad { get; set; }
    public string? Referencia { get; set; }
}
