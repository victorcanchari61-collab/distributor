/// Qué clase de lugar es un almacén.
enum TipoAlmacen {
  almacen('ALMACEN', 'Almacén'),
  deposito('DEPOSITO', 'Depósito'),
  tienda('TIENDA', 'Tienda'),
  vehiculo('VEHICULO', 'Vehículo');

  const TipoAlmacen(this.clave, this.etiqueta);

  final String clave;
  final String etiqueta;

  static TipoAlmacen desdeClave(String? clave) => values.firstWhere(
    (t) => t.clave == clave,
    orElse: () => TipoAlmacen.almacen,
  );
}

/// Almacen: donde se guarda la mercaderia.
class Almacen {
  const Almacen({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.tipo = TipoAlmacen.almacen,
    this.direccion,
    this.distritoId,
    this.distrito,
    this.provinciaId,
    this.provincia,
    this.departamentoId,
    this.referencia,
    this.responsable,
    this.telefono,
    required this.esPrincipal,
    required this.activo,
    this.ubicaciones = 0,
    required this.productos,
    required this.valorizado,
  });

  final int id;
  final String codigo;
  final String nombre;
  final TipoAlmacen tipo;

  /// Calle, numero, manzana y lote. El distrito va aparte.
  final String? direccion;

  final int? distritoId;
  final String? distrito;
  final int? provinciaId;
  final String? provincia;
  final int? departamentoId;

  /// Como llegar: "frente al mercado, porton verde".
  final String? referencia;

  /// Quien lo tiene a cargo.
  final String? responsable;
  final String? telefono;

  /// El que recibe todo movimiento sin indicar otro. No se desactiva.
  final bool esPrincipal;

  final bool activo;

  /// Cuantos lugares (pisos, pasillos, estantes...) tiene definidos dentro.
  final int ubicaciones;

  /// Cuantos productos tienen stock ahi.
  final int productos;

  /// Cuanto vale la mercaderia que guarda, al costo.
  final double valorizado;

  /// La direccion en una linea: calle, distrito y provincia.
  String? get direccionCompleta {
    final partes = [
      if (direccion != null && direccion!.trim().isNotEmpty) direccion!.trim(),
      if (distrito != null) distrito!,
      if (provincia != null && provincia != distrito) provincia!,
    ];
    return partes.isEmpty ? null : partes.join(', ');
  }

  /// Texto contra el que se busca en la lista.
  String get buscable =>
      '$codigo $nombre ${direccionCompleta ?? ''} ${responsable ?? ''} ${tipo.etiqueta}'
          .toLowerCase();

  factory Almacen.desdeJson(Map<String, dynamic> json) => Almacen(
    id: json['id'] as int,
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    tipo: TipoAlmacen.desdeClave(json['tipo'] as String?),
    direccion: json['direccion'] as String?,
    distritoId: json['distritoId'] as int?,
    distrito: json['distrito'] as String?,
    provinciaId: json['provinciaId'] as int?,
    provincia: json['provincia'] as String?,
    departamentoId: json['departamentoId'] as int?,
    referencia: json['referencia'] as String?,
    responsable: json['responsable'] as String?,
    telefono: json['telefono'] as String?,
    esPrincipal: json['esPrincipal'] as bool? ?? false,
    activo: json['activo'] as bool? ?? true,
    ubicaciones: json['ubicaciones'] as int? ?? 0,
    productos: json['productos'] as int? ?? 0,
    valorizado: (json['valorizado'] as num?)?.toDouble() ?? 0,
  );
}

/// Un lugar dentro de un almacen: un piso, un pasillo, un estante, una posicion.
class Ubicacion {
  const Ubicacion({
    required this.id,
    required this.almacenId,
    required this.padreId,
    required this.tipoEtiqueta,
    required this.codigo,
    required this.nombre,
    required this.ruta,
    required this.nivel,
    required this.activo,
    required this.hijos,
    required this.productos,
  });

  final int id;
  final int almacenId;
  final int? padreId;
  final String tipoEtiqueta;

  /// El codigo corto de este punto: "P1", "A", "03".
  final String codigo;
  final String? nombre;

  /// Los codigos desde la raiz, unidos con guion: "P1-A-03". Es como se nombra el lugar.
  final String ruta;

  /// Cuantos escalones tiene arriba: 0 en la raiz del almacen.
  final int nivel;
  final bool activo;

  /// Cuantos lugares tiene directamente adentro.
  final int hijos;

  /// Cuantos productos estan puestos aqui.
  final int productos;

  factory Ubicacion.desdeJson(Map<String, dynamic> json) => Ubicacion(
    id: json['id'] as int,
    almacenId: json['almacenId'] as int? ?? 0,
    padreId: json['padreId'] as int?,
    tipoEtiqueta: json['tipoEtiqueta'] as String? ?? '',
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String?,
    ruta: json['ruta'] as String? ?? '',
    nivel: json['nivel'] as int? ?? 0,
    activo: json['activo'] as bool? ?? true,
    hijos: json['hijos'] as int? ?? 0,
    productos: json['productos'] as int? ?? 0,
  );
}

/// Un producto puesto en un lugar del almacen.
class UbicacionProducto {
  const UbicacionProducto({
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.categoria,
    required this.unidadBase,
  });

  final int productoId;
  final String codigo;
  final String producto;
  final String? categoria;
  final String unidadBase;

  factory UbicacionProducto.desdeJson(Map<String, dynamic> json) =>
      UbicacionProducto(
        productoId: json['productoId'] as int,
        codigo: json['codigo'] as String? ?? '',
        producto: json['producto'] as String? ?? '',
        categoria: json['categoria'] as String?,
        unidadBase: json['unidadBase'] as String? ?? '',
      );
}
