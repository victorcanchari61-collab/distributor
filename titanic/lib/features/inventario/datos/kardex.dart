import '../../../compartido/fechas.dart';

/// Una línea del kardex: lo que entró o salió, con el saldo que dejó.
class MovimientoKardex {
  const MovimientoKardex({
    required this.id,
    required this.fecha,
    required this.documento,
    required this.motivo,
    required this.tipo,
    required this.productoId,
    required this.producto,
    required this.unidadBase,
    required this.almacen,
    this.presentacion,
    required this.cantidadPresentacion,
    required this.cantidad,
    required this.costoUnitario,
    required this.costoTotal,
    required this.saldo,
    required this.anulado,
  });

  final int id;
  final DateTime fecha;
  final String documento;
  final String motivo;

  /// ENTRADA o SALIDA.
  final String tipo;

  final int productoId;
  final String producto;
  final String unidadBase;
  final String almacen;

  /// Cómo se escribió: "2 Saco 50 kg".
  final String? presentacion;
  final double cantidadPresentacion;

  /// En unidad base, siempre positiva.
  final double cantidad;

  final double costoUnitario;
  final double costoTotal;

  /// Stock que quedó después de este movimiento.
  final double saldo;

  final bool anulado;

  bool get esEntrada => tipo == 'ENTRADA';

  /// Lo que aparta un pedido: no mueve stock, solo lo compromete.
  ///
  /// Se pregunta aparte porque no es ni entrada ni salida: sin esto caia en el
  /// "todo lo demas es salida" y el kardex mostraba lo contrario de lo que
  /// paso —mercaderia saliendo cuando en realidad sigue en el almacen.
  bool get esReserva => tipo == 'RESERVA';

  /// Texto contra el que se busca en la lista.
  String get buscable => '$documento $motivo $producto $almacen'.toLowerCase();

  factory MovimientoKardex.desdeJson(Map<String, dynamic> json) =>
      MovimientoKardex(
        id: json['id'] as int,
        fecha: fechaDeJson(json['fecha'] as String),
        documento: json['documento'] as String? ?? '',
        motivo: json['motivo'] as String? ?? '',
        tipo: json['tipo'] as String? ?? '',
        productoId: json['productoId'] as int,
        producto: json['producto'] as String? ?? '',
        unidadBase: json['unidadBase'] as String? ?? '',
        almacen: json['almacen'] as String? ?? '',
        presentacion: json['presentacion'] as String?,
        cantidadPresentacion:
            (json['cantidadPresentacion'] as num?)?.toDouble() ?? 0,
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
        costoUnitario: (json['costoUnitario'] as num?)?.toDouble() ?? 0,
        costoTotal: (json['costoTotal'] as num?)?.toDouble() ?? 0,
        saldo: (json['saldo'] as num?)?.toDouble() ?? 0,
        anulado: json['anulado'] as bool? ?? false,
      );
}
