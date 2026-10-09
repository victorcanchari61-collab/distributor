import '../../../compartido/fechas.dart';
import '../../../core/red/cliente_api.dart';
import 'adelanto.dart';
import 'asistencia.dart';
import 'planilla.dart';

/// Llamadas de RR. HH.: asistencia, planilla semanal y feriados.
class RrhhApi {
  const RrhhApi(this._api);

  final ClienteApi _api;

  // --- Asistencia ---

  /// GET /api/asistencia/empleados: todos, con sus fechas de ingreso y cese.
  Future<List<EmpleadoAsistencia>> empleadosAsistencia() async {
    final datos = await _api.get('/asistencia/empleados') as List;
    return datos
        .map((e) => EmpleadoAsistencia.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/asistencia?desde&hasta: las marcas del rango, anuladas incluidas.
  Future<List<Asistencia>> asistencias(DateTime desde, DateTime hasta) async {
    final datos =
        await _api.get(
              '/asistencia?desde=${diaIso(desde)}&hasta=${diaIso(hasta)}',
            )
            as List;
    return datos
        .map((e) => Asistencia.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/asistencia/resumen?desde&hasta
  /// Con [empleadoId], solo las de esa persona.
  Future<ResumenAsistencia> resumenAsistencia(
    DateTime desde,
    DateTime hasta, {
    int? empleadoId,
  }) async => ResumenAsistencia.desdeJson(
    await _api.get(
          '/asistencia/resumen?desde=${diaIso(desde)}&hasta=${diaIso(hasta)}'
          '${empleadoId != null ? '&empleadoId=$empleadoId' : ''}',
        )
        as Map<String, dynamic>,
  );

  /// POST /api/asistencia/dia: el pase de lista de un dia, todo o nada. A
  /// quien ya tenia marca se le corrige; al resto se le registra.
  Future<({int creadas, int corregidas})> marcarDia(
    DateTime fecha,
    List<Map<String, dynamic>> marcas,
  ) async {
    final r =
        await _api.post(
              '/asistencia/dia',
              cuerpo: {'fecha': diaIso(fecha), 'marcas': marcas},
            )
            as Map<String, dynamic>;
    return (
      creadas: r['creadas'] as int? ?? 0,
      corregidas: r['corregidas'] as int? ?? 0,
    );
  }

  /// PUT /api/asistencia/{id}: solo el estado y la observacion.
  Future<void> editarAsistencia(
    int id, {
    required String estado,
    String? observacion,
  }) => _api.put(
    '/asistencia/$id',
    cuerpo: {'estado': estado, 'observacion': observacion},
  );

  /// PATCH /api/asistencia/{id}/anular: no se borra, queda el historial.
  Future<void> anularAsistencia(int id) => _api.patch('/asistencia/$id/anular');

  // --- Planilla semanal ---

  /// GET /api/planilla/semana?fecha: la de la semana que contiene esa fecha.
  /// Null si todavia no se armo (el servidor responde 204, sin cuerpo).
  Future<Planilla?> planillaSemana(DateTime fecha) async {
    final datos = await _api.get('/planilla/semana?fecha=${diaIso(fecha)}');
    return datos == null
        ? null
        : Planilla.desdeJson(datos as Map<String, dynamic>);
  }

  /// GET /api/planilla: todas las semanas armadas, pagadas o anuladas.
  Future<List<PlanillaResumen>> historialPlanillas() async {
    final datos = await _api.get('/planilla') as List;
    return datos
        .map((e) => PlanillaResumen.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/planilla/cuentas: de donde puede salir el pago.
  Future<List<CuentaPago>> cuentasPlanilla() async {
    final datos = await _api.get('/planilla/cuentas') as List;
    return datos
        .map((e) => CuentaPago.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/planilla/generar: arma la semana, o la recalcula si esta en
  /// borrador conservando los ajustes a mano.
  Future<Planilla> generarPlanilla(DateTime semana) async => Planilla.desdeJson(
    await _api.post('/planilla/generar', cuerpo: {'semana': diaIso(semana)})
        as Map<String, dynamic>,
  );

  /// PUT /api/planilla/detalle/{id}: bonos, otros descuentos y cuanto de sus
  /// adelantos se le descuenta esta semana (null: lo que le toca).
  Future<Planilla> ajustarPlanilla(
    int detalleId, {
    required double bonos,
    required double otrosDescuentos,
    String? nota,
    double? adelantos,
  }) async => Planilla.desdeJson(
    await _api.put(
          '/planilla/detalle/$detalleId',
          cuerpo: {
            'bonos': bonos,
            'otrosDescuentos': otrosDescuentos,
            'nota': nota,
            'adelantos': adelantos,
          },
        )
        as Map<String, dynamic>,
  );

  /// POST /api/planilla/{id}/pagar. Con dias sin marcar, el servidor no paga salvo que se
  /// confirme con [conDiasSinMarcar].
  Future<Planilla> pagarPlanilla(
    int id,
    int cuentaFinancieraId, {
    bool conDiasSinMarcar = false,
  }) async => Planilla.desdeJson(
    await _api.post(
          '/planilla/$id/pagar',
          cuerpo: {
            'cuentaFinancieraId': cuentaFinancieraId,
            'conDiasSinMarcar': conDiasSinMarcar,
          },
        )
        as Map<String, dynamic>,
  );

  /// PATCH /api/planilla/{id}/anular: revierte el pago si ya estaba pagada.
  Future<void> anularPlanilla(int id) => _api.patch('/planilla/$id/anular');

  // --- Adelantos ---

  /// GET /api/adelanto
  Future<List<Adelanto>> adelantos() async {
    final datos = await _api.get('/adelanto') as List;
    return datos
        .map((e) => Adelanto.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/adelanto/resumen
  Future<ResumenAdelantos> resumenAdelantos() async =>
      ResumenAdelantos.desdeJson(
        await _api.get('/adelanto/resumen') as Map<String, dynamic>,
      );

  /// GET /api/adelanto/{id}: con lo descontado semana por semana.
  Future<Adelanto> adelanto(int id) async => Adelanto.desdeJson(
    await _api.get('/adelanto/$id') as Map<String, dynamic>,
  );

  /// GET /api/adelanto/empleados: los activos, con su sueldo y lo que deben.
  Future<List<EmpleadoAdelanto>> empleadosAdelanto() async {
    final datos = await _api.get('/adelanto/empleados') as List;
    return datos
        .map((e) => EmpleadoAdelanto.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/adelanto/cuentas
  Future<List<CuentaPago>> cuentasAdelanto() async {
    final datos = await _api.get('/adelanto/cuentas') as List;
    return datos
        .map((e) => CuentaPago.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/adelanto
  Future<Adelanto> crearAdelanto(Map<String, dynamic> cuerpo) async =>
      Adelanto.desdeJson(
        await _api.post('/adelanto', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/adelanto/{id}/plan: desde que semana y de a cuanto.
  Future<Adelanto> cambiarPlanAdelanto(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Adelanto.desdeJson(
    await _api.put('/adelanto/$id/plan', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  /// PATCH /api/adelanto/{id}/anular: solo sin descuentos.
  Future<void> anularAdelanto(int id) => _api.patch('/adelanto/$id/anular');

  // --- Feriados ---

  /// GET /api/feriado
  Future<List<Feriado>> feriados() async {
    final datos = await _api.get('/feriado') as List;
    return datos
        .map((e) => Feriado.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/feriado
  Future<void> crearFeriado(Map<String, dynamic> cuerpo) =>
      _api.post('/feriado', cuerpo: cuerpo);

  /// PUT /api/feriado/{id}
  Future<void> actualizarFeriado(int id, Map<String, dynamic> cuerpo) =>
      _api.put('/feriado/$id', cuerpo: cuerpo);

  /// DELETE /api/feriado/{id}
  Future<void> eliminarFeriado(int id) => _api.delete('/feriado/$id');
}
