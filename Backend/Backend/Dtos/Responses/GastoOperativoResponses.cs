namespace Backend.Dtos.Responses;

public class CategoriaMovimientoResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public string Tipo { get; set; } = string.Empty;
    public string Origen { get; set; } = string.Empty;
    public bool Activo { get; set; }

    /// <summary>La registra el sistema solo: no se edita, no se borra, no se elige a mano.</summary>
    public bool EsSistema { get; set; }

    /// <summary>En cuántos movimientos, plantillas o cuadres se usa. Si hay alguno, no se elimina.</summary>
    public int Usos { get; set; }
}

/// <summary>Lo justo para elegir una categoría al registrar un ingreso o egreso.</summary>
public class CategoriaOpcionResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;
    public string Origen { get; set; } = string.Empty;
}

public class GastoRecurrenteResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int MotivoGastoId { get; set; }
    public string MotivoGasto { get; set; } = string.Empty;
    public decimal MontoEstimado { get; set; }
    public int DiaVencimiento { get; set; }
    public int? CuentaFinancieraSugeridaId { get; set; }
    public string? CuentaFinancieraSugerida { get; set; }
    public bool Activo { get; set; }
}

/// <summary>Una plantilla recurrente que este mes todavía no tiene su pago registrado.</summary>
public class GastoPendienteResponse
{
    public int GastoRecurrenteId { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int MotivoGastoId { get; set; }
    public string MotivoGasto { get; set; } = string.Empty;
    public decimal MontoEstimado { get; set; }
    public int? CuentaFinancieraSugeridaId { get; set; }
    public DateTime ProximoVencimiento { get; set; }
    public bool Vencido { get; set; }
}

public class MovimientoOperativoResponse
{
    public int Id { get; set; }
    public int CuentaFinancieraId { get; set; }
    public string CuentaFinanciera { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;
    public int MotivoGastoId { get; set; }
    public string MotivoGasto { get; set; } = string.Empty;

    /// <summary>OPERATIVO o NO_OPERATIVO, según su categoría.</summary>
    public string Origen { get; set; } = string.Empty;

    /// <summary>Lo generó otro módulo (la planilla): se anula desde allí, no desde aquí.</summary>
    public bool EsSistema { get; set; }

    public decimal Monto { get; set; }
    public DateTime Fecha { get; set; }
    public string? Descripcion { get; set; }
    public int? GastoRecurrenteId { get; set; }
    public string? Usuario { get; set; }
    public bool Anulado { get; set; }
}
