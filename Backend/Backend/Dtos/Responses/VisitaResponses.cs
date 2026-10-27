namespace Backend.Dtos.Responses;

/// <summary>Un cliente al que toca visitar ese día.</summary>
public class VisitaResponse
{
    /// <summary>El día al que corresponde la visita.</summary>
    public DateTime Fecha { get; set; }

    /// <summary>LUNES, MARTES... el día de visita del cliente.</summary>
    public string Dia { get; set; } = string.Empty;

    public int ClienteId { get; set; }
    public string Cliente { get; set; } = string.Empty;
    public string Documento { get; set; } = string.Empty;

    /// <summary>Dónde está el puesto: sin esto la lista no sirve en la calle.</summary>
    public string? Direccion { get; set; }
    public string? Mercado { get; set; }
    public string? Telefono { get; set; }

    public int? RutaId { get; set; }
    public string? Ruta { get; set; }

    public int? VendedorId { get; set; }
    public string? Vendedor { get; set; }

    /// <summary>
    /// Si ya se le tomó pedido ese día.
    ///
    /// Es lo que convierte la lista en trabajo pendiente: lo que importa no es
    /// a quién toca visitar, sino a quién falta.
    /// </summary>
    public bool Atendido { get; set; }
    public int? PedidoId { get; set; }
    public string? PedidoNumero { get; set; }
    public decimal Total { get; set; }

    /// <summary>
    /// Cómo viene comprando el cliente este mes frente al anterior (CRITICO, ALTO, MEDIO, ESTABLE,
    /// NUEVO o INACTIVO), para que quien lo visita sepa si es uno de los que se están yendo.
    /// Nulo si no hay datos o quien pregunta no puede ver la cartera del CRM.
    /// </summary>
    public string? Riesgo { get; set; }

    /// <summary>Cambio en % de sus compras del mes contra el mes anterior.</summary>
    public decimal? Variacion { get; set; }

    /// <summary>La próxima acción de seguimiento abierta de este cliente, si la hay.</summary>
    public string? AccionPendiente { get; set; }

    /// <summary>Esa acción ya debió hacerse.</summary>
    public bool AccionVencida { get; set; }
}

public class ResumenVisitasResponse
{
    /// <summary>Cuántos clientes tocan ese día.</summary>
    public int Programadas { get; set; }

    /// <summary>A cuántos ya se les tomó pedido.</summary>
    public int Atendidas { get; set; }

    public int Pendientes { get; set; }

    /// <summary>Lo pedido ese día por los clientes de la lista.</summary>
    public decimal Total { get; set; }
}
