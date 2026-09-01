import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/almacenamiento/sesion_almacen.dart';
import '../../../core/red/cliente_api.dart';
import '../../../core/red/excepciones.dart';
import '../datos/auth_api.dart';
import '../datos/usuario.dart';

/// Piezas compartidas. Se declaran como proveedores para poder reemplazarlas en
/// pruebas sin tocar las pantallas.
final sesionAlmacenProvider = Provider((_) => const SesionAlmacen());

final clienteApiProvider = Provider(
  (ref) => ClienteApi(sesion: ref.watch(sesionAlmacenProvider)),
);

final authApiProvider = Provider(
  (ref) => AuthApi(ref.watch(clienteApiProvider)),
);

/// En que punto esta la sesion.
enum EstadoSesion {
  /// Revisando si hay una sesion guardada en el dispositivo.
  cargando,
  autenticado,
  invitado,
}

class AuthEstado {
  const AuthEstado({
    this.estado = EstadoSesion.cargando,
    this.usuario,
    this.error,
    this.enviando = false,
  });

  final EstadoSesion estado;
  final Usuario? usuario;

  /// Mensaje del ultimo intento fallido, listo para mostrar.
  final String? error;

  /// Hay un login en curso: sirve para el spinner del boton.
  final bool enviando;

  AuthEstado copiar({
    EstadoSesion? estado,
    Usuario? usuario,
    String? error,
    bool? enviando,
    bool limpiarError = false,
    bool limpiarUsuario = false,
  }) => AuthEstado(
    estado: estado ?? this.estado,
    usuario: limpiarUsuario ? null : (usuario ?? this.usuario),
    error: limpiarError ? null : (error ?? this.error),
    enviando: enviando ?? this.enviando,
  );
}

/// Maneja el ciclo de la sesion: restaurar, entrar y salir.
class AuthControlador extends Notifier<AuthEstado> {
  @override
  AuthEstado build() {
    // Se lanza sin await: la UI muestra la pantalla de carga mientras tanto.
    Future.microtask(restaurar);
    return const AuthEstado();
  }

  SesionAlmacen get _sesion => ref.read(sesionAlmacenProvider);
  AuthApi get _api => ref.read(authApiProvider);

  /// Recupera la sesion guardada al abrir la app.
  ///
  /// Pase lo que pase, esto TIENE que terminar en autenticado o invitado: si
  /// queda en cargando, la app se queda con el spinner girando para siempre.
  /// Por eso el try/catch y el limite de tiempo: leer el almacen seguro puede
  /// fallar en un dispositivo concreto y no hay razon para bloquear al usuario,
  /// basta con pedirle que entre otra vez.
  Future<void> restaurar() async {
    try {
      final token = await _sesion.token().timeout(const Duration(seconds: 5));
      final datos = await _sesion.usuario().timeout(const Duration(seconds: 5));

      if (token == null || datos == null) {
        state = state.copiar(
          estado: EstadoSesion.invitado,
          limpiarUsuario: true,
        );
        return;
      }

      state = state.copiar(
        estado: EstadoSesion.autenticado,
        usuario: Usuario.desdeJson(datos),
      );
    } catch (e, pila) {
      debugPrint('No se pudo restaurar la sesion: $e\n$pila');
      state = state.copiar(estado: EstadoSesion.invitado, limpiarUsuario: true);
    }
  }

  Future<bool> entrar({required String email, required String password}) async {
    state = state.copiar(enviando: true, limpiarError: true);

    try {
      final respuesta = await _api.login(
        email: email.trim(),
        password: password,
      );
      await _sesion.guardar(
        token: respuesta.token,
        usuario: respuesta.usuario.aJson(),
      );

      state = AuthEstado(
        estado: EstadoSesion.autenticado,
        usuario: respuesta.usuario,
      );
      return true;
    } on ApiExcepcion catch (e) {
      state = state.copiar(enviando: false, error: e.texto);
      return false;
    } catch (_) {
      state = state.copiar(
        enviando: false,
        error: 'No pudimos validar tus credenciales. Inténtalo nuevamente.',
      );
      return false;
    }
  }

  Future<void> salir() async {
    try {
      await _sesion.limpiar();
    } catch (e) {
      debugPrint('No se pudo limpiar la sesion: $e');
    }
    // La sesion se cierra igual: el usuario pidio salir.
    state = const AuthEstado(estado: EstadoSesion.invitado);
  }

  void limpiarError() => state = state.copiar(limpiarError: true);
}

final authProvider = NotifierProvider<AuthControlador, AuthEstado>(
  AuthControlador.new,
);
