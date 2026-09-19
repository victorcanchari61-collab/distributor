import '../../../core/red/cliente_api.dart';
import 'dashboard_modelos.dart';

/// Llamadas de los dashboards.
///
/// Cada tablero tiene su endpoint y su permiso (`dashboard.*`): se piden por
/// separado para que uno que falla, o al que la persona no tiene acceso, no le
/// quite a los demás su gráfico.
class DashboardApi {
  const DashboardApi(this._api);

  final ClienteApi _api;

  /// GET /api/dashboard/ventas?desde=&hasta=
  Future<DashboardVentas> ventas(DateTime desde, DateTime hasta) async =>
      DashboardVentas.desdeJson(await _pedir('ventas', desde, hasta));

  /// GET /api/dashboard/ganancias?desde=&hasta= (el tablero de Rentabilidad)
  Future<DashboardGanancias> ganancias(DateTime desde, DateTime hasta) async =>
      DashboardGanancias.desdeJson(await _pedir('ganancias', desde, hasta));

  /// GET /api/dashboard/cobranza?desde=&hasta=
  Future<DashboardCobranza> cobranza(DateTime desde, DateTime hasta) async =>
      DashboardCobranza.desdeJson(await _pedir('cobranza', desde, hasta));

  /// GET /api/dashboard/inventario — la foto de hoy, sin rango.
  Future<DashboardInventario> inventario() async =>
      DashboardInventario.desdeJson(await _pedir('inventario'));

  /// GET /api/dashboard/reparto?desde=&hasta=
  Future<DashboardReparto> reparto(DateTime desde, DateTime hasta) async =>
      DashboardReparto.desdeJson(await _pedir('reparto', desde, hasta));

  Future<Map<String, dynamic>> _pedir(
    String tablero, [
    DateTime? desde,
    DateTime? hasta,
  ]) async {
    final rango = desde == null || hasta == null
        ? ''
        : '?desde=${_dia(desde)}&hasta=${_dia(hasta)}';
    return await _api.get('/dashboard/$tablero$rango') as Map<String, dynamic>;
  }

  static String _dia(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';
}
