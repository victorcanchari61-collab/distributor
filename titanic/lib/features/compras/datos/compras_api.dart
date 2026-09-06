import '../../../core/red/cliente_api.dart';
import 'compra.dart';
import 'orden_compra.dart';

/// Llamadas del modulo de compras.
class ComprasApi {
  const ComprasApi(this._api);

  final ClienteApi _api;

  // --- Ordenes de compra ---

  /// GET /api/ordencompra
  Future<List<OrdenCompra>> ordenesCompra() async {
    final datos = await _api.get('/ordencompra') as List;
    return datos
        .map((e) => OrdenCompra.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/ordencompra
  Future<OrdenCompra> crearOrdenCompra(Map<String, dynamic> cuerpo) async =>
      OrdenCompra.desdeJson(
        await _api.post('/ordencompra', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/ordencompra/{id}. Solo mientras esta Pendiente.
  Future<OrdenCompra> actualizarOrdenCompra(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => OrdenCompra.desdeJson(
    await _api.put('/ordencompra/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PATCH /api/ordencompra/{id}/confirmar. Cierra la orden y crea la Compra.
  Future<OrdenCompra> confirmarOrdenCompra(int id) async => OrdenCompra.desdeJson(
    await _api.patch('/ordencompra/$id/confirmar') as Map<String, dynamic>,
  );

  /// PATCH /api/ordencompra/{id}/anular
  Future<void> anularOrdenCompra(int id) async {
    await _api.patch('/ordencompra/$id/anular');
  }

  // --- Compras ---

  /// GET /api/compra
  Future<List<Compra>> compras() async {
    final datos = await _api.get('/compra') as List;
    return datos.map((e) => Compra.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/compra. Directa, sin orden previa: al contado, en el momento.
  Future<Compra> crearCompra(Map<String, dynamic> cuerpo) async =>
      Compra.desdeJson(await _api.post('/compra', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PUT /api/compra/{id}. Solo mientras esta Pendiente: sin nada recibido.
  Future<Compra> actualizarCompra(int id, Map<String, dynamic> cuerpo) async =>
      Compra.desdeJson(await _api.put('/compra/$id', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PATCH /api/compra/{id}/anular. Solo si nada se ha recibido.
  Future<void> anularCompra(int id) async {
    await _api.patch('/compra/$id/anular');
  }

  // --- Cuentas por pagar / pagos ---

  /// GET /api/compra/cuentasporpagar
  Future<List<Compra>> cuentasPorPagar() async {
    final datos = await _api.get('/compra/cuentasporpagar') as List;
    return datos.map((e) => Compra.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/compra/{id}/pagos
  Future<Compra> registrarPagoCompra(int id, Map<String, dynamic> cuerpo) async =>
      Compra.desdeJson(
        await _api.post('/compra/$id/pagos', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/compra/{id}/pagos/{pagoId}
  Future<Compra> actualizarPagoCompra(
    int id,
    int pagoId,
    Map<String, dynamic> cuerpo,
  ) async => Compra.desdeJson(
    await _api.put('/compra/$id/pagos/$pagoId', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// DELETE /api/compra/{id}/pagos/{pagoId} — anula, no borra.
  Future<Compra> anularPagoCompra(int id, int pagoId) async => Compra.desdeJson(
    await _api.delete('/compra/$id/pagos/$pagoId') as Map<String, dynamic>,
  );
}
