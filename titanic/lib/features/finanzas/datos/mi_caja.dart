import '../../../compartido/fechas.dart';

/// La caja de quien esta logueado: su propio dinero en la ruta.
class MiCaja {
  const MiCaja({
    required this.id,
    required this.nombre,
    required this.saldoActual,
  });

  final int id;
  final String nombre;

  /// Lo que deberia tener ahora en la mano.
  final double saldoActual;

  factory MiCaja.desdeJson(Map<String, dynamic> json) => MiCaja(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    saldoActual: (json['saldoActual'] as num? ?? 0).toDouble(),
  );
}

/// De donde viene cada movimiento, dicho como se entiende en la ruta.
class DocumentoMovimiento {
  const DocumentoMovimiento._();

  static const etiquetas = <String, String>{
    'PAGO_VENTA': 'Cobro de venta',
    'PAGO_COMPRA': 'Pago a proveedor',
    'MOVIMIENTO_OPERATIVO': 'Ingreso o egreso',
    'CIERRE_CAJA': 'Cierre de caja',
    'FALTANTE_CAJA': 'Faltante de cierre',
    'SOBRANTE_CAJA': 'Sobrante de cierre',
    'REVERSION': 'Anulación',
    'SALDO_INICIAL': 'Saldo inicial',
    'TRANSFERENCIA_INTERNA': 'Transferencia',
    'FINANCIAMIENTO': 'Préstamo recibido',
    'PAGO_FINANCIAMIENTO': 'Pago de préstamo',
    'RECUPERO_FALTANTE': 'Recupero de faltante',
  };

  static String etiqueta(String documento) => etiquetas[documento] ?? documento;
}

/// Un movimiento de la caja: lo que entro o salio y con que saldo quedo.
class MovimientoCaja {
  const MovimientoCaja({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.saldoResultante,
    required this.fecha,
    required this.documentoOrigen,
    this.observacion,
    this.anulado = false,
    this.esReversa = false,
  });

  final int id;

  /// INGRESO o EGRESO.
  final String tipo;
  final double monto;
  final double saldoResultante;
  final DateTime fecha;

  /// De donde viene: PAGO_VENTA, CIERRE_CAJA... ver [DocumentoMovimiento].
  final String documentoOrigen;

  final String? observacion;

  /// Tiene una reversa: ya no cuenta, pero queda en el historial.
  final bool anulado;

  /// Es la reversa de otro movimiento.
  final bool esReversa;

  /// Movio plata de verdad: ni lo anulado ni su reversa.
  bool get vigente => !anulado && !esReversa;

  bool get esIngreso => tipo == 'INGRESO';

  String get concepto => DocumentoMovimiento.etiqueta(documentoOrigen);

  String get buscable => '$concepto ${observacion ?? ''}'.toLowerCase();

  factory MovimientoCaja.desdeJson(Map<String, dynamic> json) => MovimientoCaja(
    id: json['id'] as int,
    tipo: json['tipo'] as String? ?? '',
    monto: (json['monto'] as num? ?? 0).toDouble(),
    saldoResultante: (json['saldoResultante'] as num? ?? 0).toDouble(),
    fecha: fechaDeJson(json['fecha'] as String),
    documentoOrigen: json['documentoOrigen'] as String? ?? '',
    observacion: json['observacion'] as String?,
    anulado: json['anulado'] as bool? ?? false,
    esReversa: json['esReversa'] as bool? ?? false,
  );
}

/// Una categoria para un ingreso o egreso libre.
class CategoriaMovimiento {
  const CategoriaMovimiento({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.origen,
  });

  final int id;
  final String nombre;

  /// INGRESO o EGRESO.
  final String tipo;

  /// OPERATIVO o NO_OPERATIVO.
  final String origen;

  String get etiqueta =>
      '$nombre · ${origen == 'OPERATIVO' ? 'Operativo' : 'No operativo'}';

  factory CategoriaMovimiento.desdeJson(Map<String, dynamic> json) =>
      CategoriaMovimiento(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        tipo: json['tipo'] as String? ?? '',
        origen: json['origen'] as String? ?? '',
      );
}

/// A quien se le puede entregar lo contado al cerrar: una caja o un banco.
class CuentaDestino {
  const CuentaDestino({
    required this.id,
    required this.nombre,
    required this.naturaleza,
  });

  final int id;
  final String nombre;
  final String naturaleza;

  String get etiqueta => switch (naturaleza) {
    'CAJA' => '$nombre · Caja',
    'BANCO' => '$nombre · Banco',
    'PASARELA' => '$nombre · Pasarela',
    _ => nombre,
  };

  factory CuentaDestino.desdeJson(Map<String, dynamic> json) => CuentaDestino(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    naturaleza: json['naturaleza'] as String? ?? '',
  );
}

/// Lo que dejo un cierre: cuanto se conto contra lo que habia que tener.
class CierreCaja {
  const CierreCaja({
    required this.saldoSistema,
    required this.contado,
    required this.diferencia,
    required this.cuentaDestino,
    required this.sinEmpleado,
  });

  final double saldoSistema;
  final double contado;

  /// Negativa: falto plata. Positiva: sobro.
  final double diferencia;

  final String cuentaDestino;

  /// El usuario no tiene empleado vinculado: su faltante no puede entrar en
  /// ninguna planilla hasta que se lo vincule.
  final bool sinEmpleado;

  factory CierreCaja.desdeJson(Map<String, dynamic> json) => CierreCaja(
    saldoSistema: (json['saldoSistema'] as num? ?? 0).toDouble(),
    contado: (json['contado'] as num? ?? 0).toDouble(),
    diferencia: (json['diferencia'] as num? ?? 0).toDouble(),
    cuentaDestino: json['cuentaDestino'] as String? ?? '',
    sinEmpleado: json['sinEmpleado'] as bool? ?? false,
  );
}

/// Un cobro o pago que hizo por Yape, Plin o transferencia: no pasa por su
/// caja —la plata va directo al banco—, pero es suyo.
class MovimientoDigital {
  const MovimientoDigital({
    required this.id,
    required this.fecha,
    required this.tipo,
    required this.documento,
    required this.metodoPago,
    required this.metodoTipo,
    required this.monto,
    required this.anulado,
    this.contraparte,
    this.cuenta,
    this.numeroOperacion,
    this.estadoVerificacion,
  });

  final int id;
  final DateTime fecha;

  /// COBRO (de una venta) o PAGO (a un proveedor).
  final String tipo;

  /// La nota de venta o la compra.
  final String documento;

  /// El cliente o el proveedor.
  final String? contraparte;
  final String metodoPago;

  /// BILLETERA_DIGITAL o TRANSFERENCIA.
  final String metodoTipo;
  final double monto;

  /// A que cuenta entro (o de cual salio).
  final String? cuenta;
  final bool anulado;

  /// Solo en cobros: con el se busca en el banco.
  final String? numeroOperacion;

  /// PENDIENTE, VERIFICADO o RECHAZADO en el banco. Nulo en pagos.
  final String? estadoVerificacion;

  bool get esCobro => tipo == 'COBRO';

  /// No aparecio en el banco: no cuenta como cobrado, se le descuenta.
  bool get rechazado => estadoVerificacion == 'RECHAZADO';

  String get buscable =>
      '$documento ${contraparte ?? ''} $metodoPago ${numeroOperacion ?? ''}'
          .toLowerCase();

  factory MovimientoDigital.desdeJson(Map<String, dynamic> json) =>
      MovimientoDigital(
        id: json['id'] as int,
        fecha: fechaDeJson(json['fecha'] as String),
        tipo: json['tipo'] as String? ?? '',
        documento: json['documento'] as String? ?? '',
        contraparte: json['contraparte'] as String?,
        metodoPago: json['metodoPago'] as String? ?? '',
        metodoTipo: json['metodoTipo'] as String? ?? '',
        monto: (json['monto'] as num? ?? 0).toDouble(),
        cuenta: json['cuenta'] as String?,
        anulado: json['anulado'] as bool? ?? false,
        numeroOperacion: json['numeroOperacion'] as String?,
        estadoVerificacion: json['estadoVerificacion'] as String?,
      );
}

/// Una fila de Mi Caja: un movimiento de la caja (efectivo) o un cobro o pago
/// por Yape o transferencia, que no pasa por la caja pero tambien es suyo.
class FilaMiCaja {
  const FilaMiCaja.efectivo(MovimientoCaja this.efectivo) : digital = null;
  const FilaMiCaja.digital(MovimientoDigital this.digital) : efectivo = null;

  final MovimientoCaja? efectivo;
  final MovimientoDigital? digital;

  bool get esEfectivo => efectivo != null;
  DateTime get fecha => efectivo?.fecha ?? digital!.fecha;
  bool get esIngreso => efectivo?.esIngreso ?? digital!.esCobro;
  double get monto => efectivo?.monto ?? digital!.monto;

  /// Movio plata de verdad: ni anulado, ni reversa, ni rechazado en el banco.
  bool get cuenta => efectivo != null
      ? efectivo!.vigente
      : !digital!.anulado && !digital!.rechazado;

  /// De donde viene, con las mismas claves que el efectivo: un cobro digital
  /// es un cobro de venta igual.
  String get concepto =>
      efectivo?.documentoOrigen ??
      (digital!.esCobro ? 'PAGO_VENTA' : 'PAGO_COMPRA');

  String get buscable => efectivo?.buscable ?? digital!.buscable;
}
