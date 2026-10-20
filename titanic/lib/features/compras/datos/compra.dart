import '../../../compartido/fechas.dart';

class EstadoCompra {
  const EstadoCompra._();
  static const pendiente = 'PENDIENTE';
  static const recibidaParcial = 'RECIBIDA_PARCIAL';
  static const recibidaTotal = 'RECIBIDA_TOTAL';
  static const anulada = 'ANULADA';
}

/// El comprobante que trae el proveedor por la compra.
class TipoComprobanteCompra {
  const TipoComprobanteCompra._();
  static const factura = 'FACTURA';
  static const boleta = 'BOLETA';
  static const notaVenta = 'NOTA_VENTA';
  static const todos = [factura, boleta, notaVenta];

  static String etiqueta(String tipo) => switch (tipo) {
    factura => 'Factura',
    boleta => 'Boleta',
    notaVenta => 'Nota de venta',
    _ => tipo,
  };
}

/// Como se paga la compra al proveedor.
class FormaPagoCompra {
  const FormaPagoCompra._();
  static const contado = 'CONTADO';
  static const credito = 'CREDITO';
}

/// La Boveda como opcion del metodo en efectivo, igual que `PAGO_BOVEDA` en el
/// panel web. No es un metodo del catalogo: es de donde sale la plata. En el
/// selector vale [id], y al guardar se manda como el metodo Efectivo con
/// `desdeBoveda`, para que el pago salga de la Boveda y no de la caja de quien
/// paga.
class PagoBoveda {
  const PagoBoveda._();

  /// El valor de la opcion en el selector: ningun id del catalogo es negativo.
  static const id = -1;

  static const nombre = 'Bóveda';

  /// Con su detalle, como las demas opciones del selector ("BCP · ...").
  static const opcion = '$nombre · El efectivo de la empresa';
}

/// El pago listo para el API: la opcion Boveda pasa a ser el metodo Efectivo
/// del catalogo (`efectivoId`) con `desdeBoveda`; las demas van tal cual.
Map<String, dynamic> cuerpoPagoCompra(
  int metodoPagoId,
  double monto,
  int? efectivoId,
) {
  final boveda = metodoPagoId == PagoBoveda.id;
  return {
    'metodoPagoId': boveda ? efectivoId ?? 0 : metodoPagoId,
    'monto': monto,
    'desdeBoveda': boveda,
  };
}

/// Una linea de una compra, con cuanto de ella ya llego al almacen.
class CompraDetalle {
  const CompraDetalle({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidadBase,
    this.presentacionId,
    this.presentacion,
    required this.cantidadPresentacion,
    required this.cantidad,
    required this.costoUnitario,
    required this.costoTotal,
    required this.cantidadRecibida,
    required this.cantidadPendiente,
  });

  final int id;
  final int productoId;
  final String codigo;
  final String producto;
  final String unidadBase;

  final int? presentacionId;
  final String? presentacion;
  final double cantidadPresentacion;

  final double cantidad;
  final double costoUnitario;
  final double costoTotal;

  final double cantidadRecibida;

  /// Cantidad - CantidadRecibida, en unidad base.
  final double cantidadPendiente;

  factory CompraDetalle.desdeJson(Map<String, dynamic> json) => CompraDetalle(
    id: json['id'] as int,
    productoId: json['productoId'] as int,
    codigo: json['codigo'] as String? ?? '',
    producto: json['producto'] as String? ?? '',
    unidadBase: json['unidadBase'] as String? ?? '',
    presentacionId: json['presentacionId'] as int?,
    presentacion: json['presentacion'] as String?,
    cantidadPresentacion:
        (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
    cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
    costoUnitario: (json['costoUnitario'] as num?)?.toDouble() ?? 0,
    costoTotal: (json['costoTotal'] as num?)?.toDouble() ?? 0,
    cantidadRecibida: (json['cantidadRecibida'] as num?)?.toDouble() ?? 0,
    cantidadPendiente: (json['cantidadPendiente'] as num?)?.toDouble() ?? 0,
  );
}

/// Un pago parcial: un metodo del catalogo y cuanto se pago con el.
class PagoCompra {
  const PagoCompra({
    required this.id,
    required this.metodoPagoId,
    required this.metodoPago,
    required this.monto,
    required this.fecha,
    this.usuario,
    this.anulado = false,
    this.desdeBoveda = false,
  });

  final int id;
  final int metodoPagoId;
  final String metodoPago;
  final double monto;
  final DateTime fecha;
  final String? usuario;
  final bool anulado;

  /// En efectivo, salio de la Boveda y no de la caja de quien pago. El metodo
  /// que trae es el Efectivo del catalogo, asi que solo esto lo distingue.
  final bool desdeBoveda;

  /// El valor del selector de metodo: la Boveda vuelve a ser su opcion.
  int get metodoElegido => desdeBoveda ? PagoBoveda.id : metodoPagoId;

  /// Como se lee el metodo: "Bóveda" y no "Efectivo" si salio de ahi.
  String get nombreMetodo => desdeBoveda ? PagoBoveda.nombre : metodoPago;

  factory PagoCompra.desdeJson(Map<String, dynamic> json) => PagoCompra(
    id: json['id'] as int,
    metodoPagoId: json['metodoPagoId'] as int,
    metodoPago: json['metodoPago'] as String? ?? '',
    monto: (json['monto'] as num?)?.toDouble() ?? 0,
    fecha: fechaDeJson(json['fecha'] as String),
    usuario: json['usuario'] as String?,
    anulado: json['anulado'] as bool? ?? false,
    // Un servidor anterior no lo manda: entonces nada salio de la Boveda.
    desdeBoveda: json['desdeBoveda'] as bool? ?? false,
  );
}

/// Una compra registrada, directa o nacida de confirmar una orden.
class Compra {
  const Compra({
    required this.id,
    required this.numero,
    required this.proveedorId,
    required this.proveedor,
    this.ordenCompraId,
    this.ordenCompraNumero,
    required this.fecha,
    required this.estado,
    required this.tipoComprobante,
    this.serieComprobante,
    this.numeroComprobante,
    required this.formaPago,
    this.observacion,
    this.usuario,
    required this.total,
    required this.detalle,
    required this.pagos,
    required this.totalPagado,
  });

  final int id;
  final String numero;
  final int proveedorId;
  final String proveedor;

  /// Si nacio de confirmar una orden, cual. Null si fue directa.
  final int? ordenCompraId;
  final String? ordenCompraNumero;

  final DateTime fecha;

  /// PENDIENTE, RECIBIDA_PARCIAL, RECIBIDA_TOTAL o ANULADA.
  final String estado;

  /// FACTURA, BOLETA o NOTA_VENTA.
  final String tipoComprobante;
  final String? serieComprobante;
  final String? numeroComprobante;

  /// CONTADO o CREDITO.
  final String formaPago;

  final String? observacion;
  final String? usuario;
  final double total;
  final List<CompraDetalle> detalle;

  /// Con que se pago. Puede ser mas de un metodo: un pago mixto.
  final List<PagoCompra> pagos;

  /// Suma de pagos. Si es menor que total, falta esa diferencia por pagar.
  final double totalPagado;

  String get buscable =>
      '$numero $proveedor ${numeroComprobante ?? ''}'.toLowerCase();

  factory Compra.desdeJson(Map<String, dynamic> json) => Compra(
    id: json['id'] as int,
    numero: json['numero'] as String? ?? '',
    proveedorId: json['proveedorId'] as int,
    proveedor: json['proveedor'] as String? ?? '',
    ordenCompraId: json['ordenCompraId'] as int?,
    ordenCompraNumero: json['ordenCompraNumero'] as String?,
    fecha: fechaDeJson(json['fecha'] as String),
    estado: json['estado'] as String? ?? EstadoCompra.pendiente,
    tipoComprobante:
        json['tipoComprobante'] as String? ?? TipoComprobanteCompra.factura,
    serieComprobante: json['serieComprobante'] as String?,
    numeroComprobante: json['numeroComprobante'] as String?,
    formaPago: json['formaPago'] as String? ?? FormaPagoCompra.contado,
    observacion: json['observacion'] as String?,
    usuario: json['usuario'] as String?,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    detalle: (json['detalle'] as List? ?? const [])
        .map((e) => CompraDetalle.desdeJson(e as Map<String, dynamic>))
        .toList(),
    pagos: (json['pagos'] as List? ?? const [])
        .map((e) => PagoCompra.desdeJson(e as Map<String, dynamic>))
        .toList(),
    totalPagado: (json['totalPagado'] as num?)?.toDouble() ?? 0,
  );
}
