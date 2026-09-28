import '../../../compartido/fechas.dart';

double _monto(Object? v) => (v as num? ?? 0).toDouble();

/// De donde sale un movimiento del dinero para el resultado del negocio.
class OrigenDinero {
  const OrigenDinero._();

  static const operativo = 'OPERATIVO';
  static const noOperativo = 'NO_OPERATIVO';

  /// Plata que solo se movio de una cuenta propia a otra: no es ganar ni gastar.
  static const interno = 'INTERNO';

  static const todos = [operativo, noOperativo, interno];

  static String etiqueta(String origen) => switch (origen) {
    operativo => 'Operativo',
    noOperativo => 'No operativo',
    interno => 'Interno',
    _ => origen,
  };
}

/// Un renglon del kardex del dinero: lo que entro o salio de una caja o banco.
class MovimientoDinero {
  const MovimientoDinero({
    required this.id,
    required this.fecha,
    required this.cuentaFinancieraId,
    required this.cuenta,
    required this.tipo,
    required this.monto,
    required this.saldoResultante,
    required this.documentoOrigen,
    required this.concepto,
    required this.origen,
    required this.anulado,
    required this.esReversa,
    required this.anulable,
    this.categoria,
    this.observacion,
    this.usuario,
    this.movimientoOperativoId,
  });

  final int id;
  final DateTime fecha;
  final int cuentaFinancieraId;
  final String cuenta;

  /// INGRESO o EGRESO.
  final String tipo;
  final double monto;
  final double saldoResultante;
  final String documentoOrigen;

  /// Dicho como se entiende: "Cobro NV-0004 — Distribuciones ABC".
  final String concepto;
  final String? categoria;

  /// Ver [OrigenDinero].
  final String origen;

  final String? observacion;
  final String? usuario;

  /// Tiene una reversa: ya no cuenta.
  final bool anulado;

  /// Es la reversa de otro movimiento.
  final bool esReversa;

  /// El ingreso o egreso registrado a mano detras de este renglon, si lo hay.
  final int? movimientoOperativoId;

  /// Se puede anular desde aqui (solo los registrados a mano).
  final bool anulable;

  bool get esIngreso => tipo == 'INGRESO';

  /// Una de las dos mitades de una transferencia entre cuentas propias.
  bool get esTransferencia => documentoOrigen == 'TRANSFERENCIA_INTERNA';

  /// Cuenta para los totales: ni lo anulado ni su reversa movieron plata.
  bool get vigente => !anulado && !esReversa;

  String get buscable =>
      '$concepto ${categoria ?? ''} $cuenta ${observacion ?? ''} ${usuario ?? ''}'
          .toLowerCase();

  factory MovimientoDinero.desdeJson(Map<String, dynamic> json) =>
      MovimientoDinero(
        id: json['id'] as int,
        fecha: fechaDeJson(json['fecha'] as String),
        cuentaFinancieraId: json['cuentaFinancieraId'] as int? ?? 0,
        cuenta: json['cuenta'] as String? ?? '',
        tipo: json['tipo'] as String? ?? '',
        monto: _monto(json['monto']),
        saldoResultante: _monto(json['saldoResultante']),
        documentoOrigen: json['documentoOrigen'] as String? ?? '',
        concepto: json['concepto'] as String? ?? '',
        categoria: json['categoria'] as String?,
        origen: json['origen'] as String? ?? '',
        observacion: json['observacion'] as String?,
        usuario: json['usuario'] as String?,
        anulado: json['anulado'] as bool? ?? false,
        esReversa: json['esReversa'] as bool? ?? false,
        movimientoOperativoId: json['movimientoOperativoId'] as int?,
        anulable: json['anulable'] as bool? ?? false,
      );
}

/// Un renglon del estado de resultados: una categoria con lo que sumo.
class LineaResultado {
  const LineaResultado({
    required this.concepto,
    required this.monto,
    required this.movimientos,
  });

  final String concepto;
  final double monto;
  final int movimientos;

  factory LineaResultado.desdeJson(Map<String, dynamic> json) => LineaResultado(
    concepto: json['concepto'] as String? ?? '',
    monto: _monto(json['monto']),
    movimientos: json['movimientos'] as int? ?? 0,
  );
}

List<LineaResultado> _lineas(Object? v) => [
  for (final l in v as List? ?? const [])
    LineaResultado.desdeJson(l as Map<String, dynamic>),
];

/// Si el negocio gana en un rango: lo vendido menos lo que costo, menos los
/// gastos de operar. Lo no operativo va aparte y no suma.
class EstadoResultados {
  const EstadoResultados({
    required this.desde,
    required this.hasta,
    required this.ventasBrutas,
    required this.igv,
    required this.ventasNetas,
    required this.costoVentas,
    required this.utilidadBruta,
    required this.otrosIngresos,
    required this.totalOtrosIngresos,
    required this.gastosOperativos,
    required this.totalGastosOperativos,
    required this.utilidadOperativa,
    required this.ingresosNoOperativos,
    required this.totalIngresosNoOperativos,
    required this.egresosNoOperativos,
    required this.totalEgresosNoOperativos,
    required this.ventas,
    required this.lineasSinCosto,
    this.margenBruto,
    this.margenOperativo,
  });

  final DateTime desde;
  final DateTime hasta;
  final double ventasBrutas;
  final double igv;
  final double ventasNetas;
  final double costoVentas;
  final double utilidadBruta;
  final double? margenBruto;
  final List<LineaResultado> otrosIngresos;
  final double totalOtrosIngresos;
  final List<LineaResultado> gastosOperativos;
  final double totalGastosOperativos;
  final double utilidadOperativa;
  final double? margenOperativo;
  final List<LineaResultado> ingresosNoOperativos;
  final double totalIngresosNoOperativos;
  final List<LineaResultado> egresosNoOperativos;
  final double totalEgresosNoOperativos;
  final int ventas;
  final int lineasSinCosto;

  factory EstadoResultados.desdeJson(Map<String, dynamic> json) =>
      EstadoResultados(
        desde: fechaDeJson(json['desde'] as String),
        hasta: fechaDeJson(json['hasta'] as String),
        ventasBrutas: _monto(json['ventasBrutas']),
        igv: _monto(json['igv']),
        ventasNetas: _monto(json['ventasNetas']),
        costoVentas: _monto(json['costoVentas']),
        utilidadBruta: _monto(json['utilidadBruta']),
        margenBruto: (json['margenBruto'] as num?)?.toDouble(),
        otrosIngresos: _lineas(json['otrosIngresos']),
        totalOtrosIngresos: _monto(json['totalOtrosIngresos']),
        gastosOperativos: _lineas(json['gastosOperativos']),
        totalGastosOperativos: _monto(json['totalGastosOperativos']),
        utilidadOperativa: _monto(json['utilidadOperativa']),
        margenOperativo: (json['margenOperativo'] as num?)?.toDouble(),
        ingresosNoOperativos: _lineas(json['ingresosNoOperativos']),
        totalIngresosNoOperativos: _monto(json['totalIngresosNoOperativos']),
        egresosNoOperativos: _lineas(json['egresosNoOperativos']),
        totalEgresosNoOperativos: _monto(json['totalEgresosNoOperativos']),
        ventas: json['ventas'] as int? ?? 0,
        lineasSinCosto: json['lineasSinCosto'] as int? ?? 0,
      );
}

/// Como termino un cierre de caja.
class ResultadoCierre {
  const ResultadoCierre._();

  static const faltante = 'FALTANTE';
  static const sobrante = 'SOBRANTE';
  static const cuadro = 'CUADRO';

  static String etiqueta(String r) => switch (r) {
    faltante => 'Faltante',
    sobrante => 'Sobrante',
    _ => 'Cuadró',
  };
}

/// Un cierre de caja ya hecho: cuanto debia haber, cuanto se conto y a quien
/// se entrego.
class CierreRegistrado {
  const CierreRegistrado({
    required this.id,
    required this.fecha,
    required this.usuario,
    required this.caja,
    required this.saldoSistema,
    required this.contado,
    required this.diferencia,
    required this.cuentaDestino,
    required this.anulado,
    required this.sinEmpleado,
    this.observacion,
    this.estadoDescuento,
    this.saldoDescuento,
    this.billetes = 0,
    this.monedas = 0,
    this.digital = 0,
    this.digitalPorVerificar = 0,
    this.digitalRechazados = 0,
  });

  final int id;
  final DateTime fecha;
  final String usuario;
  final String caja;
  final double saldoSistema;
  final double contado;
  final double billetes;
  final double monedas;

  /// Lo cobrado por Yape o transferencia desde el cierre anterior hasta este,
  /// sin lo rechazado. No pasa por la caja: se verifica en el banco.
  final double digital;
  final int digitalPorVerificar;
  final int digitalRechazados;

  /// Negativa: falto plata. Positiva: sobro.
  final double diferencia;
  final String cuentaDestino;
  final String? observacion;
  final bool anulado;

  /// El faltante no puede entrar en ninguna planilla: el usuario no tiene
  /// empleado vinculado.
  final bool sinEmpleado;

  /// PENDIENTE, DESCONTADO o ANULADO; null si no hubo faltante.
  final String? estadoDescuento;
  final double? saldoDescuento;

  String get resultado => diferencia < 0
      ? ResultadoCierre.faltante
      : diferencia > 0
      ? ResultadoCierre.sobrante
      : ResultadoCierre.cuadro;

  String get buscable =>
      '$usuario $caja $cuentaDestino ${observacion ?? ''}'.toLowerCase();

  factory CierreRegistrado.desdeJson(Map<String, dynamic> json) {
    final descuento = json['descuento'] as Map<String, dynamic>?;
    return CierreRegistrado(
      id: json['id'] as int,
      fecha: fechaDeJson(json['fecha'] as String),
      usuario: json['usuario'] as String? ?? '',
      caja: json['caja'] as String? ?? '',
      saldoSistema: _monto(json['saldoSistema']),
      contado: _monto(json['contado']),
      diferencia: _monto(json['diferencia']),
      cuentaDestino: json['cuentaDestino'] as String? ?? '',
      observacion: json['observacion'] as String?,
      anulado: json['anulado'] as bool? ?? false,
      sinEmpleado: json['sinEmpleado'] as bool? ?? false,
      estadoDescuento: descuento?['estado'] as String?,
      saldoDescuento: descuento == null ? null : _monto(descuento['saldo']),
      billetes: _monto(json['billetes']),
      monedas: _monto(json['monedas']),
      digital: _monto(json['digital']),
      digitalPorVerificar: json['digitalPorVerificar'] as int? ?? 0,
      digitalRechazados: json['digitalRechazados'] as int? ?? 0,
    );
  }
}

/// Un billete o una moneda contada en un cierre.
class DenominacionContada {
  const DenominacionContada({
    required this.valor,
    required this.cantidad,
    required this.total,
    required this.esBillete,
  });

  final double valor;
  final int cantidad;
  final double total;
  final bool esBillete;

  factory DenominacionContada.desdeJson(Map<String, dynamic> json) =>
      DenominacionContada(
        valor: _monto(json['valor']),
        cantidad: json['cantidad'] as int? ?? 0,
        total: _monto(json['total']),
        esBillete: json['esBillete'] as bool? ?? false,
      );
}

/// Un movimiento de la caja dentro del periodo de un cierre.
class MovimientoCierre {
  const MovimientoCierre({
    required this.id,
    required this.fecha,
    required this.tipo,
    required this.monto,
    required this.documentoOrigen,
    required this.anulado,
    required this.esReversa,
    this.detalle,
  });

  final int id;
  final DateTime fecha;
  final String tipo;
  final double monto;
  final String documentoOrigen;

  /// La venta y el cliente, la categoria del gasto o lo escrito a mano.
  final String? detalle;
  final bool anulado;
  final bool esReversa;

  bool get esIngreso => tipo == 'INGRESO';

  /// Movio plata de verdad: ni lo anulado ni su reversa.
  bool get vigente => !anulado && !esReversa;

  factory MovimientoCierre.desdeJson(Map<String, dynamic> json) =>
      MovimientoCierre(
        id: json['id'] as int,
        fecha: fechaDeJson(json['fecha'] as String),
        tipo: json['tipo'] as String? ?? '',
        monto: _monto(json['monto']),
        documentoOrigen: json['documentoOrigen'] as String? ?? '',
        detalle: json['detalle'] as String?,
        anulado: json['anulado'] as bool? ?? false,
        esReversa: json['esReversa'] as bool? ?? false,
      );
}

/// Todo lo de un cierre para revisar si cuadra: el efectivo que paso por la
/// caja, lo cobrado digital que tiene que aparecer en el banco y los billetes
/// y monedas que se contaron.
class CierreDetalle {
  const CierreDetalle({
    required this.cierre,
    required this.saldoAnterior,
    required this.denominaciones,
    required this.efectivo,
    required this.digitales,
    this.desde,
  });

  final CierreRegistrado cierre;

  /// El cierre anterior de esa caja. Nulo si es el primero.
  final DateTime? desde;

  /// Lo que la caja ya tenia al empezar el periodo.
  final double saldoAnterior;

  /// Vacio en los cierres de antes de guardar el desglose.
  final List<DenominacionContada> denominaciones;
  final List<MovimientoCierre> efectivo;
  final List<CobroDigital> digitales;

  factory CierreDetalle.desdeJson(Map<String, dynamic> json) {
    final desde = json['desde'] as String?;
    List<Map<String, dynamic>> lista(String clave) =>
        (json[clave] as List? ?? const []).cast<Map<String, dynamic>>();
    return CierreDetalle(
      cierre: CierreRegistrado.desdeJson(
        json['cierre'] as Map<String, dynamic>,
      ),
      desde: desde == null ? null : fechaDeJson(desde),
      saldoAnterior: _monto(json['saldoAnterior']),
      denominaciones: lista(
        'denominaciones',
      ).map(DenominacionContada.desdeJson).toList(),
      efectivo: lista('efectivo').map(MovimientoCierre.desdeJson).toList(),
      digitales: lista('digitales').map(CobroDigital.desdeJson).toList(),
    );
  }
}

/// Un cobro por Yape, Plin o transferencia, para buscarlo en el banco por su
/// numero de operacion: si aparece se verifica; si no, se rechaza y se le
/// descuenta a quien lo cobro.
class CobroDigital {
  const CobroDigital({
    required this.id,
    required this.fecha,
    required this.documento,
    required this.metodoPago,
    required this.metodoTipo,
    required this.monto,
    required this.estado,
    required this.sinEmpleado,
    this.cliente,
    this.usuarioId,
    this.usuario,
    this.cuenta,
    this.numeroOperacion,
    this.verificadoPor,
    this.verificadoEn,
    this.observacion,
    this.estadoDescuento,
    this.saldoDescuento,
  });

  /// El id del pago de la venta.
  final int id;
  final DateTime fecha;
  final String documento;
  final String? cliente;

  /// Quien lo cobro: a quien se le descuenta si no aparece.
  final int? usuarioId;
  final String? usuario;
  final String metodoPago;

  /// BILLETERA_DIGITAL o TRANSFERENCIA.
  final String metodoTipo;

  /// La cuenta donde tiene que aparecer.
  final String? cuenta;
  final String? numeroOperacion;
  final double monto;

  /// PENDIENTE, VERIFICADO o RECHAZADO.
  final String estado;
  final String? verificadoPor;
  final DateTime? verificadoEn;
  final String? observacion;

  /// Solo si se rechazo: PENDIENTE, DESCONTADO o ANULADO.
  final String? estadoDescuento;
  final double? saldoDescuento;

  /// Se rechazo pero quien cobro no tiene empleado: no entra en planilla.
  final bool sinEmpleado;

  String get buscable =>
      '$documento ${cliente ?? ''} ${usuario ?? ''} ${numeroOperacion ?? ''}'
          .toLowerCase();

  factory CobroDigital.desdeJson(Map<String, dynamic> json) {
    final descuento = json['descuento'] as Map<String, dynamic>?;
    final verificadoEn = json['verificadoEn'] as String?;
    return CobroDigital(
      id: json['id'] as int,
      fecha: fechaDeJson(json['fecha'] as String),
      documento: json['documento'] as String? ?? '',
      cliente: json['cliente'] as String?,
      usuarioId: json['usuarioId'] as int?,
      usuario: json['usuario'] as String?,
      metodoPago: json['metodoPago'] as String? ?? '',
      metodoTipo: json['metodoTipo'] as String? ?? '',
      cuenta: json['cuenta'] as String?,
      numeroOperacion: json['numeroOperacion'] as String?,
      monto: _monto(json['monto']),
      estado: json['estado'] as String? ?? '',
      verificadoPor: json['verificadoPor'] as String?,
      verificadoEn: verificadoEn == null ? null : fechaDeJson(verificadoEn),
      observacion: json['observacion'] as String?,
      sinEmpleado: json['sinEmpleado'] as bool? ?? false,
      estadoDescuento: descuento?['estado'] as String?,
      saldoDescuento: descuento == null ? null : _monto(descuento['saldo']),
    );
  }
}

/// Estados de un prestamo recibido.
class EstadoPrestamo {
  const EstadoPrestamo._();

  static const vigente = 'VIGENTE';
  static const cancelado = 'CANCELADO';
  static const anulado = 'ANULADO';

  static const todos = [vigente, cancelado, anulado];

  static String etiqueta(String e) => switch (e) {
    vigente => 'Vigente',
    cancelado => 'Cancelado',
    anulado => 'Anulado',
    _ => e,
  };
}

/// Un pago de un prestamo recibido.
class PagoPrestamo {
  const PagoPrestamo({
    required this.id,
    required this.fecha,
    required this.monto,
    required this.cuentaFinanciera,
    required this.anulado,
    this.usuario,
    this.observacion,
  });

  final int id;
  final DateTime fecha;
  final double monto;
  final String cuentaFinanciera;
  final bool anulado;
  final String? usuario;
  final String? observacion;

  factory PagoPrestamo.desdeJson(Map<String, dynamic> json) => PagoPrestamo(
    id: json['id'] as int,
    fecha: fechaDeJson(json['fecha'] as String),
    monto: _monto(json['monto']),
    cuentaFinanciera: json['cuentaFinanciera'] as String? ?? '',
    anulado: json['anulado'] as bool? ?? false,
    usuario: json['usuario'] as String?,
    observacion: json['observacion'] as String?,
  );
}

/// Un prestamo recibido: la plata que entro y lo que falta devolver.
class Prestamo {
  const Prestamo({
    required this.id,
    required this.acreedor,
    required this.fecha,
    required this.montoRecibido,
    required this.totalADevolver,
    required this.pagado,
    required this.saldo,
    required this.estado,
    required this.cuentaFinanciera,
    required this.pagos,
    this.descripcion,
    this.usuario,
  });

  final int id;

  /// Banco o persona que presto.
  final String acreedor;
  final String? descripcion;
  final DateTime fecha;
  final double montoRecibido;

  /// Lo pactado, intereses incluidos.
  final double totalADevolver;
  final double pagado;
  final double saldo;

  /// Ver [EstadoPrestamo].
  final String estado;

  /// A donde entro la plata.
  final String cuentaFinanciera;
  final String? usuario;
  final List<PagoPrestamo> pagos;

  bool get vigente => estado == EstadoPrestamo.vigente;

  /// Lo que cuesta el prestamo: lo que se devuelve de mas.
  double get costo => totalADevolver - montoRecibido;

  String get buscable => '$acreedor ${descripcion ?? ''}'.toLowerCase();

  factory Prestamo.desdeJson(Map<String, dynamic> json) => Prestamo(
    id: json['id'] as int,
    acreedor: json['acreedor'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    fecha: fechaDeJson(json['fecha'] as String),
    montoRecibido: _monto(json['montoRecibido']),
    totalADevolver: _monto(json['totalADevolver']),
    pagado: _monto(json['pagado']),
    saldo: _monto(json['saldo']),
    estado: json['estado'] as String? ?? EstadoPrestamo.vigente,
    cuentaFinanciera: json['cuentaFinanciera'] as String? ?? '',
    usuario: json['usuario'] as String?,
    pagos: [
      for (final p in json['pagos'] as List? ?? const [])
        PagoPrestamo.desdeJson(p as Map<String, dynamic>),
    ],
  );
}

/// Una caja o cuenta bancaria, con su saldo real.
class CuentaFinanciera {
  const CuentaFinanciera({
    required this.id,
    required this.nombre,
    required this.naturaleza,
    required this.saldoActual,
    required this.activo,
    this.esBoveda = false,
    this.usuarioResponsableId,
    this.usuarioResponsable,
    this.bancoId,
    this.banco,
    this.numeroCuenta,
    this.cci,
    this.titular,
  });

  final int id;
  final String nombre;

  /// CAJA, BANCO o PASARELA.
  final String naturaleza;
  final double saldoActual;
  final bool activo;

  /// La caja de la empresa, sin responsable: adonde va el efectivo de los
  /// cierres. Solo efectivo.
  final bool esBoveda;

  /// Solo en una caja: de quien es.
  final int? usuarioResponsableId;
  final String? usuarioResponsable;

  /// Solo en una cuenta bancaria.
  final int? bancoId;
  final String? banco;
  final String? numeroCuenta;
  final String? cci;
  final String? titular;

  String get buscable =>
      '$nombre ${usuarioResponsable ?? ''} ${banco ?? ''} ${numeroCuenta ?? ''}'
          .toLowerCase();

  factory CuentaFinanciera.desdeJson(Map<String, dynamic> json) =>
      CuentaFinanciera(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        naturaleza: json['naturaleza'] as String? ?? '',
        saldoActual: _monto(json['saldoActual']),
        activo: json['activo'] as bool? ?? true,
        esBoveda: json['esBoveda'] as bool? ?? false,
        usuarioResponsableId: json['usuarioResponsableId'] as int?,
        usuarioResponsable: json['usuarioResponsable'] as String?,
        bancoId: json['bancoId'] as int?,
        banco: json['banco'] as String?,
        numeroCuenta: json['numeroCuenta'] as String?,
        cci: json['cci'] as String?,
        titular: json['titular'] as String?,
      );

  /// Lo que acepta el backend al editar: la cuenta tal cual, con su estado.
  Map<String, dynamic> aJson({bool? activo}) => {
    'nombre': nombre,
    'naturaleza': naturaleza,
    'usuarioResponsableId': usuarioResponsableId,
    'bancoId': bancoId,
    'numeroCuenta': numeroCuenta,
    'cci': cci,
    'titular': titular,
    'activo': activo ?? this.activo,
  };
}

/// Un banco del catalogo (BCP, BBVA...): de el cuelgan las cuentas bancarias.
class Banco {
  const Banco({required this.id, required this.nombre, required this.activo});

  final int id;
  final String nombre;
  final bool activo;

  factory Banco.desdeJson(Map<String, dynamic> json) => Banco(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
  );
}

/// Una categoria de ingresos y egresos, con su tipo y su origen.
class CategoriaFinanzas {
  const CategoriaFinanzas({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.origen,
    required this.activo,
    required this.esSistema,
    required this.usos,
    this.descripcion,
  });

  final int id;
  final String nombre;
  final String? descripcion;

  /// INGRESO o EGRESO.
  final String tipo;

  /// OPERATIVO o NO_OPERATIVO.
  final String origen;
  final bool activo;

  /// La usa el propio sistema (ventas, planilla, faltantes): no se edita ni
  /// se borra.
  final bool esSistema;

  /// Cuantos movimientos o plantillas la usan: con usos no se borra.
  final int usos;

  String get buscable => '$nombre ${descripcion ?? ''}'.toLowerCase();

  factory CategoriaFinanzas.desdeJson(Map<String, dynamic> json) =>
      CategoriaFinanzas(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        descripcion: json['descripcion'] as String?,
        tipo: json['tipo'] as String? ?? '',
        origen: json['origen'] as String? ?? '',
        activo: json['activo'] as bool? ?? true,
        esSistema: json['esSistema'] as bool? ?? false,
        usos: json['usos'] as int? ?? 0,
      );
}

/// Un gasto que se repite cada mes: alquiler, luz, internet.
class GastoRecurrente {
  const GastoRecurrente({
    required this.id,
    required this.nombre,
    required this.motivoGastoId,
    required this.motivoGasto,
    required this.montoEstimado,
    required this.diaVencimiento,
    required this.activo,
    this.cuentaFinancieraSugeridaId,
    this.cuentaFinancieraSugerida,
  });

  final int id;
  final String nombre;
  final int motivoGastoId;
  final String motivoGasto;
  final double montoEstimado;

  /// Que dia del mes vence.
  final int diaVencimiento;
  final int? cuentaFinancieraSugeridaId;
  final String? cuentaFinancieraSugerida;
  final bool activo;

  String get buscable => '$nombre $motivoGasto'.toLowerCase();

  factory GastoRecurrente.desdeJson(Map<String, dynamic> json) =>
      GastoRecurrente(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        motivoGastoId: json['motivoGastoId'] as int? ?? 0,
        motivoGasto: json['motivoGasto'] as String? ?? '',
        montoEstimado: _monto(json['montoEstimado']),
        diaVencimiento: json['diaVencimiento'] as int? ?? 1,
        cuentaFinancieraSugeridaId: json['cuentaFinancieraSugeridaId'] as int?,
        cuentaFinancieraSugerida: json['cuentaFinancieraSugerida'] as String?,
        activo: json['activo'] as bool? ?? true,
      );

  /// Lo que acepta el backend al editar: la plantilla tal cual, con su estado.
  Map<String, dynamic> aJson({bool? activo}) => {
    'nombre': nombre,
    'motivoGastoId': motivoGastoId,
    'montoEstimado': montoEstimado,
    'diaVencimiento': diaVencimiento,
    'cuentaFinancieraSugeridaId': cuentaFinancieraSugeridaId,
    'activo': activo ?? this.activo,
  };
}

/// Un gasto recurrente que toca pagar este mes y todavia no se pago.
class GastoPendiente {
  const GastoPendiente({
    required this.gastoRecurrenteId,
    required this.nombre,
    required this.motivoGastoId,
    required this.motivoGasto,
    required this.montoEstimado,
    required this.proximoVencimiento,
    required this.vencido,
    this.cuentaFinancieraSugeridaId,
  });

  final int gastoRecurrenteId;
  final String nombre;
  final int motivoGastoId;
  final String motivoGasto;
  final double montoEstimado;
  final int? cuentaFinancieraSugeridaId;
  final DateTime proximoVencimiento;
  final bool vencido;

  String get buscable => '$nombre $motivoGasto'.toLowerCase();

  factory GastoPendiente.desdeJson(Map<String, dynamic> json) => GastoPendiente(
    gastoRecurrenteId: json['gastoRecurrenteId'] as int,
    nombre: json['nombre'] as String? ?? '',
    motivoGastoId: json['motivoGastoId'] as int? ?? 0,
    motivoGasto: json['motivoGasto'] as String? ?? '',
    montoEstimado: _monto(json['montoEstimado']),
    cuentaFinancieraSugeridaId: json['cuentaFinancieraSugeridaId'] as int?,
    proximoVencimiento: fechaDeJson(json['proximoVencimiento'] as String),
    vencido: json['vencido'] as bool? ?? false,
  );
}
