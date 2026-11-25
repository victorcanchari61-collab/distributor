import '../../../compartido/fechas.dart';

/// De donde sale lo que se devuelve al proveedor.
class OrigenDevolucion {
  const OrigenDevolucion._();

  /// Ya habia llegado: sale del stock.
  static const recibido = 'RECIBIDO';

  /// Nunca llego: no mueve stock.
  static const pendiente = 'PENDIENTE';
}

/// Que da el proveedor a cambio.
class ResolucionDevolucion {
  const ResolucionDevolucion._();

  /// Lo trae otro dia: vuelve a quedar por recibir en la compra.
  static const reposicion = 'REPOSICION';

  /// No lo repone: la compra baja. Si ya estaba pagada, queda saldo a favor.
  static const descuento = 'DESCUENTO';

  static String etiqueta(String r) =>
      r == reposicion ? 'Reposición' : 'Descuento';
}

/// Una linea devuelta: cuanto, de donde sale y que da el proveedor a cambio.
class LineaDevolucionProveedor {
  const LineaDevolucionProveedor({
    required this.id,
    required this.producto,
    required this.codigo,
    required this.unidadBase,
    required this.cantidad,
    required this.importe,
    required this.origen,
    required this.resolucion,
  });

  final int id;
  final String producto;
  final String codigo;
  final String unidadBase;

  /// En unidad base.
  final double cantidad;
  final double importe;
  final String origen;
  final String resolucion;

  factory LineaDevolucionProveedor.desdeJson(Map<String, dynamic> json) =>
      LineaDevolucionProveedor(
        id: json['id'] as int,
        producto: json['producto'] as String? ?? '',
        codigo: json['codigo'] as String? ?? '',
        unidadBase: json['unidadBase'] as String? ?? '',
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
        importe: (json['importe'] as num?)?.toDouble() ?? 0,
        origen: json['origen'] as String? ?? OrigenDevolucion.recibido,
        resolucion:
            json['resolucion'] as String? ?? ResolucionDevolucion.descuento,
      );
}

/// Lo que se le devolvio a un proveedor de una compra.
class DevolucionProveedor {
  const DevolucionProveedor({
    required this.id,
    required this.numero,
    required this.compraId,
    required this.compraNumero,
    required this.proveedorId,
    required this.proveedor,
    required this.fecha,
    required this.estado,
    required this.motivo,
    this.observacion,
    this.almacen,
    this.documentoInventario,
    this.fechaReposicion,
    this.serieNotaCredito,
    this.numeroNotaCredito,
    required this.montoDescuento,
    required this.saldoFavorGenerado,
    required this.montoReposicion,
    this.usuario,
    required this.detalle,
  });

  final int id;
  final String numero;
  final int compraId;
  final String compraNumero;
  final int proveedorId;
  final String proveedor;
  final DateTime fecha;

  /// CONFIRMADA o ANULADA.
  final String estado;
  final String motivo;
  final String? observacion;
  final String? almacen;
  final String? documentoInventario;
  final DateTime? fechaReposicion;
  final String? serieNotaCredito;
  final String? numeroNotaCredito;

  /// Lo que bajo el total de la compra.
  final double montoDescuento;

  /// De lo descontado, lo que ya estaba pagado y quedo como saldo a favor.
  final double saldoFavorGenerado;

  /// Lo que el proveedor va a reponer, a su costo.
  final double montoReposicion;
  final String? usuario;
  final List<LineaDevolucionProveedor> detalle;

  bool get anulada => estado == 'ANULADA';

  String get buscable =>
      '$numero $compraNumero $proveedor $motivo'.toLowerCase();

  factory DevolucionProveedor.desdeJson(Map<String, dynamic> json) =>
      DevolucionProveedor(
        id: json['id'] as int,
        numero: json['numero'] as String? ?? '',
        compraId: json['compraId'] as int,
        compraNumero: json['compraNumero'] as String? ?? '',
        proveedorId: json['proveedorId'] as int,
        proveedor: json['proveedor'] as String? ?? '',
        fecha: fechaDeJson(json['fecha'] as String),
        estado: json['estado'] as String? ?? 'CONFIRMADA',
        motivo: json['motivo'] as String? ?? '',
        observacion: json['observacion'] as String?,
        almacen: json['almacen'] as String?,
        documentoInventario: json['documentoInventario'] as String?,
        fechaReposicion: json['fechaReposicion'] == null
            ? null
            : fechaDeJson(json['fechaReposicion'] as String),
        serieNotaCredito: json['serieNotaCredito'] as String?,
        numeroNotaCredito: json['numeroNotaCredito'] as String?,
        montoDescuento: (json['montoDescuento'] as num?)?.toDouble() ?? 0,
        saldoFavorGenerado:
            (json['saldoFavorGenerado'] as num?)?.toDouble() ?? 0,
        montoReposicion: (json['montoReposicion'] as num?)?.toDouble() ?? 0,
        usuario: json['usuario'] as String?,
        detalle: (json['detalle'] as List? ?? const [])
            .map(
              (e) =>
                  LineaDevolucionProveedor.desdeJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

/// Un proveedor que debe devolver plata (o descontarla de su proxima compra).
class SaldoFavorProveedor {
  const SaldoFavorProveedor({
    required this.proveedorId,
    required this.proveedor,
    required this.saldo,
    required this.totalGenerado,
    required this.ultimoMovimiento,
  });

  final int proveedorId;
  final String proveedor;
  final double saldo;
  final double totalGenerado;
  final DateTime ultimoMovimiento;

  factory SaldoFavorProveedor.desdeJson(Map<String, dynamic> json) =>
      SaldoFavorProveedor(
        proveedorId: json['proveedorId'] as int,
        proveedor: json['proveedor'] as String? ?? '',
        saldo: (json['saldo'] as num?)?.toDouble() ?? 0,
        totalGenerado: (json['totalGenerado'] as num?)?.toDouble() ?? 0,
        ultimoMovimiento: fechaDeJson(json['ultimoMovimiento'] as String),
      );
}
