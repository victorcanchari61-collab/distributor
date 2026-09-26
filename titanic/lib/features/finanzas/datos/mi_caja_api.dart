import '../../../core/red/cliente_api.dart';
import 'mi_caja.dart';

/// Llamadas de Mi Caja: la caja propia, sus movimientos y su cierre.
///
/// Ninguna recibe la cuenta: el servidor usa siempre la caja de quien pide,
/// asi nadie mueve la caja de otro desde aqui.
class MiCajaApi {
  const MiCajaApi(this._api);

  final ClienteApi _api;

  /// GET /api/micaja. Si el usuario no tiene caja asignada, el servidor
  /// responde con un error que lo dice.
  Future<MiCaja> mia() async =>
      MiCaja.desdeJson(await _api.get('/micaja') as Map<String, dynamic>);

  /// GET /api/micaja/movimientos?desde&hasta, dias en formato yyyy-MM-dd.
  Future<List<MovimientoCaja>> movimientos({
    required String desde,
    required String hasta,
  }) async {
    final datos =
        await _api.get('/micaja/movimientos?desde=$desde&hasta=$hasta') as List;
    return datos
        .map((e) => MovimientoCaja.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/gastooperativo/categorias/opciones?tipo=INGRESO|EGRESO
  Future<List<CategoriaMovimiento>> categorias(String tipo) async {
    final datos =
        await _api.get('/gastooperativo/categorias/opciones?tipo=$tipo')
            as List;
    return datos
        .map((e) => CategoriaMovimiento.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/micaja/movimiento: un ingreso o egreso libre.
  Future<void> registrarMovimiento(Map<String, dynamic> cuerpo) =>
      _api.post('/micaja/movimiento', cuerpo: cuerpo);

  /// GET /api/micaja/destinos: a quien se puede entregar lo contado.
  Future<List<CuentaDestino>> destinos() async {
    final datos = await _api.get('/micaja/destinos') as List;
    return datos
        .map((e) => CuentaDestino.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/micaja/cerrar
  Future<CierreCaja> cerrar(Map<String, dynamic> cuerpo) async =>
      CierreCaja.desdeJson(
        await _api.post('/micaja/cerrar', cuerpo: cuerpo)
            as Map<String, dynamic>,
      );
}
