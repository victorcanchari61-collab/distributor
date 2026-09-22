import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda la sesion en el almacen seguro del dispositivo.
///
/// En movil el token vive en el Keystore de Android o el Keychain de iOS, no en
/// texto plano: el telefono de un repartidor se pierde o se lo prestan, y con
/// el token a la vista cualquiera entraria al sistema.
class SesionAlmacen {
  const SesionAlmacen();

  static const _almacen = FlutterSecureStorage();

  static const _claveToken = 'titanic.token';
  static const _claveUsuario = 'titanic.usuario';

  /// Si esta sesión debe seguir ahí la próxima vez que se abra la app.
  ///
  /// El token SIEMPRE se guarda —si no, ninguna llamada de esta misma
  /// sesión tendría con qué autenticarse—; esto solo decide si
  /// [AuthControlador.restaurar] la respeta al reabrir la app o la borra,
  /// igual que "Mantener sesión iniciada" decide entre localStorage y
  /// sessionStorage en la web.
  static const _claveRecordar = 'titanic.recordar';

  Future<void> guardar({
    required String token,
    required Map<String, dynamic> usuario,
    bool recordar = true,
  }) async {
    await _almacen.write(key: _claveToken, value: token);
    await _almacen.write(key: _claveUsuario, value: jsonEncode(usuario));
    await _almacen.write(key: _claveRecordar, value: recordar.toString());
  }

  Future<String?> token() => _almacen.read(key: _claveToken);

  Future<Map<String, dynamic>?> usuario() async {
    final texto = await _almacen.read(key: _claveUsuario);
    if (texto == null) return null;

    try {
      return jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      // Dato corrupto: se descarta y se pide login otra vez.
      return null;
    }
  }

  /// true si no hay nada guardado todavía: una sesión recién creada, antes
  /// de que [guardar] escriba el valor real, se trata como "sí recordar" —
  /// es el comportamiento de siempre.
  Future<bool> recordar() async =>
      (await _almacen.read(key: _claveRecordar)) != 'false';

  Future<void> limpiar() async {
    await _almacen.delete(key: _claveToken);
    await _almacen.delete(key: _claveUsuario);
    await _almacen.delete(key: _claveRecordar);
  }
}
