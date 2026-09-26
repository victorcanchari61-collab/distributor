namespace Backend.Dtos.Responses;

public class ClienteResponse
{
    public int Id { get; set; }
    public string Documento { get; set; } = string.Empty;
    public string TipoDoc { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Direccion { get; set; }
    public int? DistritoId { get; set; }
    public string? Distrito { get; set; }
    public int? ProvinciaId { get; set; }
    public string? Provincia { get; set; }
    public int? DepartamentoId { get; set; }
    public string? Departamento { get; set; }
    public string? Telefono { get; set; }
    public string? Email { get; set; }
    public string? DiaVisita { get; set; }
    public int? RutaId { get; set; }
    public string? Ruta { get; set; }
    public int? MercadoId { get; set; }
    public string? Mercado { get; set; }
    public int? VendedorId { get; set; }

    public int? ListaPrecioId { get; set; }
    public string? ListaPrecio { get; set; }
    public string? Vendedor { get; set; }
    public bool Activo { get; set; }
    public DateTime FechaCreacion { get; set; }
}

/// <summary>
/// Un cliente para elegirlo en un selector (pedido, nota de venta): lo justo
/// para reconocerlo y la lista de precios con que se le vende.
/// </summary>
public class ClienteOpcionResponse
{
    public int Id { get; set; }
    public string Documento { get; set; } = string.Empty;
    public string TipoDoc { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Distrito { get; set; }
    public string? Ruta { get; set; }
    public string? Mercado { get; set; }
    public int? ListaPrecioId { get; set; }

    /// <summary>Por dónde se lo encuentra en la calle: el APK también busca por dirección.</summary>
    public string? Direccion { get; set; }

    /// <summary>El día que se lo visita: el APK filtra el selector por día.</summary>
    public string? DiaVisita { get; set; }

    /// <summary>Siempre true: el selector solo ofrece activos (el APK lo lee para filtrar).</summary>
    public bool Activo { get; set; } = true;
}
