import '../../../core/red/cliente_api.dart';
import 'config_modelos.dart';

/// Llamadas del modulo de configuracion.
class ConfigApi {
  const ConfigApi(this._api);

  final ClienteApi _api;

  // --- Usuarios ---

  /// GET /api/usuario
  Future<List<Usuario>> usuarios() async {
    final datos = await _api.get('/usuario') as List;
    return datos
        .map((e) => Usuario.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/usuario
  Future<Usuario> crearUsuario(Map<String, dynamic> cuerpo) async =>
      Usuario.desdeJson(
        await _api.post('/usuario', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/usuario/{id}
  Future<Usuario> actualizarUsuario(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Usuario.desdeJson(
    await _api.put('/usuario/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  // --- Roles ---

  /// GET /api/rol
  Future<List<Rol>> roles() async {
    final datos = await _api.get('/rol') as List;
    return datos.map((e) => Rol.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/rol
  Future<Rol> crearRol(Map<String, dynamic> cuerpo) async => Rol.desdeJson(
    await _api.post('/rol', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/rol/{id}
  Future<Rol> actualizarRol(int id, Map<String, dynamic> cuerpo) async =>
      Rol.desdeJson(
        await _api.put('/rol/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/rol/{id}/permisos. Manda la matriz completa del rol.
  Future<Rol> actualizarPermisos(int id, List<Map<String, dynamic>> permisos) async =>
      Rol.desdeJson(
        await _api.put('/rol/$id/permisos', cuerpo: {'permisos': permisos})
            as Map<String, dynamic>,
      );

  // --- Consultas a SUNAT ---

  /// GET /api/consulta/ruc/{ruc}
  Future<ConsultaRuc> consultarRuc(String ruc) async => ConsultaRuc.desdeJson(
    await _api.get('/consulta/ruc/$ruc') as Map<String, dynamic>,
  );

  // --- Empresas ---

  /// GET /api/empresa
  Future<List<Empresa>> empresas() async {
    final datos = await _api.get('/empresa') as List;
    return datos
        .map((e) => Empresa.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/empresa
  Future<Empresa> crearEmpresa(Map<String, dynamic> cuerpo) async =>
      Empresa.desdeJson(
        await _api.post('/empresa', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/empresa/{id}
  Future<Empresa> actualizarEmpresa(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Empresa.desdeJson(
    await _api.put('/empresa/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PATCH /api/empresa/{id}/activar
  ///
  /// El backend desactiva sola la que estuviera activa: nunca hay dos.
  Future<Empresa> activarEmpresa(int id) async => Empresa.desdeJson(
    await _api.patch('/empresa/$id/activar') as Map<String, dynamic>,
  );

  /// PATCH /api/empresa/{id}/habilitar | /deshabilitar
  Future<Empresa> cambiarHabilitacion(
    int id, {
    required bool habilitada,
  }) async => Empresa.desdeJson(
    await _api.patch(
          '/empresa/$id/${habilitada ? 'habilitar' : 'deshabilitar'}',
        )
        as Map<String, dynamic>,
  );
}
