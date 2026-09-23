import 'pedido.dart';
import '../../../compartido/fechas.dart';

class EstadoNotaVenta {
  const EstadoNotaVenta._();
  static const confirmada = 'CONFIRMADA';
  static const anulada = 'ANULADA';
}

/// Como se paga una venta al cliente.
class FormaPagoVenta {
  const FormaPagoVenta._();
  static const contado = 'CONTADO';
  static const credito = 'CREDITO';
  static const todas = [contado, credito];
}

/// Un pago parcial dentro de una nota de venta: un metodo y cuanto se pago.
class PagoVenta {
  const PagoVenta({
    required this.id,
    required this.metodoPagoId,
    required this.metodoPago,
    required this.monto,
    required this.fecha,
    this.usuario,
    this.anulado = false,
  });

  final int id;
  final int metodoPagoId;
  final String metodoPago;
  final double monto;
  final DateTime fecha;
  final String? usuario;
  final bool anulado;

  factory PagoVenta.desdeJson(Map<String, dynamic> json) => PagoVenta(
    id: json['id'] as int,
    metodoPagoId: json['metodoPagoId'] as int,
    metodoPago: json['metodoPago'] as String? ?? '',
    monto: (json['monto'] as num?)?.toDouble() ?? 0,
    fecha: fechaDeJson(json['fecha'] as String),
    usuario: json['usuario'] as String?,
    anulado: json['anulado'] as bool? ?? false,
  );
}

/// PENDIENTE: todavia no entra a ningun almacen (el repartidor no lo elige).
/// VERIFICADO: el encargado ya lo conto y eligio el almacen. ANULADO: se
/// anulo junto con la venta.
class EstadoRecojo {
  const EstadoRecojo._();
  static const pendiente = 'PENDIENTE';
  static const verificado = 'VERIFICADO';
  static const anulado = 'ANULADO';
}

/// Mercaderia de OTRA venta que se recogio al entregar esta: se descuenta
/// del total. No entra a stock al registrarla — queda Pendiente, igual que
/// una novedad de entrega, hasta que se verifica en Novedades de entrega y
/// recien ahi se elige el almacen.
class RecojoVenta {
  const RecojoVenta({
    required this.id,
    required this.fecha,
    required this.productoId,
    required this.producto,
    this.presentacion,
    required this.unidadBase,
    required this.cantidadPresentacion,
    this.almacenId,
    this.almacen,
    required this.motivo,
    this.observacion,
    this.usuario,
    required this.importe,
    this.estado = EstadoRecojo.pendiente,
    this.verificadoPor,
    this.verificadoEn,
  });

  final int id;
  final DateTime fecha;
  final int productoId;
  final String producto;
  final String? presentacion;
  final String unidadBase;
  final double cantidadPresentacion;

  /// Vacio mientras esta Pendiente: el almacen lo decide quien lo verifica.
  final int? almacenId;
  final String? almacen;

  final String motivo;
  final String? observacion;
  final String? usuario;
  final double importe;
  final String estado;
  final String? verificadoPor;
  final DateTime? verificadoEn;

  factory RecojoVenta.desdeJson(Map<String, dynamic> json) => RecojoVenta(
    id: json['id'] as int,
    fecha: fechaDeJson(json['fecha'] as String),
    productoId: json['productoId'] as int,
    producto: json['producto'] as String? ?? '',
    presentacion: json['presentacion'] as String?,
    unidadBase: json['unidadBase'] as String? ?? '',
    cantidadPresentacion:
        (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
    almacenId: json['almacenId'] as int?,
    almacen: json['almacen'] as String?,
    motivo: json['motivo'] as String? ?? '',
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    importe: (json['importe'] as num?)?.toDouble() ?? 0,
    estado: json['estado'] as String? ?? EstadoRecojo.pendiente,
    verificadoPor: json['verificadoPor'] as String?,
    verificadoEn: json['verificadoEn'] == null
        ? null
        : fechaDeJson(json['verificadoEn'] as String),
  );
}

/// Un recojo pendiente de verificar, visto desde Novedades de entrega — con
/// el contexto de la venta que lo desconto.
class RecojoPendiente {
  const RecojoPendiente({
    required this.id,
    required this.fecha,
    required this.notaVentaId,
    required this.notaVenta,
    required this.cliente,
    required this.productoId,
    required this.producto,
    this.presentacion,
    required this.unidadBase,
    required this.cantidadPresentacion,
    required this.motivo,
    this.observacion,
    this.usuario,
    required this.importe,
  });

  final int id;
  final DateTime fecha;
  final int notaVentaId;
  final String notaVenta;
  final String cliente;
  final int productoId;
  final String producto;
  final String? presentacion;
  final String unidadBase;
  final double cantidadPresentacion;
  final String motivo;
  final String? observacion;
  final String? usuario;
  final double importe;

  factory RecojoPendiente.desdeJson(Map<String, dynamic> json) =>
      RecojoPendiente(
        id: json['id'] as int,
        fecha: fechaDeJson(json['fecha'] as String),
        notaVentaId: json['notaVentaId'] as int,
        notaVenta: json['notaVenta'] as String? ?? '',
        cliente: json['cliente'] as String? ?? '',
        productoId: json['productoId'] as int,
        producto: json['producto'] as String? ?? '',
        presentacion: json['presentacion'] as String?,
        unidadBase: json['unidadBase'] as String? ?? '',
        cantidadPresentacion:
            (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
        motivo: json['motivo'] as String? ?? '',
        observacion: json['observacion'] as String?,
        usuario: json['usuario'] as String?,
        importe: (json['importe'] as num?)?.toDouble() ?? 0,
      );
}

/// Una venta lista tal cual: nacio de confirmar un pedido o se registro
/// directa. El stock ya salio al momento de crearla — no hay estados de
/// "recibido parcial" como en una compra.
class NotaVenta {
  const NotaVenta({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.cliente,
    this.pedidoId,
    this.pedidoNumero,
    required this.almacenId,
    required this.almacen,
    required this.fecha,
    required this.estado,
    required this.formaPago,
    this.observacion,
    this.usuario,
    required this.total,
    this.opGravada = 0,
    this.igv = 0,
    this.opExonerada = 0,
    required this.detalle,
    required this.pagos,
    required this.totalPagado,
    this.totalRecogido = 0,
    this.recojos = const [],
  });

  final int id;
  final String numero;
  final int clienteId;
  final String cliente;

  /// Si nacio de confirmar un pedido, cual. Null si fue directa.
  final int? pedidoId;
  final String? pedidoNumero;

  final int almacenId;
  final String almacen;

  final DateTime fecha;

  /// CONFIRMADA o ANULADA.
  final String estado;

  /// CONTADO o CREDITO.
  final String formaPago;

  final String? observacion;
  final String? usuario;
  final double total;

  /// Op. Gravada: lo cobrado SIN el IGV, de las líneas afectas.
  final double opGravada;

  /// El IGV de las líneas afectas: opGravada × 18%.
  final double igv;

  /// Lo cobrado por líneas no afectas (exoneradas). opGravada + igv + opExonerada = total.
  final double opExonerada;

  final List<LineaVenta> detalle;

  /// Con que se pago. Puede ser mas de un metodo — un pago mixto.
  final List<PagoVenta> pagos;

  /// Suma de pagos. Si es menor que total, falta esa diferencia por cobrar.
  final double totalPagado;

  /// Suma de los recojos vigentes. Ya esta restada de total; es informativo.
  final double totalRecogido;

  /// Mercaderia de otra venta que se recogio al entregar esta.
  final List<RecojoVenta> recojos;

  String get buscable => '$numero $cliente'.toLowerCase();

  factory NotaVenta.desdeJson(Map<String, dynamic> json) => NotaVenta(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    clienteId: json['clienteId'] as int,
    cliente: json['cliente'] as String? ?? '',
    pedidoId: json['pedidoId'] as int?,
    pedidoNumero: json['pedidoNumero'] as String?,
    almacenId: json['almacenId'] as int? ?? 0,
    almacen: json['almacen'] as String? ?? '',
    fecha: fechaDeJson(json['fecha'] as String),
    estado: json['estado'] as String? ?? EstadoNotaVenta.confirmada,
    formaPago: json['formaPago'] as String? ?? FormaPagoVenta.contado,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    opGravada: (json['opGravada'] as num?)?.toDouble() ?? 0,
    igv: (json['igv'] as num?)?.toDouble() ?? 0,
    opExonerada: (json['opExonerada'] as num?)?.toDouble() ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => LineaVenta.desdeJson(e as Map<String, dynamic>))
        .toList(),
    pagos: (json['pagos'] as List? ?? const [])
        .map((e) => PagoVenta.desdeJson(e as Map<String, dynamic>))
        .toList(),
    totalPagado: (json['totalPagado'] as num?)?.toDouble() ?? 0,
    totalRecogido: (json['totalRecogido'] as num?)?.toDouble() ?? 0,
    recojos: (json['recojos'] as List? ?? const [])
        .map((e) => RecojoVenta.desdeJson(e as Map<String, dynamic>))
        .toList(),
  );
}
