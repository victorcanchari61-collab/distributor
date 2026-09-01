import 'dart:convert';

import 'package:http/http.dart' as http;

import '../almacenamiento/sesion_almacen.dart';
import '../config/entorno.dart';
import 'excepciones.dart';

/// Cliente HTTP del sistema.
///
/// Es el unico punto por donde sale una llamada al backend: aqui se arma la
/// URL, se adjunta el token, se interpreta la respuesta y se convierten los
/// errores en ApiExcepcion. Las pantallas nunca hablan con http directamente.
class ClienteApi {
  ClienteApi({http.Client? cliente, SesionAlmacen? sesion})
    : _http = cliente ?? http.Client(),
      _sesion = sesion ?? SesionAlmacen();

  final http.Client _http;
  final SesionAlmacen _sesion;

  Future<dynamic> get(String ruta, {bool conAuth = true}) =>
      _enviar('GET', ruta, conAuth: conAuth);

  Future<dynamic> post(String ruta, {Object? cuerpo, bool conAuth = true}) =>
      _enviar('POST', ruta, cuerpo: cuerpo, conAuth: conAuth);

  Future<dynamic> put(String ruta, {Object? cuerpo}) =>
      _enviar('PUT', ruta, cuerpo: cuerpo);

  Future<dynamic> patch(String ruta, {Object? cuerpo}) =>
      _enviar('PATCH', ruta, cuerpo: cuerpo);

  Future<dynamic> delete(String ruta) => _enviar('DELETE', ruta);

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    bool conAuth = true,
  }) async {
    final url = Uri.parse('${Entorno.apiUrl}$ruta');

    final cabeceras = <String, String>{'Accept': 'application/json'};
    if (cuerpo != null) cabeceras['Content-Type'] = 'application/json';

    if (conAuth) {
      final token = await _sesion.token();
      if (token != null) cabeceras['Authorization'] = 'Bearer $token';
    }

    http.Response respuesta;
    try {
      final peticion = http.Request(metodo, url)..headers.addAll(cabeceras);
      if (cuerpo != null) peticion.body = jsonEncode(cuerpo);

      final flujo = await _http.send(peticion).timeout(Entorno.timeout);
      respuesta = await http.Response.fromStream(flujo);
    } catch (_) {
      // Sin conexion, servidor caido o timeout: para el usuario es lo mismo,
      // pero se incluye la URL usada porque el fallo mas comun en desarrollo es
      // apuntar a una direccion que el dispositivo no alcanza.
      throw ApiExcepcion(
        'No pudimos conectar con el servidor.\n${Entorno.apiUrl}',
      );
    }

    final texto = respuesta.body;
    final datos = texto.isEmpty ? null : jsonDecode(texto);

    if (respuesta.statusCode >= 400) {
      final mapa = datos is Map<String, dynamic>
          ? datos
          : const <String, dynamic>{};

      throw ApiExcepcion(
        mapa['message'] as String? ?? 'Error ${respuesta.statusCode}',
        codigo: mapa['statusCode'] as int? ?? respuesta.statusCode,
        errores:
            (mapa['errors'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
    }

    return datos;
  }
}
