import '../../../core/red/cliente_api.dart';
import 'catalogo.dart';
import 'cliente.dart';
import 'empleado.dart';
import 'producto.dart';
import 'proveedor.dart';

/// Llamadas de clientes, proveedores, productos y empleados.
class MaestrosApi {
  const MaestrosApi(this._api);

  final ClienteApi _api;

  // --- Clientes ---

  /// GET /api/cliente
  ///
  /// Con [para] ("pedidos" o "notaventa") el servidor deja solo los clientes que quien pide puede
  /// vender: los de su ruta si tiene el alcance "mis clientes".
  Future<List<Cliente>> clientes({String? para}) async {
    final datos = await _api.get(para == null ? '/cliente' : '/cliente?para=$para') as List;
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

  // --- Empleados ---

  /// GET /api/empleado
  Future<List<Empleado>> empleados() async {
    final datos = await _api.get('/empleado') as List;
    return datos
        .map((e) => Empleado.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/empleado/opciones
  ///
  /// Solo los activos, para elegir uno al crear un usuario. Lo puede pedir
  /// quien administra usuarios aunque no tenga el maestro de Empleados: si no,
  /// no podria enlazar la cuenta con su ficha.
  Future<List<EmpleadoOpcion>> opcionesEmpleado() async {
    final datos = await _api.get('/empleado/opciones') as List;
    return datos
        .map((e) => EmpleadoOpcion.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/empleado
  Future<Empleado> crearEmpleado(Map<String, dynamic> cuerpo) async =>
      Empleado.desdeJson(
        await _api.post('/empleado', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/empleado/{id}
  Future<Empleado> actualizarEmpleado(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Empleado.desdeJson(
    await _api.put('/empleado/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PATCH /api/empleado/{id}/activar | /desactivar
  Future<Empleado> cambiarEstadoEmpleado(int id, {required bool activo}) async =>
      Empleado.desdeJson(
        await _api.patch('/empleado/$id/${activo ? 'activar' : 'desactivar'}')
            as Map<String, dynamic>,
      );

  /// DELETE /api/empleado/{id}
  ///
  /// Borrado definitivo. El backend lo rechaza si una cuenta usa la ficha.
  Future<void> eliminarEmpleado(int id) => _api.delete('/empleado/$id');

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

  /// POST /api/categoria
  Future<Categoria> crearCategoria(Map<String, dynamic> cuerpo) async =>
      Categoria.desdeJson(
        await _api.post('/categoria', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// GET /api/marca
  Future<List<Marca>> marcas() async {
    final datos = await _api.get('/marca') as List;
    return datos.map((e) => Marca.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/marca
  Future<Marca> crearMarca(Map<String, dynamic> cuerpo) async =>
      Marca.desdeJson(
        await _api.post('/marca', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// GET /api/unidad
  Future<List<UnidadMedida>> unidades() async {
    final datos = await _api.get('/unidad') as List;
    return datos
        .map((e) => UnidadMedida.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/unidad
  Future<UnidadMedida> crearUnidad(Map<String, dynamic> cuerpo) async =>
      UnidadMedida.desdeJson(
        await _api.post('/unidad', cuerpo: cuerpo) as Map<String, dynamic>,
      );
}
