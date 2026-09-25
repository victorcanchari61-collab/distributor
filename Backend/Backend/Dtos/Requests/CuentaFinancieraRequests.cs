namespace Backend.Dtos.Requests;

public class CuentaFinancieraRequest
{
    public string Nombre { get; set; } = string.Empty;

    /// <summary>CAJA, BANCO o PASARELA.</summary>
    public string Naturaleza { get; set; } = string.Empty;

    /// <summary>A qué Banco pertenece: solo aplica si Naturaleza es Banco.</summary>
    public int? BancoId { get; set; }

    /// <summary>Solo aplica si Naturaleza es Banco o Pasarela.</summary>
    public string? NumeroCuenta { get; set; }
    public string? Cci { get; set; }
    public string? Titular { get; set; }

    /// <summary>
    /// Solo aplica si Naturaleza es Caja: de quién es (un vendedor o
    /// repartidor). La Caja General no tiene responsable.
    /// </summary>
    public int? UsuarioResponsableId { get; set; }

    /// <summary>
    /// Con cuánto ya venía la cuenta antes de registrarla (lo que de verdad
    /// tiene el banco hoy). Solo se usa al crearla: una vez creada, el saldo
    /// se mueve con movimientos, no editando este campo.
    /// </summary>
    public decimal MontoInicial { get; set; }

    public bool Activo { get; set; } = true;
}
