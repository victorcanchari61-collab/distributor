import '../../../compartido/consulta_tabla.dart';
import '../../../core/red/cliente_api.dart';
import 'auditoria.dart';
import 'config_modelos.dart';
import 'permiso_modelos.dart';

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

  /// PUT /api/rol/{id}/permisos
  ///
  /// Reemplazo completo: cada item es {submodulo, accion} y lo que no va en la
  /// lista se retira.
  Future<Rol> actualizarPermisos(
    int id,
    List<Map<String, dynamic>> permisos,
  ) async => Rol.desdeJson(
    await _api.put('/rol/$id/permisos', cuerpo: {'permisos': permisos})
        as Map<String, dynamic>,
  );

  // --- Permisos ---

  /// GET /api/permiso/catalogo
  ///
  /// Que submodulos hay y que acciones admite cada uno. La matriz de Accesos
  /// saca de aqui sus columnas en vez de traer una lista propia.
  Future<List<SubmoduloCatalogo>> catalogoPermisos() async {
    final datos = await _api.get('/permiso/catalogo') as List;
    return datos
        .map((e) => SubmoduloCatalogo.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/permiso/solicitudes — la bandeja del admin.
  Future<List<SolicitudPermiso>> solicitudes() async {
    final datos = await _api.get('/permiso/solicitudes') as List;
    return datos
        .map((e) => SolicitudPermiso.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/permiso/solicitudes/{id}/aprobar
  ///
  /// El alcance lo elige quien aprueba, no quien pide: casi siempre lo que
  /// hace falta es una vez —anular ESA nota— y concederlo para siempre por
  /// comodidad es como se termina con vendedores que pueden anular cualquier
  /// cosa.
  Future<void> aprobarSolicitud(
    int id, {
    required int alcance,
    DateTime? expiraEn,
    String? respuesta,
  }) => _api.post(
    '/permiso/solicitudes/$id/aprobar',
    cuerpo: {
      'alcance': alcance,
      'expiraEn': expiraEn?.toIso8601String(),
      'respuesta': respuesta,
    },
  );

  /// POST /api/permiso/solicitudes/{id}/rechazar
  Future<void> rechazarSolicitud(int id, {String? respuesta}) => _api.post(
    '/permiso/solicitudes/$id/rechazar',
    cuerpo: {'respuesta': respuesta},
  );

  /// GET /api/permiso/usuario/{id} — lo que tiene una persona y su rol no le da.
  Future<List<UsuarioPermiso>> permisosDe(int usuarioId) async {
    final datos = await _api.get('/permiso/usuario/$usuarioId') as List;
    return datos
        .map((e) => UsuarioPermiso.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /api/permiso/{id}/revocar
  Future<void> revocarPermiso(int id) => _api.patch('/permiso/$id/revocar');

  // --- Consultas a SUNAT ---

  /// GET /api/consulta/ruc/{ruc}
  Future<ConsultaRuc> consultarRuc(String ruc) async => ConsultaRuc.desdeJson(
    await _api.get('/consulta/ruc/$ruc') as Map<String, dynamic>,
  );

  // --- Auditoria ---

  /// GET /api/auditoria. Los ultimos cambios, del mas nuevo al mas viejo.
  Future<List<RegistroAuditoria>> auditoria() async {
    final datos = await _api.get('/auditoria') as List;
    return datos
        .map((e) => RegistroAuditoria.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/auditoria/resumen. Contadores y valores de filtro de toda la
  /// bitácora: de aquí salen las listas de usuarios y entidades.
  Future<ResumenAuditoria> resumenAuditoria() async => ResumenAuditoria.desdeJson(
    await _api.get('/auditoria/resumen') as Map<String, dynamic>,
  );

  /// POST /api/auditoria/listar, pidiendo una sola fila: solo interesa el
  /// `total`, es decir, cuántos registros deja a la vista esa consulta.
  ///
  /// Se cuenta con el mismo listado que después se borra, no con otro camino:
  /// así el número que se le enseña a la persona es lo que de verdad se va.
  Future<int> contarAuditoria(ConsultaTabla consulta) async {
    final pagina =
        await _api.post(
              '/auditoria/listar',
              cuerpo: consulta.conPagina(1, porPagina: 1).aJson(),
            )
            as Map<String, dynamic>;
    return pagina['total'] as int? ?? 0;
  }

  /// POST /api/auditoria/eliminar. Depuración masiva: borra todo lo que esa
  /// consulta deja a la vista, sin importar página ni orden. Devuelve cuántos
  /// registros se eliminaron.
  Future<int> depurarAuditoria(ConsultaTabla consulta) async {
    final respuesta =
        await _api.post('/auditoria/eliminar', cuerpo: consulta.aJson())
            as Map<String, dynamic>;
    return respuesta['eliminados'] as int? ?? 0;
  }

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
