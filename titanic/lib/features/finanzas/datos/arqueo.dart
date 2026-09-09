// Modelos del cuadre de caja del reparto: calcan los DTOs del backend
// (ArqueoResponses.cs / ArqueoRequests.cs).

/// En que estado esta el cuadre de una persona en un dia.
class EstadoCuadre {
  const EstadoCuadre._();

  /// Cobro ese dia y todavia no ha cuadrado.
  static const pendiente = 'pendiente';

  /// Cuadro y no hubo diferencia.
  static const cuadrado = 'cuadrado';

  static const conDiferencia = 'conDiferencia';
  static const anulado = 'anulado';

  static String etiqueta(String estado) => switch (estado) {
    pendiente => 'Pendiente',
    cuadrado => 'Cuadrado',
    conDiferencia => 'Con diferencia',
    anulado => 'Anulado',
    _ => estado,
  };
}

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Motivo de gasto de la ruta: pasaje, combustible, menu.
class MotivoGasto {
  const MotivoGasto({
    required this.id,
    required this.nombre,
    required this.activo,
    required this.usos,
    this.descripcion,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final int usos;

  factory MotivoGasto.desdeJson(Map<String, dynamic> json) => MotivoGasto(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    activo: json['activo'] as bool? ?? true,
    usos: json['usos'] as int? ?? 0,
  );
}

/// Una fila de la lista: un dia y una persona.
///
/// Aparece aunque nadie haya cuadrado todavia, que es justo a quien hay que ir
/// a buscar.
class CuadrePendiente {
  const CuadrePendiente({
    required this.fecha,
    required this.usuarioId,
    required this.usuario,
    required this.efectivo,
    required this.bancos,
    required this.total,
    required this.estado,
    required this.faltante,
    required this.faltanteSaldado,
    this.diferenciaEfectivo,
    this.arqueoId,
  });

  final DateTime fecha;
  final int usuarioId;
  final String usuario;

  /// Lo que el sistema dice que cobro en efectivo ese dia.
  final double efectivo;

  /// Lo que le entro por Yape, Plin o transferencia.
  final double bancos;

  final double total;

  /// Solo si ya cuadro. Negativa: falta dinero.
  final double? diferenciaEfectivo;

  final String estado;

  /// El cuadre registrado, si lo hay: para corregirlo o anularlo.
  final int? arqueoId;

  final double faltante;
  final bool faltanteSaldado;

  bool get cuadrado => arqueoId != null && estado != EstadoCuadre.anulado;

  factory CuadrePendiente.desdeJson(Map<String, dynamic> json) =>
      CuadrePendiente(
        fecha: DateTime.parse(json['fecha'] as String),
        usuarioId: json['usuarioId'] as int,
        usuario: json['usuario'] as String? ?? '',
        efectivo: _num(json['efectivo']),
        bancos: _num(json['bancos']),
        total: _num(json['total']),
        diferenciaEfectivo: (json['diferenciaEfectivo'] as num?)?.toDouble(),
        estado: json['estado'] as String? ?? EstadoCuadre.pendiente,
        arqueoId: json['arqueoId'] as int?,
        faltante: _num(json['faltante']),
        faltanteSaldado: json['faltanteSaldado'] as bool? ?? false,
      );
}

/// Un cobro concreto: de quien vino y cuanto.
class CobroDelDia {
  const CobroDelDia({
    required this.pagoId,
    required this.fecha,
    required this.cliente,
    required this.documento,
    required this.metodoPagoId,
    required this.metodoPago,
    required this.tipoMetodo,
    required this.monto,
    required this.esDeudaAnterior,
  });

  final int pagoId;
  final DateTime fecha;
  final String cliente;

  /// El documento al que se aplico: NV-000012.
  final String documento;

  final int metodoPagoId;
  final String metodoPago;
  final String tipoMetodo;
  final double monto;

  /// El cobro salda una venta de otro dia: deuda vieja cobrada en la ruta.
  final bool esDeudaAnterior;

  factory CobroDelDia.desdeJson(Map<String, dynamic> json) => CobroDelDia(
    pagoId: json['pagoId'] as int? ?? 0,
    fecha: DateTime.parse(json['fecha'] as String),
    cliente: json['cliente'] as String? ?? '',
    documento: json['documento'] as String? ?? '',
    metodoPagoId: json['metodoPagoId'] as int? ?? 0,
    metodoPago: json['metodoPago'] as String? ?? '',
    tipoMetodo: json['tipoMetodo'] as String? ?? '',
    monto: _num(json['monto']),
    esDeudaAnterior: json['esDeudaAnterior'] as bool? ?? false,
  );
}

class ArqueoGasto {
  const ArqueoGasto({
    required this.id,
    required this.motivoGastoId,
    required this.motivoGasto,
    required this.monto,
    this.descripcion,
  });

  final int id;
  final int motivoGastoId;
  final String motivoGasto;
  final double monto;
  final String? descripcion;

  factory ArqueoGasto.desdeJson(Map<String, dynamic> json) => ArqueoGasto(
    id: json['id'] as int? ?? 0,
    motivoGastoId: json['motivoGastoId'] as int? ?? 0,
    motivoGasto: json['motivoGasto'] as String? ?? '',
    monto: _num(json['monto']),
    descripcion: json['descripcion'] as String?,
  );
}

class ArqueoPagoDigital {
  const ArqueoPagoDigital({
    required this.id,
    required this.metodoPagoId,
    required this.metodoPago,
    required this.monto,
    this.pagoVentaId,
    this.clienteId,
    this.cliente,
    this.numeroOperacion,
  });

  final int id;

  /// El cobro del sistema que esta linea confirma.
  final int? pagoVentaId;

  final int? clienteId;
  final String? cliente;
  final int metodoPagoId;
  final String metodoPago;
  final String? numeroOperacion;
  final double monto;

  factory ArqueoPagoDigital.desdeJson(Map<String, dynamic> json) =>
      ArqueoPagoDigital(
        id: json['id'] as int? ?? 0,
        pagoVentaId: json['pagoVentaId'] as int?,
        clienteId: json['clienteId'] as int?,
        cliente: json['cliente'] as String?,
        metodoPagoId: json['metodoPagoId'] as int? ?? 0,
        metodoPago: json['metodoPago'] as String? ?? '',
        numeroOperacion: json['numeroOperacion'] as String?,
        monto: _num(json['monto']),
      );
}

/// El cuadre ya declarado por una persona en un dia.
class ArqueoCaja {
  const ArqueoCaja({
    required this.id,
    required this.fecha,
    required this.usuarioId,
    required this.usuario,
    required this.billetes,
    required this.monedas,
    required this.efectivoSistema,
    required this.bancosSistema,
    required this.totalEfectivoReal,
    required this.totalDigitalReal,
    required this.diferenciaEfectivo,
    required this.diferenciaBancos,
    required this.faltante,
    required this.sobrante,
    required this.faltanteSaldado,
    required this.estado,
    required this.fechaCreacion,
    required this.gastos,
    required this.pagosDigitales,
    this.fechaSaldado,
    this.observacion,
    this.registradoPor,
  });

  final int id;
  final DateTime fecha;
  final int usuarioId;
  final String usuario;

  final double billetes;
  final double monedas;

  final double efectivoSistema;
  final double bancosSistema;

  final double totalEfectivoReal;
  final double totalDigitalReal;
  final double diferenciaEfectivo;
  final double diferenciaBancos;

  /// Lo que la persona debe reponer, si falto dinero.
  final double faltante;

  /// Lo que trajo de mas. Solo se informa.
  final double sobrante;

  final bool faltanteSaldado;
  final DateTime? fechaSaldado;

  final String? observacion;
  final String estado;
  final String? registradoPor;
  final DateTime fechaCreacion;

  final List<ArqueoGasto> gastos;
  final List<ArqueoPagoDigital> pagosDigitales;

  factory ArqueoCaja.desdeJson(Map<String, dynamic> json) => ArqueoCaja(
    id: json['id'] as int,
    fecha: DateTime.parse(json['fecha'] as String),
    usuarioId: json['usuarioId'] as int? ?? 0,
    usuario: json['usuario'] as String? ?? '',
    billetes: _num(json['billetes']),
    monedas: _num(json['monedas']),
    efectivoSistema: _num(json['efectivoSistema']),
    bancosSistema: _num(json['bancosSistema']),
    totalEfectivoReal: _num(json['totalEfectivoReal']),
    totalDigitalReal: _num(json['totalDigitalReal']),
    diferenciaEfectivo: _num(json['diferenciaEfectivo']),
    diferenciaBancos: _num(json['diferenciaBancos']),
    faltante: _num(json['faltante']),
    sobrante: _num(json['sobrante']),
    faltanteSaldado: json['faltanteSaldado'] as bool? ?? false,
    fechaSaldado: json['fechaSaldado'] == null
        ? null
        : DateTime.parse(json['fechaSaldado'] as String),
    observacion: json['observacion'] as String?,
    estado: json['estado'] as String? ?? '',
    registradoPor: json['registradoPor'] as String?,
    fechaCreacion: DateTime.parse(json['fechaCreacion'] as String),
    gastos: [
      for (final g in (json['gastos'] as List? ?? const []))
        ArqueoGasto.desdeJson(g as Map<String, dynamic>),
    ],
    pagosDigitales: [
      for (final p in (json['pagosDigitales'] as List? ?? const []))
        ArqueoPagoDigital.desdeJson(p as Map<String, dynamic>),
    ],
  );
}

/// Todo lo necesario para cuadrar a una persona en un dia.
class DetalleCuadre {
  const DetalleCuadre({
    required this.fecha,
    required this.usuarioId,
    required this.usuario,
    required this.efectivoSistema,
    required this.bancosSistema,
    required this.efectivo,
    required this.digital,
    this.arqueo,
  });

  final DateTime fecha;
  final int usuarioId;
  final String usuario;

  final double efectivoSistema;
  final double bancosSistema;

  /// Los cobros en efectivo, uno a uno: sin ver de quien se cobro no hay forma
  /// de encontrar el faltante.
  final List<CobroDelDia> efectivo;

  final List<CobroDelDia> digital;

  /// Lo declarado, si ya se cuadro.
  final ArqueoCaja? arqueo;

  factory DetalleCuadre.desdeJson(Map<String, dynamic> json) => DetalleCuadre(
    fecha: DateTime.parse(json['fecha'] as String),
    usuarioId: json['usuarioId'] as int? ?? 0,
    usuario: json['usuario'] as String? ?? '',
    efectivoSistema: _num(json['efectivoSistema']),
    bancosSistema: _num(json['bancosSistema']),
    efectivo: [
      for (final c in (json['efectivo'] as List? ?? const []))
        CobroDelDia.desdeJson(c as Map<String, dynamic>),
    ],
    digital: [
      for (final c in (json['digital'] as List? ?? const []))
        CobroDelDia.desdeJson(c as Map<String, dynamic>),
    ],
    arqueo: json['arqueo'] == null
        ? null
        : ArqueoCaja.desdeJson(json['arqueo'] as Map<String, dynamic>),
  );
}

/// Lo que una persona debe por faltantes, para descontarselo.
class DeudaUsuario {
  const DeudaUsuario({
    required this.usuarioId,
    required this.usuario,
    required this.pendiente,
    required this.dias,
    required this.saldado,
    required this.detalle,
  });

  final int usuarioId;
  final String usuario;

  /// Faltantes todavia sin saldar.
  final double pendiente;

  final int dias;

  /// Lo ya descontado o repuesto.
  final double saldado;

  final List<ArqueoCaja> detalle;

  factory DeudaUsuario.desdeJson(Map<String, dynamic> json) => DeudaUsuario(
    usuarioId: json['usuarioId'] as int? ?? 0,
    usuario: json['usuario'] as String? ?? '',
    pendiente: _num(json['pendiente']),
    dias: json['dias'] as int? ?? 0,
    saldado: _num(json['saldado']),
    detalle: [
      for (final a in (json['detalle'] as List? ?? const []))
        ArqueoCaja.desdeJson(a as Map<String, dynamic>),
    ],
  );
}
