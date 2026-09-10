import '../../../core/red/cliente_api.dart';
import '../../auth/datos/usuario.dart';

/// Llamadas del perfil propio.
///
/// Va contra /api/perfil y no contra /api/usuario: alli todo exige el permiso
/// "config.usuarios", que un vendedor o un almacenero no tiene. Aqui cada uno
/// edita lo suyo sin poder tocarse el rol ni el estado.
class PerfilApi {
  const PerfilApi(this._api);

  final ClienteApi _api;

  /// GET /api/perfil
  Future<Usuario> perfil() async =>
      Usuario.desdeJson(await _api.get('/perfil') as Map<String, dynamic>);

  /// PUT /api/perfil
  Future<Usuario> actualizar(Map<String, dynamic> cuerpo) async => Usuario.desdeJson(
    await _api.put('/perfil', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/perfil/password
  Future<void> cambiarPassword({
    required String actual,
    required String nueva,
  }) => _api.put(
    '/perfil/password',
    cuerpo: {'passwordActual': actual, 'passwordNueva': nueva},
  );
}
