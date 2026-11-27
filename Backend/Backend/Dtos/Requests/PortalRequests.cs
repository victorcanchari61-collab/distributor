namespace Backend.Dtos.Requests;

/// <summary>Entrar al portal: con el usuario que eligió o con su DNI/RUC.</summary>
public class PortalLoginRequest
{
    public string Usuario { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

/// <summary>Completar la invitación: el cliente confirma su documento y elige su usuario y contraseña.</summary>
public class PortalActivarRequest
{
    public string Token { get; set; } = string.Empty;

    /// <summary>Su DNI o RUC: si el enlace se reenvió por error, otra persona no puede quedarse con la cuenta.</summary>
    public string Documento { get; set; } = string.Empty;

    public string Usuario { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

/// <summary>Elegir otra contraseña con el enlace de "olvidé mi contraseña".</summary>
public class PortalRestablecerRequest
{
    public string Token { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

/// <summary>Cambiar el usuario desde "Mi perfil": pide la contraseña actual.</summary>
public class PortalCambiarUsuarioRequest
{
    public string Usuario { get; set; } = string.Empty;
    public string PasswordActual { get; set; } = string.Empty;
}

/// <summary>Cambiar la contraseña desde "Mi perfil": pide la actual.</summary>
public class PortalCambiarPasswordRequest
{
    public string PasswordActual { get; set; } = string.Empty;
    public string PasswordNueva { get; set; } = string.Empty;
}

public class PortalOlvideRequest
{
    /// <summary>Su usuario o su DNI/RUC.</summary>
    public string Usuario { get; set; } = string.Empty;
}

/// <summary>Lo que el cliente manda desde el carrito.</summary>
public class CrearCotizacionRequest
{
    public string? Nota { get; set; }
    public List<LineaCotizacionRequest> Detalle { get; set; } = [];
}

public class LineaCotizacionRequest
{
    /// <summary>La presentación del catálogo (saco, caja, unidad...). El producto sale de ella.</summary>
    public int PresentacionId { get; set; }

    /// <summary>Cuántas presentaciones.</summary>
    public decimal Cantidad { get; set; }
}

public class DescartarCotizacionRequest
{
    /// <summary>Por qué no se atiende: lo ve el cliente.</summary>
    public string Motivo { get; set; } = string.Empty;
}

/// <summary>Prender o apagar el acceso al portal de un cliente.</summary>
public class AccesoPortalActivoRequest
{
    public bool Activo { get; set; }
}
