import '../../../core/red/cliente_api.dart';
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
}
