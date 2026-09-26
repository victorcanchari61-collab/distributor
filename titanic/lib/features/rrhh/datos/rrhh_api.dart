import '../../../compartido/fechas.dart';
import '../../../core/red/cliente_api.dart';
import 'asistencia.dart';
import 'planilla.dart';

/// Llamadas de RR. HH.: asistencia, planilla semanal y feriados.
class RrhhApi {
  const RrhhApi(this._api);

  final ClienteApi _api;

  // --- Asistencia ---

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
  Future<ResumenAsistencia> resumenAsistencia(
    DateTime desde,
    DateTime hasta,
  ) async => ResumenAsistencia.desdeJson(
    await _api.get(
          '/asistencia/resumen?desde=${diaIso(desde)}&hasta=${diaIso(hasta)}',
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

  /// PUT /api/planilla/detalle/{id}: bonos y otros descuentos de un empleado.
  Future<Planilla> ajustarPlanilla(
    int detalleId, {
    required double bonos,
    required double otrosDescuentos,
    String? nota,
  }) async => Planilla.desdeJson(
    await _api.put(
          '/planilla/detalle/$detalleId',
          cuerpo: {
            'bonos': bonos,
            'otrosDescuentos': otrosDescuentos,
            'nota': nota,
          },
        )
        as Map<String, dynamic>,
  );

  /// POST /api/planilla/{id}/pagar
  Future<Planilla> pagarPlanilla(int id, int cuentaFinancieraId) async =>
      Planilla.desdeJson(
        await _api.post(
              '/planilla/$id/pagar',
              cuerpo: {'cuentaFinancieraId': cuentaFinancieraId},
            )
            as Map<String, dynamic>,
      );

  /// PATCH /api/planilla/{id}/anular: revierte el pago si ya estaba pagada.
  Future<void> anularPlanilla(int id) => _api.patch('/planilla/$id/anular');

  // --- Feriados ---

  /// GET /api/feriado
  Future<List<Feriado>> feriados() async {
    final datos = await _api.get('/feriado') as List;
    return datos
        .map((e) => Feriado.desdeJson(e as Map<String, dynamic>))
        .toList();
  }
}
