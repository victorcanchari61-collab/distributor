import '../../../core/red/cliente_api.dart';
import 'despacho.dart';

/// Llamadas del modulo de Despachos.
class DespachoApi {
  const DespachoApi(this._api);

  final ClienteApi _api;

  /// GET /api/despacho
  Future<List<Despacho>> despachos() async {
    final datos = await _api.get('/despacho') as List;
    return datos.map((e) => Despacho.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/despacho/resumen
  Future<ResumenDespachos> resumen() async =>
      ResumenDespachos.desdeJson(await _api.get('/despacho/resumen') as Map<String, dynamic>);

  /// GET /api/despacho/disponibles
  ///
  /// `despachoId` se manda al editar: sin él, los pedidos que ya son de ese
  /// despacho se verían como tomados y desaparecerían de la pantalla.
  ///
  /// Varias rutas: un camión atiende más de una el mismo día. Con [diaVisita] (LUNES … SABADO) solo salen los
  /// clientes que se visitan ese día; sin él, de cualquier día.
  Future<List<DespachoPedido>> disponibles(
    List<int> rutaIds, {
    int? despachoId,
    String? diaVisita,
  }) async {
    final partes = [
      for (final id in rutaIds) 'rutaIds=$id',
      if (despachoId != null) 'despachoId=$despachoId',
      if (diaVisita != null) 'diaVisita=$diaVisita',
    ];
    final datos = await _api.get('/despacho/disponibles?${partes.join('&')}') as List;
    return datos.map((e) => DespachoPedido.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/vehiculo/{id}/recorrido
  ///
  /// Las rutas que recorre el vehículo cada día: LUNES … DOMINGO → ids. Solo los días con salida.
  Future<Map<String, List<int>>> recorridoDe(int vehiculoId) async {
    final dato = await _api.get('/vehiculo/$vehiculoId/recorrido') as Map<String, dynamic>;
    final dias = (dato['dias'] as Map<String, dynamic>?) ?? const {};
    return {
      for (final e in dias.entries) e.key: [for (final r in (e.value as List)) r as int],
    };
  }

  /// GET /api/despacho/{id}/carga/opciones
  Future<OpcionesCarga> opcionesCarga(int id) async => OpcionesCarga.desdeJson(
    await _api.get('/despacho/$id/carga/opciones') as Map<String, dynamic>,
  );

  /// POST /api/despacho
  Future<Despacho> crear(Map<String, dynamic> cuerpo) async =>
      Despacho.desdeJson(await _api.post('/despacho', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PUT /api/despacho/{id}
  Future<Despacho> actualizar(int id, Map<String, dynamic> cuerpo) async => Despacho.desdeJson(
    await _api.put('/despacho/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PATCH /api/despacho/{id}/anular
  Future<Despacho> anular(int id) async =>
      Despacho.desdeJson(await _api.patch('/despacho/$id/anular') as Map<String, dynamic>);

  /// GET /api/despacho/{id}/pdf/carga, con los filtros ya armados en la query.
  Future<List<int>> pdfCarga(int id, String query) =>
      _api.archivo('/despacho/$id/pdf/carga${query.isEmpty ? '' : '?$query'}');

  /// GET /api/despacho/{id}/pdf/clientes
  Future<List<int>> pdfClientes(int id) => _api.archivo('/despacho/$id/pdf/clientes');
}
