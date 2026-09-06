namespace Backend.Models;

/// <summary>
/// Una cosa que un rol puede hacer: una accion sobre un submodulo.
///
/// Antes era una fila por MODULO con cuatro banderas (ver/crear/editar/
/// eliminar). Eso no alcanzaba: dentro de Facturacion no es lo mismo emitir
/// una nota de venta que anularla, y acciones como exportar o importar no
/// existian.
///
/// El modulo NO se guarda: sale del prefijo de <see cref="Submodulo"/>
/// ("fact.pedidos" es de "fact"). Guardarlo aparte permitiria estados
/// contradictorios, como negar Facturacion y a la vez permitir Pedidos.
///
/// La combinacion valida la define <see cref="CatalogoPermisos"/>.
/// </summary>
public class RolPermiso
{
    public int Id { get; set; }
    public int RolId { get; set; }
    public Rol? Rol { get; set; }

    /// <summary>Clave del menu: "fact.pedidos", "inv.ajustes".</summary>
    public string Submodulo { get; set; } = string.Empty;

    /// <summary>Ver, crear, editar, anular... Ver <see cref="Accion"/>.</summary>
    public string Accion { get; set; } = string.Empty;
}
