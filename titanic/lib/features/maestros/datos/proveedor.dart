/// Proveedor: a quien se le compra.
class Proveedor {
  const Proveedor({
    required this.id,
    required this.documento,
    required this.tipoDoc,
    required this.nombre,
    required this.activo,
    this.nombreComercial,
    this.direccion,
    this.departamento,
    this.distrito,
    this.telefono,
    this.telefono2,
    this.email,
    this.rubro,
  });

  final int id;
  final String documento;
  final String tipoDoc;

  /// Razon social.
  final String nombre;
  final String? nombreComercial;

  final String? direccion;
  final String? departamento;
  final String? distrito;
  final String? telefono;
  final String? telefono2;
  final String? email;

  /// Que vende: "FIDEOS Y HARINAS".
  final String? rubro;

  final bool activo;

  String get buscable =>
      '$documento $nombre ${nombreComercial ?? ''} ${rubro ?? ''} ${distrito ?? ''}'
          .toLowerCase();

  factory Proveedor.desdeJson(Map<String, dynamic> json) => Proveedor(
    id: json['id'] as int,
    documento: json['documento'] as String? ?? '',
    tipoDoc: json['tipoDoc'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    nombreComercial: json['nombreComercial'] as String?,
    direccion: json['direccion'] as String?,
    departamento: json['departamento'] as String?,
    distrito: json['distrito'] as String?,
    telefono: json['telefono'] as String?,
    telefono2: json['telefono2'] as String?,
    email: json['email'] as String?,
    rubro: json['rubro'] as String?,
    activo: json['activo'] as bool? ?? true,
  );

  Map<String, dynamic> aJson() => {
    'documento': documento,
    'tipoDoc': tipoDoc,
    'nombre': nombre,
    'nombreComercial': nombreComercial,
    'direccion': direccion,
    'departamento': departamento,
    'distrito': distrito,
    'telefono': telefono,
    'telefono2': telefono2,
    'email': email,
    'rubro': rubro,
  };
}
