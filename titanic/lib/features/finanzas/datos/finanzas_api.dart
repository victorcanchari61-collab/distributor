import '../../../core/red/cliente_api.dart';
import 'arqueo_caja.dart';
import 'metodo_pago.dart';

/// Llamadas del modulo de finanzas.
class FinanzasApi {
  const FinanzasApi(this._api);

  final ClienteApi _api;

  /// GET /api/metodopago
  Future<List<MetodoPago>> metodosPago() async {
    final datos = await _api.get('/metodopago') as List;
    return datos
        .map((e) => MetodoPago.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/metodopago
  Future<MetodoPago> crearMetodoPago(Map<String, dynamic> cuerpo) async =>
      MetodoPago.desdeJson(
        await _api.post('/metodopago', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/metodopago/{id}
  Future<MetodoPago> actualizarMetodoPago(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => MetodoPago.desdeJson(
    await _api.put('/metodopago/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// GET /api/arqueo/resumen?fecha=
  Future<ArqueoResumen> resumenArqueo(DateTime fecha) async =>
      ArqueoResumen.desdeJson(
        await _api.get('/arqueo/resumen?fecha=${fecha.toIso8601String().substring(0, 10)}')
            as Map<String, dynamic>,
      );

  /// GET /api/arqueo/historial
  Future<List<ArqueoCaja>> historialArqueo() async {
    final datos = await _api.get('/arqueo/historial') as List;
    return datos
        .map((e) => ArqueoCaja.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/arqueo
  Future<ArqueoCaja> registrarArqueo(Map<String, dynamic> cuerpo) async =>
      ArqueoCaja.desdeJson(
        await _api.post('/arqueo', cuerpo: cuerpo) as Map<String, dynamic>,
      );
}
