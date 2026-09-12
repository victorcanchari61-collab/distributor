namespace Backend.Models;

/// <summary>
/// Hasta dónde llega lo que alguien ve dentro de un submódulo.
///
/// Es distinto de un permiso: el permiso dice si puede entrar y qué botones
/// tiene; el alcance dice QUÉ FILAS. Un vendedor puede tener permiso de ver
/// pedidos y aun así no tener por qué ver los de toda la empresa.
///
/// Se guarda como texto y no como número para que la fila de la base se lea
/// sola — "misclientes" dice lo que es, un 1 no.
/// </summary>
public static class AlcanceDatos
{
    /// <summary>Sin restricción. Es lo que se aplica si no hay nada configurado.</summary>
    public const string Todos = "todos";

    /// <summary>
    /// Lo de los clientes que tiene asignados, MÁS lo que él mismo registró.
    ///
    /// Lo segundo no es un capricho: si un vendedor toma un pedido de un
    /// cliente que no es suyo y el alcance fuera estricto, lo perdería de vista
    /// al instante y no podría ni corregirlo ni anularlo.
    /// </summary>
    public const string MisClientes = "misclientes";

    /// <summary>Solo lo que él registró, sin importar de quién sea el cliente.</summary>
    public const string Propios = "propios";

    public static readonly string[] Todas = [Todos, MisClientes, Propios];

    public static bool EsValido(string alcance) => Todas.Contains(alcance);

    /// <summary>
    /// Los submódulos donde el alcance tiene sentido.
    ///
    /// Son aquellos cuyas filas pertenecen a alguien: un pedido es de un
    /// cliente y lo tomó una persona. Un almacén o un producto no son de
    /// nadie, y ofrecer ahí un alcance sería ofrecer algo que no se puede
    /// cumplir.
    /// </summary>
    public static readonly string[] Submodulos =
    [
        "fact.pedidos",
        "fact.notaventa",
        "maestros.clientes",
    ];
}

/// <summary>El alcance que tiene un rol en un submódulo.</summary>
public class RolAlcance
{
    public int Id { get; set; }

    public int RolId { get; set; }
    public Rol? Rol { get; set; }

    /// <summary>Clave del menú: "fact.pedidos".</summary>
    public string Submodulo { get; set; } = string.Empty;

    public string Alcance { get; set; } = AlcanceDatos.Todos;
}

/// <summary>
/// El alcance de una persona concreta, que manda sobre el de su rol.
///
/// Existe por el mismo motivo que las excepciones de permiso: el supervisor
/// que es del rol Vendedor pero sí necesita ver todo, sin tener que crearle un
/// rol propio para una sola persona.
/// </summary>
public class UsuarioAlcance
{
    public int Id { get; set; }

    public int UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public string Submodulo { get; set; } = string.Empty;

    public string Alcance { get; set; } = AlcanceDatos.Todos;

    /// <summary>Quién se lo dio y cuándo, para poder responder por qué ve lo que ve.</summary>
    public int? ConcedidoPorId { get; set; }
    public Usuario? ConcedidoPor { get; set; }
    public DateTime ConcedidoEn { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// El alcance ya resuelto para una persona concreta, listo para acotar una
/// consulta.
///
/// Viaja hasta el repositorio porque el recorte tiene que ocurrir DENTRO de la
/// consulta: filtrar en memoria despues de paginar daria paginas incompletas
/// — "mostrando 3 de 40" con dos filas visibles.
/// </summary>
public sealed record AlcanceFiltro(string Alcance, int UsuarioId)
{
    public bool SinRestriccion => Alcance == AlcanceDatos.Todos;

    /// <summary>Solo lo que registro esa persona.</summary>
    public bool SoloPropios => Alcance == AlcanceDatos.Propios;
}
