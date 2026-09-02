import '../../../core/red/cliente_api.dart';
import 'usuario.dart';

/// Respuesta del login: token y datos del usuario.
class LoginRespuesta {
  const LoginRespuesta({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;
}

/// Llamadas de autenticacion.
class AuthApi {
  const AuthApi(this._api);

  final ClienteApi _api;

  /// POST /api/auth/login
  Future<LoginRespuesta> login({
    required String email,
    required String password,
  }) async {
    final datos =
        await _api.post(
              '/auth/login',
              cuerpo: {'email': email, 'password': password},
              conAuth: false,
            )
            as Map<String, dynamic>;

    return LoginRespuesta(
      token: datos['token'] as String,
      usuario: Usuario.desdeJson(datos['usuario'] as Map<String, dynamic>),
    );
  }
}
