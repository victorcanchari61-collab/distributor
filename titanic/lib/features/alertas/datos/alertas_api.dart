import '../../../core/red/cliente_api.dart';
import 'alerta.dart';

/// Llamadas del modulo de alertas.
class AlertasApi {
  const AlertasApi(this._api);

  final ClienteApi _api;

  /// GET /api/alertas. Se calcula al momento, sin tabla detras.
  Future<List<Alerta>> alertas() async {
    final datos = await _api.get('/alertas') as List;
    return datos.map((e) => Alerta.desdeJson(e as Map<String, dynamic>)).toList();
  }
}
