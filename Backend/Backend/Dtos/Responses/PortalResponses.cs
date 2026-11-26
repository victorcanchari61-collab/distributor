namespace Backend.Dtos.Responses;

/// <summary>Estado del acceso de un cliente al portal, como lo ve el vendedor en su ficha.</summary>
public class AccesoPortalResponse
{
    /// <summary>SIN_INVITAR, INVITADO (todavía no crea su acceso), ACTIVO o DESACTIVADO.</summary>
    public string Estado { get; set; } = string.Empty;

    public string? Usuario { get; set; }
    public DateTime? FechaInvitacion { get; set; }
    public string? InvitadoPor { get; set; }

    /// <summary>Hasta cuándo vale la invitación pendiente.</summary>
    public DateTime? InvitacionVence { get; set; }

    public DateTime? FechaActivacion { get; set; }
    public DateTime? UltimoIngreso { get; set; }

    /// <summary>El teléfono al que se manda el WhatsApp; vacío si el cliente no tiene.</summary>
    public string? Telefono { get; set; }
}

/// <summary>Resultado de invitar: el enlace (para copiarlo) y si salió por WhatsApp.</summary>
public class InvitacionPortalResponse
{
    public string Enlace { get; set; } = string.Empty;
    public DateTime Vence { get; set; }
    public bool EnviadoPorWhatsApp { get; set; }

    /// <summary>Por qué no salió por WhatsApp (sin teléfono, servicio sin vincular...).</summary>
    public string? MotivoNoEnviado { get; set; }

    public AccesoPortalResponse Acceso { get; set; } = new();
}

/// <summary>Lo que se muestra al abrir un enlace de invitación o de recuperación.</summary>
public class EnlacePortalResponse
{
    /// <summary>INVITACION o RECUPERACION.</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>El nombre del negocio, para que vea que el enlace es suyo.</summary>
    public string Cliente { get; set; } = string.Empty;

    /// <summary>Solo en la invitación: su número de documento como usuario sugerido.</summary>
    public string? UsuarioSugerido { get; set; }

    /// <summary>Solo en la recuperación: el usuario con el que entra.</summary>
    public string? Usuario { get; set; }

    public string Empresa { get; set; } = string.Empty;
}

/// <summary>Sesión iniciada en el portal.</summary>
public class PortalSesionResponse
{
    public string Token { get; set; } = string.Empty;
    public PortalClienteResponse Cliente { get; set; } = new();
}

/// <summary>Quién está en el portal y a quién le llegan sus cotizaciones.</summary>
public class PortalClienteResponse
{
    public string Nombre { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;
    public string Usuario { get; set; } = string.Empty;
    public string? Vendedor { get; set; }
    public string Empresa { get; set; } = string.Empty;
    public string? TelefonoEmpresa { get; set; }
}

public class CotizacionResponse
{
    public int Id { get; set; }
    public string Numero { get; set; } = string.Empty;
    public DateTime Fecha { get; set; }

    /// <summary>EN_ESPERA, ATENDIDA, DESCARTADA o CANCELADA.</summary>
    public string Estado { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;
    public string ClienteDocumento { get; set; } = string.Empty;
    public string? Ruta { get; set; }

    public int? VendedorId { get; set; }
    public string? Vendedor { get; set; }

    public int? ListaPrecioId { get; set; }
    public string? Nota { get; set; }
    public decimal Total { get; set; }

    /// <summary>El pedido que salió de ella, si ya se atendió.</summary>
    public int? PedidoId { get; set; }
    public string? PedidoNumero { get; set; }

    public DateTime? FechaCierre { get; set; }
    public string? CerradaPor { get; set; }
    public string? MotivoDescarte { get; set; }

    public List<CotizacionLineaResponse> Detalle { get; set; } = [];
}

public class CotizacionLineaResponse
{
    public int Id { get; set; }
    public int ProductoId { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Producto { get; set; } = string.Empty;
    public int PresentacionId { get; set; }
    public string Presentacion { get; set; } = string.Empty;

    /// <summary>Unidades base que trae una presentación.</summary>
    public decimal Factor { get; set; }

    public decimal Cantidad { get; set; }
    public decimal PrecioPresentacion { get; set; }
    public decimal Subtotal { get; set; }
}
