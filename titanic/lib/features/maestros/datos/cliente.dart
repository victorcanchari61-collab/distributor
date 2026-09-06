/// Cliente: bodega o puesto al que se vende.
class Cliente {
  const Cliente({
    required this.id,
    required this.documento,
    required this.tipoDoc,
    required this.nombre,
    required this.activo,
    this.direccion,
    this.distrito,
    this.telefono,
    this.email,
    this.diaVisita,
    this.ruta,
    this.puntoReparto,
  });

  final int id;
  final String documento;

  /// DNI, RUC o CODIGO.
  final String tipoDoc;

  final String nombre;
  final String? direccion;
  final String? distrito;
  final String? telefono;
  final String? email;

  /// Dia en que el vendedor lo visita.
  final String? diaVisita;
  final String? ruta;

  /// Donde se entrega: no siempre es un mercado — puede ser una tienda, una
  /// bodega o una empresa.
  final String? puntoReparto;

  final bool activo;

  /// Texto contra el que se busca en la lista.
  String get buscable =>
      '$documento $nombre ${direccion ?? ''} ${distrito ?? ''} ${puntoReparto ?? ''} ${ruta ?? ''}'
          .toLowerCase();

  factory Cliente.desdeJson(Map<String, dynamic> json) => Cliente(
    id: json['id'] as int,
    documento: json['documento'] as String? ?? '',
    tipoDoc: json['tipoDoc'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    direccion: json['direccion'] as String?,
    distrito: json['distrito'] as String?,
    telefono: json['telefono'] as String?,
    email: json['email'] as String?,
    diaVisita: json['diaVisita'] as String?,
    ruta: json['ruta'] as String?,
    puntoReparto: json['puntoReparto'] as String?,
    activo: json['activo'] as bool? ?? true,
  );

  Map<String, dynamic> aJson() => {
    'documento': documento,
    'tipoDoc': tipoDoc,
    'nombre': nombre,
    'direccion': direccion,
    'distrito': distrito,
    'telefono': telefono,
    'email': email,
    'diaVisita': diaVisita,
    'ruta': ruta,
    'puntoReparto': puntoReparto,
  };

  Cliente copiar({
    String? documento,
    String? tipoDoc,
    String? nombre,
    String? direccion,
    String? distrito,
    String? telefono,
    String? email,
    String? diaVisita,
    String? ruta,
    String? puntoReparto,
    bool? activo,
  }) => Cliente(
    id: id,
    documento: documento ?? this.documento,
    tipoDoc: tipoDoc ?? this.tipoDoc,
    nombre: nombre ?? this.nombre,
    direccion: direccion ?? this.direccion,
    distrito: distrito ?? this.distrito,
    telefono: telefono ?? this.telefono,
    email: email ?? this.email,
    diaVisita: diaVisita ?? this.diaVisita,
    ruta: ruta ?? this.ruta,
    puntoReparto: puntoReparto ?? this.puntoReparto,
    activo: activo ?? this.activo,
  );
}
