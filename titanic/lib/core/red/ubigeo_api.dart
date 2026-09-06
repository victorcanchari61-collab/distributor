import 'cliente_api.dart';

/// Ubigeo oficial del Perú (INEI/RENIEC): departamento, provincia y distrito.
/// Dato de referencia precargado — no se crea, edita ni elimina desde acá.
/// Compartido por cualquier feature que necesite un distrito (Cliente hoy).

class Departamento {
  const Departamento({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory Departamento.desdeJson(Map<String, dynamic> json) => Departamento(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
  );
}

class Provincia {
  const Provincia({required this.id, required this.nombre, required this.departamentoId});

  final int id;
  final String nombre;
  final int departamentoId;

  factory Provincia.desdeJson(Map<String, dynamic> json) => Provincia(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    departamentoId: json['departamentoId'] as int,
  );
}

class Distrito {
  const Distrito({
    required this.id,
    required this.nombre,
    required this.provinciaId,
    required this.departamentoId,
  });

  final int id;
  final String nombre;
  final int provinciaId;
  final int departamentoId;

  factory Distrito.desdeJson(Map<String, dynamic> json) => Distrito(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    provinciaId: json['provinciaId'] as int,
    departamentoId: json['departamentoId'] as int,
  );
}

class UbigeoApi {
  const UbigeoApi(this._api);

  final ClienteApi _api;

  /// GET /api/ubigeo/departamentos
  Future<List<Departamento>> departamentos() async {
    final datos = await _api.get('/ubigeo/departamentos') as List;
    return datos.map((e) => Departamento.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/ubigeo/provincias
  Future<List<Provincia>> provincias() async {
    final datos = await _api.get('/ubigeo/provincias') as List;
    return datos.map((e) => Provincia.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/ubigeo/distritos
  Future<List<Distrito>> distritos() async {
    final datos = await _api.get('/ubigeo/distritos') as List;
    return datos.map((e) => Distrito.desdeJson(e as Map<String, dynamic>)).toList();
  }
}
