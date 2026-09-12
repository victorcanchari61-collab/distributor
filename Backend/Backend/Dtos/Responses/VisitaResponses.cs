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
