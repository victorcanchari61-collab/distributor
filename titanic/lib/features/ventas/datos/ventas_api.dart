import '../../../core/red/cliente_api.dart';
import 'cobro.dart';
import 'nota_venta.dart';
import 'pedido.dart';

/// Llamadas del modulo de ventas.
class VentasApi {
  const VentasApi(this._api);

  final ClienteApi _api;

  // --- Pedidos ---

  /// GET /api/pedido
  Future<List<Pedido>> pedidos() async {
    final datos = await _api.get('/pedido') as List;
    return datos.map((e) => Pedido.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/pedido
  Future<Pedido> crearPedido(Map<String, dynamic> cuerpo) async => Pedido.desdeJson(
    await _api.post('/pedido', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/pedido/{id}. Solo mientras esta Pendiente.
  Future<Pedido> actualizarPedido(int id, Map<String, dynamic> cuerpo) async =>
      Pedido.desdeJson(
        await _api.put('/pedido/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/pedido/{id}/confirmar. Cierra el pedido y crea la NotaVenta.
  Future<NotaVenta> confirmarPedido(int id, Map<String, dynamic> cuerpo) async =>
      NotaVenta.desdeJson(
        await _api.patch('/pedido/$id/confirmar', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/pedido/{id}/anular
  Future<void> anularPedido(int id) async {
    await _api.patch('/pedido/$id/anular');
  }

  // --- Notas de venta ---

  /// GET /api/notaventa
  Future<List<NotaVenta>> notasVenta() async {
    final datos = await _api.get('/notaventa') as List;
    return datos.map((e) => NotaVenta.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/notaventa. Directa, sin pedido previo: el stock sale al momento.
  Future<NotaVenta> crearNotaVenta(Map<String, dynamic> cuerpo) async =>
      NotaVenta.desdeJson(
        await _api.post('/notaventa', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/notaventa/{id}/anular
  Future<void> anularNotaVenta(int id) async {
    await _api.patch('/notaventa/$id/anular');
  }

  // --- Cuentas por cobrar / pagos ---

  /// GET /api/notaventa/cuentasporcobrar
  Future<List<NotaVenta>> cuentasPorCobrar() async {
    final datos = await _api.get('/notaventa/cuentasporcobrar') as List;
    return datos.map((e) => NotaVenta.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/notaventa/miscobros
  Future<List<Cobro>> misCobros() async {
    final datos = await _api.get('/notaventa/miscobros') as List;
    return datos.map((e) => Cobro.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/notaventa/{id}/pagos
  Future<NotaVenta> registrarPagoNotaVenta(int id, Map<String, dynamic> cuerpo) async =>
      NotaVenta.desdeJson(
        await _api.post('/notaventa/$id/pagos', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/notaventa/{id}/pagos/{pagoId}
  Future<NotaVenta> actualizarPagoNotaVenta(
    int id,
    int pagoId,
    Map<String, dynamic> cuerpo,
  ) async => NotaVenta.desdeJson(
    await _api.put('/notaventa/$id/pagos/$pagoId', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// DELETE /api/notaventa/{id}/pagos/{pagoId} — anula, no borra.
  Future<NotaVenta> anularPagoNotaVenta(int id, int pagoId) async => NotaVenta.desdeJson(
    await _api.delete('/notaventa/$id/pagos/$pagoId') as Map<String, dynamic>,
  );
}
