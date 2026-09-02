import '../../../core/red/cliente_api.dart';
import 'cliente.dart';
import 'proveedor.dart';

/// Llamadas de clientes y proveedores.
class MaestrosApi {
  const MaestrosApi(this._api);

  final ClienteApi _api;

  // --- Clientes ---

  /// GET /api/cliente
  Future<List<Cliente>> clientes() async {
    final datos = await _api.get('/cliente') as List;
    return datos.map((e) => Cliente.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/cliente
  Future<Cliente> crearCliente(Map<String, dynamic> cuerpo) async =>
      Cliente.desdeJson(await _api.post('/cliente', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PUT /api/cliente/{id}
  Future<Cliente> actualizarCliente(int id, Map<String, dynamic> cuerpo) async =>
      Cliente.desdeJson(await _api.put('/cliente/$id', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PATCH /api/cliente/{id}/activar | /desactivar
  Future<Cliente> cambiarEstadoCliente(int id, {required bool activo}) async =>
      Cliente.desdeJson(
        await _api.patch('/cliente/$id/${activo ? 'activar' : 'desactivar'}')
            as Map<String, dynamic>,
      );

  // --- Proveedores ---

  /// GET /api/proveedor
  Future<List<Proveedor>> proveedores() async {
    final datos = await _api.get('/proveedor') as List;
    return datos.map((e) => Proveedor.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/proveedor
  Future<Proveedor> crearProveedor(Map<String, dynamic> cuerpo) async =>
      Proveedor.desdeJson(await _api.post('/proveedor', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PUT /api/proveedor/{id}
  Future<Proveedor> actualizarProveedor(int id, Map<String, dynamic> cuerpo) async =>
      Proveedor.desdeJson(
        await _api.put('/proveedor/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/proveedor/{id}/activar | /desactivar
  Future<Proveedor> cambiarEstadoProveedor(int id, {required bool activo}) async =>
      Proveedor.desdeJson(
        await _api.patch('/proveedor/$id/${activo ? 'activar' : 'desactivar'}')
            as Map<String, dynamic>,
      );
}
