import '../../../core/red/cliente_api.dart';
import 'crm.dart';

/// La query de una petición: solo lo que trae valor.
String _query(Map<String, Object?> parametros) {
  final partes = <String>[
    for (final e in parametros.entries)
      if (e.value != null && '${e.value}'.isNotEmpty)
        '${e.key}=${Uri.encodeQueryComponent('${e.value}')}',
  ];
  return partes.isEmpty ? '' : '?${partes.join('&')}';
}

Map<String, dynamic> _mapa(dynamic json) => json as Map<String, dynamic>;

/// Llamadas del CRM: el seguimiento de clientes y los reportes de caída, y las
/// dos vistas del Dashboard que salen del mismo cálculo.
class CrmApi {
  const CrmApi(this._api);

  final ClienteApi _api;

  // --- Gestión y seguimiento ---

  /// GET /api/crm/seguimiento/catalogo — los resultados que se pueden elegir.
  Future<CatalogoSeguimiento> catalogo() async => CatalogoSeguimiento.desdeJson(
    _mapa(await _api.get('/crm/seguimiento/catalogo')),
  );

  /// GET /api/crm/seguimiento/clientes?buscar= — para elegir al cliente.
  Future<List<ClienteBuscado>> buscar(String texto) async {
    final datos =
        await _api.get('/crm/seguimiento/clientes${_query({'buscar': texto})}')
            as List;
    return [for (final e in datos) ClienteBuscado.desdeJson(_mapa(e))];
  }

  /// GET /api/crm/seguimiento/{id}/ficha
  Future<FichaCliente> ficha(int id) async => FichaCliente.desdeJson(
    _mapa(await _api.get('/crm/seguimiento/$id/ficha')),
  );

  /// GET /api/crm/seguimiento/{id}/gestiones
  Future<GestionesCliente> gestiones(int id) async =>
      GestionesCliente.desdeJson(
        _mapa(await _api.get('/crm/seguimiento/$id/gestiones')),
      );

  /// POST /api/crm/seguimiento/{id}/gestiones
  Future<Gestion> registrar(int clienteId, Map<String, dynamic> cuerpo) async =>
      Gestion.desdeJson(
        _mapa(
          await _api.post(
            '/crm/seguimiento/$clienteId/gestiones',
            cuerpo: cuerpo,
          ),
        ),
      );

  /// PUT /api/crm/seguimiento/gestiones/{id}
  Future<Gestion> actualizar(int id, Map<String, dynamic> cuerpo) async =>
      Gestion.desdeJson(
        _mapa(await _api.put('/crm/seguimiento/gestiones/$id', cuerpo: cuerpo)),
      );

  /// PUT /api/crm/seguimiento/gestiones/{id}/reprogramar
  Future<Gestion> reprogramar(int id, String proximoSeguimiento) async =>
      Gestion.desdeJson(
        _mapa(
          await _api.put(
            '/crm/seguimiento/gestiones/$id/reprogramar',
            cuerpo: {'proximoSeguimiento': proximoSeguimiento},
          ),
        ),
      );

  /// GET /api/crm/seguimiento/{id}/compras
  Future<ComprasCliente> compras(int id) async => ComprasCliente.desdeJson(
    _mapa(await _api.get('/crm/seguimiento/$id/compras')),
  );

  /// GET /api/crm/seguimiento/{id}/documentos
  Future<DocumentosCliente> documentos(int id) async =>
      DocumentosCliente.desdeJson(
        _mapa(await _api.get('/crm/seguimiento/$id/documentos')),
      );

  // --- Reportes ---

  /// GET /api/crm/caida — clientes frente al mismo tramo del año anterior.
  Future<CaidaClientes> caida({
    String? desde,
    String? hasta,
    EstadoCaida? estado,
  }) async => CaidaClientes.desdeJson(
    _mapa(
      await _api.get(
        '/crm/caida${_query({'desde': desde, 'hasta': hasta, 'estado': estado?.clave})}',
      ),
    ),
  );

  /// GET /api/crm/caida/{id}/productos — qué dejó de comprar ese cliente.
  Future<QueDejoDeComprar> queDejoDeComprar(
    int clienteId, {
    String? desde,
    String? hasta,
  }) async => QueDejoDeComprar.desdeJson(
    _mapa(
      await _api.get(
        '/crm/caida/$clienteId/productos${_query({'desde': desde, 'hasta': hasta})}',
      ),
    ),
  );

  /// GET /api/crm/vendedores
  Future<VendedoresCaida> vendedores({String? desde, String? hasta}) async =>
      VendedoresCaida.desdeJson(
        _mapa(
          await _api.get(
            '/crm/vendedores${_query({'desde': desde, 'hasta': hasta})}',
          ),
        ),
      );

  // --- Dashboard ---

  /// GET /api/dashboard/sin-ventas — productos que no se vendieron en N días.
  Future<ProductosSinVentas> sinVentas(int dias) async =>
      ProductosSinVentas.desdeJson(
        _mapa(await _api.get('/dashboard/sin-ventas${_query({'dias': dias})}')),
      );

  /// GET /api/dashboard/zonas — cómo le va a cada mercado o ruta.
  Future<ZonasCaida> zonas({
    String? desde,
    String? hasta,
    required String agrupar,
  }) async => ZonasCaida.desdeJson(
    _mapa(
      await _api.get(
        '/dashboard/zonas${_query({'desde': desde, 'hasta': hasta, 'agrupar': agrupar})}',
      ),
    ),
  );
}
