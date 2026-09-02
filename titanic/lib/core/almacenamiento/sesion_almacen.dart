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

  Future<void> guardar({
    required String token,
    required Map<String, dynamic> usuario,
  }) async {
    await _almacen.write(key: _claveToken, value: token);
    await _almacen.write(key: _claveUsuario, value: jsonEncode(usuario));
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

  Future<void> limpiar() async {
    await _almacen.delete(key: _claveToken);
    await _almacen.delete(key: _claveUsuario);
  }
}
