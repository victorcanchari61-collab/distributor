namespace Backend.Dtos.Requests;

/// <summary>Una categoría tal como se edita en pantalla. El "hasta" no viaja: se deduce del tramo de arriba.</summary>
public class CategoriaClienteRequest
{
    /// <summary>A a F. Identifica la categoría; no se puede cambiar.</summary>
    public string Codigo { get; set; } = string.Empty;

    public string Nombre { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;

    /// <summary>Desde cuántos soles comprados entra en esta categoría.</summary>
    public decimal Desde { get; set; }
}

/// <summary>El ciclo y los seis tramos. Guardar no recalcula: eso lo hace "Calcular ahora" o el cambio de ciclo.</summary>
public class GuardarCategorizacionRequest
{
    /// <summary>MENSUAL, TRIMESTRAL, CUATRIMESTRAL o ANUAL.</summary>
    public string Ciclo { get; set; } = string.Empty;

    public List<CategoriaClienteRequest> Categorias { get; set; } = [];
}
