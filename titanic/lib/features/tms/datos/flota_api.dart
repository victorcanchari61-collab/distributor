import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/almacenamiento/sesion_almacen.dart';
import '../../../core/config/entorno.dart';
import '../../../core/red/cliente_api.dart';
import '../../../core/red/excepciones.dart';
import 'flota.dart';

/// Llamadas de Flota y Conductores.
class FlotaApi {
  const FlotaApi(this._api);

  final ClienteApi _api;

  // --- Tipos de vehículo ---

  /// GET /api/tipovehiculo
  Future<List<TipoVehiculo>> tipos() async {
    final datos = await _api.get('/tipovehiculo') as List;
    return datos.map((e) => TipoVehiculo.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/tipovehiculo
  Future<TipoVehiculo> crearTipo(Map<String, dynamic> cuerpo) async => TipoVehiculo.desdeJson(
    await _api.post('/tipovehiculo', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/tipovehiculo/{id}
  Future<TipoVehiculo> actualizarTipo(int id, Map<String, dynamic> cuerpo) async =>
      TipoVehiculo.desdeJson(
        await _api.put('/tipovehiculo/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// DELETE /api/tipovehiculo/{id}
  Future<void> eliminarTipo(int id) => _api.delete('/tipovehiculo/$id');

  // --- Vehículos ---

  /// GET /api/vehiculo
  Future<List<Vehiculo>> vehiculos() async {
    final datos = await _api.get('/vehiculo') as List;
    return datos.map((e) => Vehiculo.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/vehiculo/resumen
  Future<ResumenFlota> resumenFlota() async =>
      ResumenFlota.desdeJson(await _api.get('/vehiculo/resumen') as Map<String, dynamic>);

  /// POST /api/vehiculo
  Future<Vehiculo> crearVehiculo(Map<String, dynamic> cuerpo) async =>
      Vehiculo.desdeJson(await _api.post('/vehiculo', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PUT /api/vehiculo/{id}
  Future<Vehiculo> actualizarVehiculo(int id, Map<String, dynamic> cuerpo) async =>
      Vehiculo.desdeJson(
        await _api.put('/vehiculo/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// DELETE /api/vehiculo/{id}
  Future<void> eliminarVehiculo(int id) => _api.delete('/vehiculo/$id');

  // --- Conductores ---

  /// GET /api/conductor
  Future<List<Conductor>> conductores() async {
    final datos = await _api.get('/conductor') as List;
    return datos.map((e) => Conductor.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/conductor/resumen
  Future<ResumenConductores> resumenConductores() async =>
      ResumenConductores.desdeJson(await _api.get('/conductor/resumen') as Map<String, dynamic>);

  /// POST /api/conductor
  Future<Conductor> crearConductor(Map<String, dynamic> cuerpo) async =>
      Conductor.desdeJson(await _api.post('/conductor', cuerpo: cuerpo) as Map<String, dynamic>);

  /// PUT /api/conductor/{id}
  Future<Conductor> actualizarConductor(int id, Map<String, dynamic> cuerpo) async =>
      Conductor.desdeJson(
        await _api.put('/conductor/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// DELETE /api/conductor/{id}
  Future<void> eliminarConductor(int id) => _api.delete('/conductor/$id');
}

/// Subida de fotos y resolución de sus URLs.
///
/// Va aparte de [FlotaApi] porque no habla JSON: manda el archivo en
/// multipart, y el cliente compartido fija `Content-Type: application/json`,
/// que ahí rompe el separador que el servidor necesita para encontrar el
/// archivo.
class ArchivoApi {
  const ArchivoApi();

  /// POST /api/archivo/imagen — devuelve la ruta relativa donde quedó.
  Future<String> subirImagen(File archivo, {required String carpeta}) async {
    final url = Uri.parse('${Entorno.apiUrl}/archivo/imagen?carpeta=$carpeta');
    final peticion = http.MultipartRequest('POST', url);

    final token = await const SesionAlmacen().token();
    if (token != null) peticion.headers['Authorization'] = 'Bearer $token';

    final extension = archivo.path.split('.').last.toLowerCase();
    peticion.files.add(
      await http.MultipartFile.fromPath(
        'archivo',
        archivo.path,
        contentType: MediaType('image', extension == 'jpg' ? 'jpeg' : extension),
      ),
    );

    final respuesta = await http.Response.fromStream(await peticion.send());
    final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;

    if (respuesta.statusCode >= 400) {
      // El backend explica por que: "mas de 5 MB", "solo JPG, PNG o WEBP".
      throw ApiExcepcion(
        cuerpo['message'] as String? ?? 'No pudimos subir la imagen.',
        codigo: respuesta.statusCode,
      );
    }

    return cuerpo['ruta'] as String;
  }

  /// La URL completa de una foto a partir de la ruta guardada.
  ///
  /// Las imagenes se sirven en la raiz del backend y no bajo /api, asi que hay
  /// que quitarle ese sufijo a la base; concatenar sin mas daria
  /// `/api/uploads/...` y un 404.
  static String url(String ruta) {
    final base = Entorno.apiUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$base$ruta';
  }
}
