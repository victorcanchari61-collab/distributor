import '../../../core/red/cliente_api.dart';
import 'catalogo.dart';
import 'cliente.dart';
import 'producto.dart';
import 'proveedor.dart';

/// Llamadas de clientes, proveedores y productos.
class MaestrosApi {
  const MaestrosApi(this._api);

  final ClienteApi _api;

  // --- Clientes ---

  /// GET /api/cliente
  Future<List<Cliente>> clientes() async {
    final datos = await _api.get('/cliente') as List;
    return datos
        .map((e) => Cliente.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/cliente
  Future<Cliente> crearCliente(Map<String, dynamic> cuerpo) async =>
      Cliente.desdeJson(
        await _api.post('/cliente', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/cliente/{id}
  Future<Cliente> actualizarCliente(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Cliente.desdeJson(
    await _api.put('/cliente/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

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
    return datos
        .map((e) => Proveedor.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/proveedor
  Future<Proveedor> crearProveedor(Map<String, dynamic> cuerpo) async =>
      Proveedor.desdeJson(
        await _api.post('/proveedor', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/proveedor/{id}
  Future<Proveedor> actualizarProveedor(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Proveedor.desdeJson(
    await _api.put('/proveedor/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PATCH /api/proveedor/{id}/activar | /desactivar
  Future<Proveedor> cambiarEstadoProveedor(
    int id, {
    required bool activo,
  }) async => Proveedor.desdeJson(
    await _api.patch('/proveedor/$id/${activo ? 'activar' : 'desactivar'}')
        as Map<String, dynamic>,
  );

  // --- Productos ---

  /// GET /api/producto
  Future<List<Producto>> productos() async {
    final datos = await _api.get('/producto') as List;
    return datos
        .map((e) => Producto.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/producto
  Future<Producto> crearProducto(Map<String, dynamic> cuerpo) async =>
      Producto.desdeJson(
        await _api.post('/producto', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/producto/{id}
  Future<Producto> actualizarProducto(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Producto.desdeJson(
    await _api.put('/producto/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PATCH /api/producto/{id}/activar | /desactivar
  Future<Producto> cambiarEstadoProducto(int id, {required bool activo}) async =>
      Producto.desdeJson(
        await _api.patch('/producto/$id/${activo ? 'activar' : 'desactivar'}')
            as Map<String, dynamic>,
      );

  /// POST /api/producto/{productoId}/presentaciones
  Future<Presentacion> agregarPresentacion(
    int productoId,
    Map<String, dynamic> cuerpo,
  ) async => Presentacion.desdeJson(
    await _api.post('/producto/$productoId/presentaciones', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  /// PUT /api/producto/presentaciones/{presentacionId}
  Future<Presentacion> actualizarPresentacion(
    int presentacionId,
    Map<String, dynamic> cuerpo,
  ) async => Presentacion.desdeJson(
    await _api.put('/producto/presentaciones/$presentacionId', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  /// DELETE /api/producto/presentaciones/{presentacionId}
  Future<void> eliminarPresentacion(int presentacionId) =>
      _api.delete('/producto/presentaciones/$presentacionId');

  // --- Catalogos de apoyo ---

  /// GET /api/categoria
  Future<List<Categoria>> categorias() async {
    final datos = await _api.get('/categoria') as List;
    return datos
        .map((e) => Categoria.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/marca
  Future<List<Marca>> marcas() async {
    final datos = await _api.get('/marca') as List;
    return datos.map((e) => Marca.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/unidad
  Future<List<UnidadMedida>> unidades() async {
    final datos = await _api.get('/unidad') as List;
    return datos
        .map((e) => UnidadMedida.desdeJson(e as Map<String, dynamic>))
        .toList();
  }
}
