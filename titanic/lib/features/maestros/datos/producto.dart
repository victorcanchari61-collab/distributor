/// Una forma de comprar o vender un producto: saco de 50, caja x12.
class Presentacion {
  const Presentacion({
    required this.id,
    required this.unidadId,
    required this.unidad,
    required this.nombre,
    required this.factor,
    required this.esBase,
    required this.esCompra,
    required this.esVenta,
    this.precioPorPresentacion = false,
    required this.activo,
  });

  final int id;
  final int unidadId;
  final String unidad;
  final String nombre;

  /// Cuantas unidades base equivale. Un saco de 50 kg tiene factor 50.
  final double factor;

  /// La de factor 1: la crea sola el backend y no se elimina ni cambia.
  final bool esBase;
  final bool esCompra;
  final bool esVenta;

  /// Los PDF de ajustes, transferencias y prestamos sacan la linea en esta
  /// presentacion ("150 cajas × S/ 83.00") y no en unidad base ("1,800 × S/ 6.92").
  /// Lo arma el servidor: la app solo lo lee y lo devuelve. Apagado por defecto
  /// —y en la base no se ofrece, por unidad base ya ES por presentacion—.
  final bool precioPorPresentacion;
  final bool activo;

  factory Presentacion.desdeJson(Map<String, dynamic> json) => Presentacion(
    id: json['id'] as int,
    unidadId: json['unidadId'] as int,
    unidad: json['unidad'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    factor: (json['factor'] as num?)?.toDouble() ?? 1,
    esBase: json['esBase'] as bool? ?? false,
    esCompra: json['esCompra'] as bool? ?? true,
    esVenta: json['esVenta'] as bool? ?? true,
    precioPorPresentacion: json['precioPorPresentacion'] as bool? ?? false,
    activo: json['activo'] as bool? ?? true,
  );

  /// Cuerpo de POST/PUT de una presentacion.
  ///
  /// El endpoint REEMPLAZA la presentacion con lo que llega y un campo ausente
  /// se guarda como apagado: por eso el marcador viaja siempre, con el valor
  /// que ya tenia, para no borrar el que se puso desde la web.
  Map<String, dynamic> aJson() => {
    'unidadId': unidadId,
    'nombre': nombre,
    'factor': factor,
    'esCompra': esCompra,
    'esVenta': esVenta,
    'precioPorPresentacion': precioPorPresentacion,
    'activo': activo,
  };
}

/// Producto: lo que se compra y se vende.
class Producto {
  const Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    this.categoriaId,
    this.categoria,
    this.marcaId,
    this.marca,
    required this.unidadBaseId,
    required this.unidadBase,
    this.costoReferencia,
    this.precioReferencia,
    this.afectoIgv = false,
    required this.controlaStock,
    required this.stockMinimo,
    this.pesoUnidadBase,
    required this.activo,
    required this.presentaciones,
    this.tieneMovimientos = false,
  });

  final int id;
  final String codigo;
  final String nombre;
  final String? descripcion;

  /// Ya tiene stock, kardex o costos: cambiar su unidad base no los convierte.
  final bool tieneMovimientos;
  final int? categoriaId;
  final String? categoria;
  final int? marcaId;
  final String? marca;
  final int unidadBaseId;

  /// Codigo de la unidad en la que se lleva el stock: KG, UND, LT.
  final String unidadBase;

  /// Lo que suele costar una unidad base. Referencia, no el costo del stock.
  final double? costoReferencia;

  /// A cuánto suele venderse una unidad base: el respaldo cuando la lista no tiene precio.
  /// Ya incluye el IGV si el producto es afecto.
  final double? precioReferencia;

  /// Si paga IGV. Los precios ya lo incluyen: no se le suma nada encima.
  final bool afectoIgv;

  final bool controlaStock;
  final double stockMinimo;

  /// Kilos que pesa UNA unidad base. Null si el producto no se pesa.
  ///
  /// De aqui sale el peso de cualquier cantidad sin anotarlo en cada
  /// presentacion: si la botella pesa 0.92, la caja de 12 pesa 11.04 y diez
  /// cajas 110.4.
  final double? pesoUnidadBase;

  final bool activo;
  final List<Presentacion> presentaciones;

  /// Texto contra el que se busca en la lista.
  String get buscable =>
      '$codigo $nombre ${categoria ?? ''} ${marca ?? ''}'.toLowerCase();

  factory Producto.desdeJson(Map<String, dynamic> json) => Producto(
    id: json['id'] as int,
    tieneMovimientos: json['tieneMovimientos'] as bool? ?? false,
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    categoriaId: json['categoriaId'] as int?,
    categoria: json['categoria'] as String?,
    marcaId: json['marcaId'] as int?,
    marca: json['marca'] as String?,
    unidadBaseId: json['unidadBaseId'] as int,
    unidadBase: json['unidadBase'] as String? ?? '',
    costoReferencia: (json['costoReferencia'] as num?)?.toDouble(),
    precioReferencia: (json['precioReferencia'] as num?)?.toDouble(),
    afectoIgv: json['afectoIgv'] as bool? ?? false,
    controlaStock: json['controlaStock'] as bool? ?? true,
    stockMinimo: (json['stockMinimo'] as num?)?.toDouble() ?? 0,
    pesoUnidadBase: (json['pesoUnidadBase'] as num?)?.toDouble(),
    activo: json['activo'] as bool? ?? true,
    presentaciones: (json['presentaciones'] as List? ?? const [])
        .map((e) => Presentacion.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
