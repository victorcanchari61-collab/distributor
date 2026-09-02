namespace Backend.Dtos.Responses;

public class CategoriaResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; }

    /// <summary>Cuantos productos la usan: sirve para avisar antes de borrar.</summary>
    public int Productos { get; set; }
}

public class MarcaResponse
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activo { get; set; }
    public int Productos { get; set; }
}

public class UnidadMedidaResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string Tipo { get; set; } = string.Empty;
    public bool Fraccionable { get; set; }
    public bool Activo { get; set; }
    public bool DelSistema { get; set; }

    /// <summary>En cuantas presentaciones o productos se usa.</summary>
    public int Usos { get; set; }
}
