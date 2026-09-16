import '../../../compartido/fechas.dart';

/// Un cliente al que toca visitar ese día.
///
/// No es un documento: el backend la arma con el día de visita del cliente y
/// los pedidos de esa fecha. Por eso no tiene id propio ni se guarda nada al
/// mirarla.
class Visita {
  const Visita({
    required this.fecha,
    required this.dia,
    required this.clienteId,
    required this.cliente,
    required this.documento,
    this.direccion,
    this.mercado,
    this.telefono,
    this.rutaId,
    this.ruta,
    this.vendedorId,
    this.vendedor,
    required this.atendido,
    this.pedidoId,
    this.pedidoNumero,
    required this.total,
  });

  final DateTime fecha;

  /// LUNES, MARTES…: el día de visita del cliente.
  final String dia;

  final int clienteId;
  final String cliente;
  final String documento;
  final String? direccion;
  final String? mercado;
  final String? telefono;
  final int? rutaId;
  final String? ruta;
  final int? vendedorId;
  final String? vendedor;

  /// Si ya se le tomó pedido ese día: lo que separa lo hecho de lo que falta.
  final bool atendido;

  final int? pedidoId;
  final String? pedidoNumero;
  final double total;

  String get buscable =>
      '$cliente $documento ${mercado ?? ''} ${direccion ?? ''} ${ruta ?? ''}'
          .toLowerCase();

  factory Visita.desdeJson(Map<String, dynamic> json) => Visita(
    fecha: fechaDeJson(json['fecha'] as String),
    dia: json['dia'] as String? ?? '',
    clienteId: json['clienteId'] as int? ?? 0,
    cliente: json['cliente'] as String? ?? '',
    documento: json['documento'] as String? ?? '',
    direccion: json['direccion'] as String?,
    mercado: json['mercado'] as String?,
    telefono: json['telefono'] as String?,
    rutaId: json['rutaId'] as int?,
    ruta: json['ruta'] as String?,
    vendedorId: json['vendedorId'] as int?,
    vendedor: json['vendedor'] as String?,
    atendido: json['atendido'] as bool? ?? false,
    pedidoId: json['pedidoId'] as int?,
    pedidoNumero: json['pedidoNumero'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
  );
}

class ResumenVisitas {
  const ResumenVisitas({
    required this.programadas,
    required this.atendidas,
    required this.pendientes,
    required this.total,
  });

  final int programadas;
  final int atendidas;
  final int pendientes;
  final double total;

  /// Qué parte de lo programado ya tiene pedido.
  int get cobertura =>
      programadas == 0 ? 0 : (atendidas * 100 / programadas).round();

  factory ResumenVisitas.desdeJson(Map<String, dynamic> json) => ResumenVisitas(
    programadas: json['programadas'] as int? ?? 0,
    atendidas: json['atendidas'] as int? ?? 0,
    pendientes: json['pendientes'] as int? ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
  );
}

class EstadoDevolucion {
  const EstadoDevolucion._();

  static const solicitada = 'SOLICITADA';
  static const aprobada = 'APROBADA';
  static const rechazada = 'RECHAZADA';
}

/// Una línea de lo que el cliente trajo de vuelta.
class LineaDevolucion {
  const LineaDevolucion({
    required this.id,
    required this.producto,
    required this.codigo,
    required this.unidadBase,
    this.presentacion,
    required this.cantidadPresentacion,
    required this.cantidad,
    required this.precioUnitario,
    required this.importe,
    required this.reingresaStock,
  });

  final int id;
  final String producto;
  final String codigo;
  final String unidadBase;
  final String? presentacion;
  final double cantidadPresentacion;
  final double cantidad;
  final double precioUnitario;
  final double importe;

  /// Si vuelve al stock vendible. En falso entra y sale como merma: un producto
  /// abierto o golpeado no se puede volver a vender.
  final bool reingresaStock;

  factory LineaDevolucion.desdeJson(Map<String, dynamic> json) =>
      LineaDevolucion(
        id: json['id'] as int,
        producto: json['producto'] as String? ?? '',
        codigo: json['codigo'] as String? ?? '',
        unidadBase: json['unidadBase'] as String? ?? '',
        presentacion: json['presentacion'] as String?,
        cantidadPresentacion:
            (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
        precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0,
        importe: (json['importe'] as num?)?.toDouble() ?? 0,
        reingresaStock: json['reingresaStock'] as bool? ?? true,
      );
}

/// Lo que un cliente trae de vuelta de una venta.
///
/// No se registra aquí: nace de editarle la cantidad a la nota de venta. Esta
/// pantalla es para verlas todas juntas y resolverlas.
class Devolucion {
  const Devolucion({
    required this.id,
    required this.numero,
    required this.fecha,
    required this.notaVenta,
    required this.cliente,
    required this.almacen,
    required this.estado,
    this.motivo,
    this.observacion,
    this.motivoRechazo,
    this.usuario,
    this.aprobadoPor,
    this.resueltaEn,
    required this.total,
    required this.detalle,
  });

  final int id;
  final String numero;
  final DateTime fecha;
  final String notaVenta;
  final String cliente;
  final String almacen;
  final String estado;
  final String? motivo;
  final String? observacion;
  final String? motivoRechazo;
  final String? usuario;
  final String? aprobadoPor;
  final DateTime? resueltaEn;
  final double total;
  final List<LineaDevolucion> detalle;

  bool get pendiente => estado == EstadoDevolucion.solicitada;

  String get buscable =>
      '$numero $notaVenta $cliente ${motivo ?? ''}'.toLowerCase();

  factory Devolucion.desdeJson(Map<String, dynamic> json) => Devolucion(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    fecha: fechaDeJson(json['fecha'] as String),
    notaVenta: json['notaVenta'] as String? ?? '',
    cliente: json['cliente'] as String? ?? '',
    almacen: json['almacen'] as String? ?? '',
    estado: json['estado'] as String? ?? EstadoDevolucion.solicitada,
    motivo: json['motivo'] as String?,
    observacion: json['observacion'] as String?,
    motivoRechazo: json['motivoRechazo'] as String?,
    usuario: json['usuario'] as String?,
    aprobadoPor: json['aprobadoPor'] as String?,
    resueltaEn: fechaDeJsonOpcional(json['resueltaEn']),
    total: (json['total'] as num?)?.toDouble() ?? 0,
    detalle: ((json['detalle'] as List?) ?? const [])
        .map((e) => LineaDevolucion.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ResumenDevoluciones {
  const ResumenDevoluciones({
    required this.total,
    required this.solicitadas,
    required this.aprobadas,
    required this.importe,
  });

  final int total;
  final int solicitadas;
  final int aprobadas;
  final double importe;

  factory ResumenDevoluciones.desdeJson(Map<String, dynamic> json) =>
      ResumenDevoluciones(
        total: json['total'] as int? ?? 0,
        solicitadas: json['solicitadas'] as int? ?? 0,
        aprobadas: json['aprobadas'] as int? ?? 0,
        importe: (json['importe'] as num?)?.toDouble() ?? 0,
      );
}
