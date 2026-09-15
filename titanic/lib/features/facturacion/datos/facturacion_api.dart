import '../../../core/red/cliente_api.dart';
import '../../../core/red/excepciones.dart';
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

  /// GET /api/listaprecio/{id}/resolver
  ///
  /// Qué precio corresponde a esa presentación por esa cantidad. La cantidad
  /// importa: el servidor elige el tramo más alto que alcanza, así que cinco
  /// sacos pueden costar menos por saco que cuatro.
  ///
  /// Devuelve null cuando esa forma de vender no tiene precio cargado: el
  /// endpoint responde 404 y eso no es un error que deba tumbar la pantalla.
  Future<double?> resolverPrecio(int listaId, int presentacionId, double cantidad) async {
    try {
      final dato =
          await _api.get(
                '/listaprecio/$listaId/resolver'
                '?presentacionId=$presentacionId&cantidad=$cantidad',
              )
              as Map<String, dynamic>;

      return (dato['precio'] as num?)?.toDouble();
    } on ApiExcepcion catch (e) {
      if (e.codigo == 404) return null;
      rethrow;
    }
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
