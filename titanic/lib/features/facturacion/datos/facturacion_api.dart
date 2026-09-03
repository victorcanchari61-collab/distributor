import '../../../core/red/cliente_api.dart';
import 'lista_precio.dart';

/// Llamadas del modulo de facturacion.
class FacturacionApi {
  const FacturacionApi(this._api);

  final ClienteApi _api;

  /// GET /api/listaprecio
  Future<List<ListaPrecio>> listasPrecio() async {
    final datos = await _api.get('/listaprecio') as List;
    return datos.map((e) => ListaPrecio.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/listaprecio
  Future<ListaPrecio> crearLista(Map<String, dynamic> cuerpo) async => ListaPrecio.desdeJson(
    await _api.post('/listaprecio', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/listaprecio/{id}
  Future<ListaPrecio> actualizarLista(int id, Map<String, dynamic> cuerpo) async =>
      ListaPrecio.desdeJson(
        await _api.put('/listaprecio/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/listaprecio/{id}/predeterminada. Solo Administrador.
  Future<ListaPrecio> marcarPredeterminada(int id) async => ListaPrecio.desdeJson(
    await _api.patch('/listaprecio/$id/predeterminada') as Map<String, dynamic>,
  );

  /// DELETE /api/listaprecio/{id}. Solo Administrador.
  Future<void> eliminarLista(int id) async {
    await _api.delete('/listaprecio/$id');
  }

  /// GET /api/listaprecio/{id}/precios
  Future<List<Precio>> preciosDeLista(int listaId) async {
    final datos = await _api.get('/listaprecio/$listaId/precios') as List;
    return datos.map((e) => Precio.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// PUT /api/listaprecio/{id}/precios. Repetir presentacion y cantidad
  /// minima actualiza el precio existente en vez de duplicarlo: manda la
  /// lista de precios completa que debe quedar.
  Future<List<Precio>> guardarPrecios(
    int listaId,
    List<Map<String, dynamic>> precios,
  ) async {
    final datos =
        await _api.put('/listaprecio/$listaId/precios', cuerpo: {'precios': precios}) as List;
    return datos.map((e) => Precio.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// DELETE /api/listaprecio/precios/{precioId}
  Future<void> eliminarPrecio(int precioId) async {
    await _api.delete('/listaprecio/precios/$precioId');
  }
}
