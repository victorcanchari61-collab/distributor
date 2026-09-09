import '../../../core/red/cliente_api.dart';
import 'arqueo.dart';
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

  /// GET /api/motivogasto
  Future<List<MotivoGasto>> motivosGasto() async {
    final datos = await _api.get('/motivogasto') as List;
    return datos
        .map((e) => MotivoGasto.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/arqueo/cuadres?desde=&hasta=
  Future<List<CuadrePendiente>> cuadres(DateTime desde, DateTime hasta) async {
    final datos =
        await _api.get(
              '/arqueo/cuadres?desde=${_dia(desde)}&hasta=${_dia(hasta)}',
            )
            as List;
    return datos
        .map((e) => CuadrePendiente.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/arqueo/detalle?fecha=&usuarioId=
  Future<DetalleCuadre> detalleCuadre(DateTime fecha, int usuarioId) async =>
      DetalleCuadre.desdeJson(
        await _api.get(
              '/arqueo/detalle?fecha=${_dia(fecha)}&usuarioId=$usuarioId',
            )
            as Map<String, dynamic>,
      );

  /// GET /api/arqueo/deudas
  Future<List<DeudaUsuario>> deudas() async {
    final datos = await _api.get('/arqueo/deudas') as List;
    return datos
        .map((e) => DeudaUsuario.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/arqueo
  Future<ArqueoCaja> registrarArqueo(Map<String, dynamic> cuerpo) async =>
      ArqueoCaja.desdeJson(
        await _api.post('/arqueo', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/arqueo/{id}/anular
  Future<ArqueoCaja> anularArqueo(int id) async => ArqueoCaja.desdeJson(
    await _api.patch('/arqueo/$id/anular') as Map<String, dynamic>,
  );

  /// PATCH /api/arqueo/{id}/saldar
  Future<ArqueoCaja> saldarFaltante(int id) async => ArqueoCaja.desdeJson(
    await _api.patch('/arqueo/$id/saldar') as Map<String, dynamic>,
  );

  static String _dia(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';
}
