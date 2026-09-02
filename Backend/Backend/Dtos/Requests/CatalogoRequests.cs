namespace Backend.Dtos.Requests;

public abstract class CategoriaRequestBase
{
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
}

public class CreateCategoriaRequest : CategoriaRequestBase;

public class UpdateCategoriaRequest : CategoriaRequestBase
{
    public bool Activo { get; set; } = true;
}

public abstract class MarcaRequestBase
{
    public string Nombre { get; set; } = string.Empty;
}

public class CreateMarcaRequest : MarcaRequestBase;

public class UpdateMarcaRequest : MarcaRequestBase
{
    public bool Activo { get; set; } = true;
}

public abstract class UnidadMedidaRequestBase
{
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;

    /// <summary>CONTEO / PESO / VOLUMEN.</summary>
    public string Tipo { get; set; } = string.Empty;

    public bool Fraccionable { get; set; }
}

public class CreateUnidadMedidaRequest : UnidadMedidaRequestBase;

public class UpdateUnidadMedidaRequest : UnidadMedidaRequestBase
{
    public bool Activo { get; set; } = true;
}
