import '../../../core/red/cliente_api.dart';
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
}
