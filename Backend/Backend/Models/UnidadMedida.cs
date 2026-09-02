namespace Backend.Models;

/// <summary>Naturaleza de la unidad. Se guarda como texto, igual que TipoDoc.</summary>
public static class TipoUnidad
{
    /// <summary>Se cuenta: unidad, caja, saco, bolsa.</summary>
    public const string Conteo = "CONTEO";

    /// <summary>Se pesa: kilo, gramo, tonelada.</summary>
    public const string Peso = "PESO";

    /// <summary>Se mide: litro, mililitro.</summary>
    public const string Volumen = "VOLUMEN";

    public static readonly string[] Todos = [Conteo, Peso, Volumen];
}

/// <summary>
/// Unidad de medida del catalogo.
///
/// Es solo el nombre de la unidad. Cuantos kilos trae un saco NO se guarda
/// aqui, porque depende del producto: hay sacos de 50 y de 43 kilos. Esa
/// equivalencia vive en <see cref="ProductoPresentacion"/>.
/// </summary>
public class UnidadMedida
{
    public int Id { get; set; }

    /// <summary>Codigo corto que se ve en documentos: KG, UND, SAC, CJA.</summary>
    public string Codigo { get; set; } = string.Empty;

    public string Nombre { get; set; } = string.Empty;

    /// <summary>CONTEO / PESO / VOLUMEN. Ver <see cref="TipoUnidad"/>.</summary>
    public string Tipo { get; set; } = TipoUnidad.Conteo;

    /// <summary>
    /// Admite decimales. Se pueden vender 2.5 kilos, pero no 2.5 sacos.
    /// </summary>
    public bool Fraccionable { get; set; }

    public bool Activo { get; set; } = true;

    /// <summary>Unidad que trae el sistema: no se elimina.</summary>
    public bool DelSistema { get; set; }

    public DateTime FechaCreacion { get; set; } = DateTime.UtcNow;
}
