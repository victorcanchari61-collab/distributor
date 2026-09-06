namespace Backend.Models;

/// <summary>
/// Lo que se puede hacer sobre un submódulo.
///
/// No es la lista de siempre (crear/editar/borrar): el negocio tiene acciones
/// propias que antes se decidían por rol a mano — anular una venta, confirmar
/// un pedido, exportar el padrón de clientes.
/// </summary>
public static class Accion
{
    /// <summary>Entrar a la pantalla. Sin esto no aplica ninguna otra.</summary>
    public const string Ver = "ver";

    public const string Crear = "crear";
    public const string Editar = "editar";

    /// <summary>Dejar sin efecto un documento ya emitido, conservándolo.</summary>
    public const string Anular = "anular";

    /// <summary>Borrado definitivo. Solo donde de verdad se puede borrar.</summary>
    public const string Eliminar = "eliminar";

    public const string Exportar = "exportar";
    public const string Importar = "importar";

    /// <summary>Cerrar el documento y que surta efecto: despachar, recibir.</summary>
    public const string Confirmar = "confirmar";

    /// <summary>Registrar o anular un pago o un cobro.</summary>
    public const string Cobrar = "cobrar";

    public static readonly string[] Todas =
    [
        Ver, Crear, Editar, Anular, Eliminar, Exportar, Importar, Confirmar, Cobrar,
    ];
}

/// <summary>
/// Qué submódulos existen y qué acciones admite cada uno.
///
/// Es la fuente de verdad del sistema de permisos: el backend valida contra
/// esto y la pantalla de Accesos dibuja su matriz con lo que devuelve el
/// catálogo. Si estuviera duplicado en el front, las dos listas se separarían
/// con el primer submódulo nuevo.
///
/// Cada submódulo declara SOLO las acciones que tienen sentido en él: la
/// auditoría no se crea, el kardex no se anula. Sin ese recorte la matriz
/// serían 41 × 9 = 369 casillas, la mayoría sin significado, y nadie la
/// configuraría bien.
///
/// La clave es la misma del menú (<c>modulo.submodulo</c>), así el front no
/// necesita traducir nada y el módulo se deduce del prefijo — por eso el
/// módulo NO se guarda como permiso aparte: tenerlo en dos niveles permitiría
/// estados contradictorios ("Facturación denegado" pero "Pedidos permitido").
/// </summary>
public static class CatalogoPermisos
{
    /// <summary>Un listado que además se exporta, pero no se edita desde aquí.</summary>
    private static readonly string[] Consulta = [Accion.Ver, Accion.Exportar];

    /// <summary>Un catálogo común: se ve, se crea, se edita y se borra.</summary>
    private static readonly string[] Catalogo =
        [Accion.Ver, Accion.Crear, Accion.Editar, Accion.Eliminar];

    /// <summary>Un catálogo grande, con carga masiva desde archivo.</summary>
    private static readonly string[] CatalogoImportable =
        [Accion.Ver, Accion.Crear, Accion.Editar, Accion.Eliminar, Accion.Exportar, Accion.Importar];

    /// <summary>Un documento que se emite, se corrige y se anula.</summary>
    private static readonly string[] Documento =
        [Accion.Ver, Accion.Crear, Accion.Editar, Accion.Anular, Accion.Exportar];

    /// <summary>Un documento que además se confirma (se despacha o se recibe).</summary>
    private static readonly string[] DocumentoConfirmable =
        [Accion.Ver, Accion.Crear, Accion.Editar, Accion.Anular, Accion.Confirmar, Accion.Exportar];

    public static readonly IReadOnlyDictionary<string, string[]> Submodulos =
        new Dictionary<string, string[]>
        {
            // --- Maestros ---
            ["maestros.clientes"] = CatalogoImportable,
            ["maestros.proveedores"] = CatalogoImportable,
            ["maestros.productos"] = CatalogoImportable,

            // --- Compras ---
            ["compras.ordenes"] = DocumentoConfirmable,
            ["compras.compras"] = [.. Documento, Accion.Cobrar],
            ["compras.recepciones"] = Documento,

            // --- Inventario ---
            ["inv.almacenes"] = Catalogo,
            ["inv.stock"] = Consulta,
            ["inv.kardex"] = Consulta,
            ["inv.ajustes"] = Documento,
            ["inv.transferencias"] = Documento,
            ["inv.prestamos"] = DocumentoConfirmable,
            ["inv.lotes"] = Consulta,
            ["inv.conteos"] = Documento,

            // --- Facturación ---
            ["fact.pedidos"] = DocumentoConfirmable,
            ["fact.notaventa"] = [.. Documento, Accion.Cobrar],
            ["fact.precios"] = Catalogo,
            ["fact.comprobantes"] = Documento,

            // --- Finanzas ---
            ["finanzas.metodospago"] = Catalogo,
            ["finanzas.cobrar"] = [Accion.Ver, Accion.Cobrar, Accion.Exportar],
            ["finanzas.pagar"] = [Accion.Ver, Accion.Cobrar, Accion.Exportar],
            ["finanzas.miscobros"] = Consulta,
            ["finanzas.arqueo"] = [Accion.Ver, Accion.Crear, Accion.Exportar],

            // --- TMS ---
            ["tms.mercados"] = Catalogo,
            ["tms.rutas"] = Catalogo,
            ["tms.flota"] = Catalogo,
            ["tms.conductores"] = Catalogo,
            ["tms.tracking"] = Consulta,
            ["tms.liquidacion"] = Documento,

            // --- DMS ---
            ["dms.visitas"] = Documento,
            ["dms.cobranzas"] = [Accion.Ver, Accion.Cobrar, Accion.Exportar],
            ["dms.devoluciones"] = Documento,
            ["dms.evidencias"] = Consulta,

            // --- RR. HH. ---
            ["rrhh.empleados"] = CatalogoImportable,
            ["rrhh.asistencia"] = Documento,
            ["rrhh.vacaciones"] = DocumentoConfirmable,
            ["rrhh.nomina"] = DocumentoConfirmable,
            ["rrhh.desempeno"] = Documento,

            // --- Configuración ---
            ["config.usuarios"] = Catalogo,
            ["config.roles"] = Catalogo,
            ["config.accesos"] = [Accion.Ver, Accion.Editar],
            ["config.empresa"] = [Accion.Ver, Accion.Editar],
            ["config.auditoria"] = Consulta,
            ["config.series"] = Catalogo,
            ["config.parametros"] = [Accion.Ver, Accion.Editar],
        };

    /// <summary>El módulo al que pertenece un submódulo: el prefijo de su clave.</summary>
    public static string ModuloDe(string submodulo)
    {
        var punto = submodulo.IndexOf('.');
        return punto < 0 ? submodulo : submodulo[..punto];
    }

    /// <summary>
    /// Si ese permiso puede existir. Sirve para no guardar basura: un submódulo
    /// mal escrito o una acción que ese submódulo no admite.
    /// </summary>
    public static bool EsValido(string submodulo, string accion) =>
        Submodulos.TryGetValue(submodulo, out var acciones) && acciones.Contains(accion);

    /// <summary>Los submódulos de un módulo, para expandir "marcar todo".</summary>
    public static IEnumerable<string> DelModulo(string modulo) =>
        Submodulos.Keys.Where(s => ModuloDe(s) == modulo);
}
