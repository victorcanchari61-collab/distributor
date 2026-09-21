import '../../../compartido/fechas.dart';

/// ARMADO o ANULADO.
class EstadoDespacho {
  const EstadoDespacho._();
  static const armado = 'ARMADO';
  static const anulado = 'ANULADO';
}

/// Un pedido dentro del camión, con lo que hace falta para repartirlo.
class DespachoPedido {
  const DespachoPedido({
    required this.pedidoId,
    required this.numero,
    required this.clienteId,
    required this.cliente,
    this.clienteDocumento,
    required this.fecha,
    this.direccion,
    this.mercado,
    this.telefono,
    this.rutaCliente,
    this.diaVisita,
    required this.total,
    required this.lineas,
    this.notaVentaId,
    this.notaVentaNumero,
    this.noEntregadoMotivo,
    this.noEntregadoObservacion,
    this.lineasConNovedad = 0,
  });

  final int pedidoId;
  final String numero;
  final int clienteId;
  final String cliente;
  final String? clienteDocumento;

  /// Cuándo se tomó el pedido.
  final DateTime fecha;
  final String? direccion;
  final String? mercado;
  final String? telefono;

  /// La ruta del cliente y el día en que se lo visita: con varias rutas en el camión, dice de cuál es cada pedido.
  final String? rutaCliente;
  final String? diaVisita;
  final double total;
  final int lineas;

  /// La venta, si el repartidor ya lo convirtió.
  final int? notaVentaId;
  final String? notaVentaNumero;

  /// Por qué no se entregó, si se marcó entero como no entregado en este
  /// camión. Vacío mientras no se haya marcado o si después se entregó.
  final String? noEntregadoMotivo;
  final String? noEntregadoObservacion;

  /// En cuántos productos se entregó menos de lo pedido.
  final int lineasConNovedad;

  bool get entregado => notaVentaId != null;

  factory DespachoPedido.desdeJson(Map<String, dynamic> json) => DespachoPedido(
    pedidoId: json['pedidoId'] as int,
    numero: json['numero'] as String? ?? '',
    clienteId: json['clienteId'] as int,
    cliente: json['cliente'] as String? ?? '',
    clienteDocumento: json['clienteDocumento'] as String?,
    fecha: fechaDeJson(json['fecha'] as String),
    direccion: json['direccion'] as String?,
    mercado: json['mercado'] as String?,
    telefono: json['telefono'] as String?,
    rutaCliente: json['rutaCliente'] as String?,
    diaVisita: json['diaVisita'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    lineas: json['lineas'] as int? ?? 0,
    notaVentaId: json['notaVentaId'] as int?,
    notaVentaNumero: json['notaVentaNumero'] as String?,
    noEntregadoMotivo: json['noEntregadoMotivo'] as String?,
    noEntregadoObservacion: json['noEntregadoObservacion'] as String?,
    lineasConNovedad: json['lineasConNovedad'] as int? ?? 0,
  );
}

/// Despacho: la carga de un camión para un día y una ruta.
///
/// Junta PEDIDOS, no ventas: el vendedor los toma en la calle, aquí se arma
/// con ellos el reparto, y es el repartidor quien convierte cada uno en venta
/// al entregarlo.
class Despacho {
  const Despacho({
    required this.id,
    required this.numero,
    required this.fecha,
    this.pedidosDesde,
    this.pedidosHasta,
    required this.rutaId,
    required this.ruta,
    this.diaVisita,
    this.rutaIds = const [],
    this.rutas = const [],
    required this.vehiculoId,
    required this.vehiculo,
    required this.conductorId,
    required this.conductor,
    required this.estado,
    this.observacion,
    this.usuario,
    required this.pedidos,
    required this.total,
    required this.entregados,
    this.noEntregados = 0,
    required this.detalle,
  });

  final int id;
  final String numero;
  final DateTime fecha;

  /// De qué días son los pedidos que carga el camión.
  final DateTime? pedidosDesde;
  final DateTime? pedidosHasta;

  /// El día de visita que atiende (LUNES … SABADO); nulo en los despachos armados antes de este campo.
  final String? diaVisita;

  /// La ruta principal (la primera).
  final int rutaId;

  /// Todas las rutas, dichas como se leen: "1 · 7".
  final String ruta;
  final List<int> rutaIds;
  final List<String> rutas;
  final int vehiculoId;

  /// La placa: es como se nombra a un camión de verdad.
  final String vehiculo;
  final int conductorId;
  final String conductor;
  final String estado;
  final String? observacion;
  final String? usuario;
  final int pedidos;
  final double total;

  /// Cuántos de esos pedidos ya se convirtieron en venta.
  final int entregados;

  /// Cuántos pedidos se marcaron como no entregados.
  final int noEntregados;
  final List<DespachoPedido> detalle;

  bool get anulado => estado == EstadoDespacho.anulado;

  String get buscable => '$numero $ruta $vehiculo $conductor'.toLowerCase();

  factory Despacho.desdeJson(Map<String, dynamic> json) => Despacho(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    fecha: fechaDeJson(json['fecha'] as String),
    pedidosDesde: fechaDeJsonOpcional(json['pedidosDesde']),
    pedidosHasta: fechaDeJsonOpcional(json['pedidosHasta']),
    rutaId: json['rutaId'] as int,
    ruta: json['ruta'] as String? ?? '',
    diaVisita: json['diaVisita'] as String?,
    rutaIds: [for (final r in (json['rutaIds'] as List? ?? const [])) r as int],
    rutas: [for (final r in (json['rutas'] as List? ?? const [])) r as String],
    vehiculoId: json['vehiculoId'] as int,
    vehiculo: json['vehiculo'] as String? ?? '',
    conductorId: json['conductorId'] as int,
    conductor: json['conductor'] as String? ?? '',
    estado: json['estado'] as String? ?? EstadoDespacho.armado,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    pedidos: json['pedidos'] as int? ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    entregados: json['entregados'] as int? ?? 0,
    noEntregados: json['noEntregados'] as int? ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => DespachoPedido.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ResumenDespachos {
  const ResumenDespachos({
    required this.total,
    required this.armados,
    required this.pedidosEnRuta,
  });

  final int total;
  final int armados;

  /// Pedidos que están en un camión y todavía no se entregaron.
  final int pedidosEnRuta;

  factory ResumenDespachos.desdeJson(Map<String, dynamic> json) => ResumenDespachos(
    total: json['total'] as int? ?? 0,
    armados: json['armados'] as int? ?? 0,
    pedidosEnRuta: json['pedidosEnRuta'] as int? ?? 0,
  );
}

/// Un mercado o unidad de medida que se puede elegir para recortar el
/// reporte de carga: solo lo que ese camión lleva.
class OpcionMercadoCarga {
  const OpcionMercadoCarga({
    required this.id,
    required this.nombre,
    required this.pedidos,
  });

  final int id;
  final String nombre;
  final int pedidos;

  factory OpcionMercadoCarga.desdeJson(Map<String, dynamic> json) => OpcionMercadoCarga(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    pedidos: json['pedidos'] as int? ?? 0,
  );
}

class OpcionUnidadCarga {
  const OpcionUnidadCarga({
    required this.codigo,
    required this.nombre,
    required this.productos,
  });

  final String codigo;
  final String nombre;
  final int productos;

  factory OpcionUnidadCarga.desdeJson(Map<String, dynamic> json) => OpcionUnidadCarga(
    codigo: json['codigo'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    productos: json['productos'] as int? ?? 0,
  );
}

/// Un corte de horario del reporte de carga: el camión se sube en tandas y cada
/// corte muestra solo lo que cambió respecto al anterior. El código 0 es todo
/// el camión, sin recortar.
class OpcionCorteCarga {
  const OpcionCorteCarga({required this.codigo, required this.nombre});

  /// 0 = Todos; 1, 2 y 3 son el primer, segundo y tercer corte.
  final int codigo;

  /// Ya viene dicho como se lee en el papel, con las horas del corte.
  final String nombre;

  factory OpcionCorteCarga.desdeJson(Map<String, dynamic> json) => OpcionCorteCarga(
    codigo: json['codigo'] as int? ?? 0,
    nombre: json['nombre'] as String? ?? '',
  );
}

class OpcionesCarga {
  const OpcionesCarga({
    required this.mercados,
    required this.unidades,
    this.cortes = const [],
  });

  final List<OpcionMercadoCarga> mercados;
  final List<OpcionUnidadCarga> unidades;

  /// Vacío si el servidor no ofrece cortes: entonces la hoja no muestra el
  /// selector y el reporte sale del camión completo, como antes.
  final List<OpcionCorteCarga> cortes;

  factory OpcionesCarga.desdeJson(Map<String, dynamic> json) => OpcionesCarga(
    mercados: (json['mercados'] as List? ?? const [])
        .map((e) => OpcionMercadoCarga.desdeJson(e as Map<String, dynamic>))
        .toList(),
    unidades: (json['unidades'] as List? ?? const [])
        .map((e) => OpcionUnidadCarga.desdeJson(e as Map<String, dynamic>))
        .toList(),
    cortes: (json['cortes'] as List? ?? const [])
        .map((e) => OpcionCorteCarga.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
