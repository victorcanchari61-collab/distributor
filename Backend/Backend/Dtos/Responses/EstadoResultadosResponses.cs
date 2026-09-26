namespace Backend.Dtos.Responses;

/// <summary>
/// Si el negocio gana en un rango de fechas: lo vendido menos lo que costó,
/// menos los gastos de operar. Lo no operativo (préstamos, aportes, retiros)
/// va aparte y no suma a la utilidad.
/// </summary>
public class EstadoResultadosResponse
{
    public DateTime Desde { get; set; }
    public DateTime Hasta { get; set; }

    /// <summary>Lo cobrado en las ventas del rango, con IGV y con los recojos restados.</summary>
    public decimal VentasBrutas { get; set; }
    public decimal Igv { get; set; }

    /// <summary>Las ventas sin IGV: el ingreso real.</summary>
    public decimal VentasNetas { get; set; }

    /// <summary>Lo que costó la mercadería que salió.</summary>
    public decimal CostoVentas { get; set; }

    public decimal UtilidadBruta { get; set; }
    public decimal? MargenBruto { get; set; }

    public List<LineaResultadoResponse> OtrosIngresos { get; set; } = [];
    public decimal TotalOtrosIngresos { get; set; }

    public List<LineaResultadoResponse> GastosOperativos { get; set; } = [];
    public decimal TotalGastosOperativos { get; set; }

    /// <summary>Utilidad bruta + otros ingresos operativos − gastos operativos.</summary>
    public decimal UtilidadOperativa { get; set; }
    public decimal? MargenOperativo { get; set; }

    /// <summary>Informativo: no suma a la utilidad.</summary>
    public List<LineaResultadoResponse> IngresosNoOperativos { get; set; } = [];
    public decimal TotalIngresosNoOperativos { get; set; }
    public List<LineaResultadoResponse> EgresosNoOperativos { get; set; } = [];
    public decimal TotalEgresosNoOperativos { get; set; }

    /// <summary>Cuántas notas de venta entraron.</summary>
    public int Ventas { get; set; }

    /// <summary>Líneas vendidas sin costo: ahí la utilidad sale inflada.</summary>
    public int LineasSinCosto { get; set; }
}

/// <summary>Un renglón del estado: una categoría con lo que sumó.</summary>
public class LineaResultadoResponse
{
    public string Concepto { get; set; } = string.Empty;
    public decimal Monto { get; set; }

    /// <summary>Cuántos movimientos la forman.</summary>
    public int Movimientos { get; set; }
}
