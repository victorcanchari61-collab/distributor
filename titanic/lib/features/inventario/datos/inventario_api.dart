import '../../../core/red/cliente_api.dart';
import 'almacen.dart';
import 'kardex.dart';
import 'lote.dart';
import 'stock.dart';

/// Llamadas del modulo de inventario.
class InventarioApi {
  const InventarioApi(this._api);

  final ClienteApi _api;

  // --- Almacenes ---

  /// GET /api/almacen
  Future<List<Almacen>> almacenes() async {
    final datos = await _api.get('/almacen') as List;
    return datos.map((e) => Almacen.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/almacen
  Future<Almacen> crearAlmacen(Map<String, dynamic> cuerpo) async => Almacen.desdeJson(
    await _api.post('/almacen', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/almacen/{id}
  Future<Almacen> actualizarAlmacen(int id, Map<String, dynamic> cuerpo) async =>
      Almacen.desdeJson(
        await _api.put('/almacen/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  // --- Stock ---

  /// GET /api/inventario/stock. Sin almacenId, suma todos.
  Future<List<Stock>> stock({int? almacenId}) async {
    final query = almacenId == null ? '' : '?almacenId=$almacenId';
    final datos = await _api.get('/inventario/stock$query') as List;
    return datos.map((e) => Stock.desdeJson(e as Map<String, dynamic>)).toList();
  }

  // --- Kardex ---

  /// GET /api/inventario/kardex. Sin almacenId, trae todos los movimientos.
  Future<List<MovimientoKardex>> kardex({int? almacenId}) async {
    final query = almacenId == null ? '' : '?almacenId=$almacenId';
    final datos = await _api.get('/inventario/kardex$query') as List;
    return datos
        .map((e) => MovimientoKardex.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Lotes ---

  /// GET /api/inventario/lotes
  Future<List<Lote>> lotes() async {
    final datos = await _api.get('/inventario/lotes') as List;
    return datos.map((e) => Lote.desdeJson(e as Map<String, dynamic>)).toList();
  }
}
