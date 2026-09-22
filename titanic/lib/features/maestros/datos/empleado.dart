import '../../../compartido/fechas.dart';

/// Empleado: quien trabaja en el negocio.
///
/// Es un MAESTRO y no una cuenta de acceso: existe aunque la persona nunca
/// entre al sistema —el estibador no necesita usuario— y se conserva cuando
/// deja de trabajar, porque los documentos que registro siguen apuntando a el.
///
/// Quien ademas usa el sistema tiene un usuario enlazado a su ficha, pero el
/// enlace es opcional en los dos sentidos: hay empleados sin usuario, y
/// usuarios sin empleado (la cuenta de soporte, la del dueño).
class Empleado {
  const Empleado({
    required this.id,
    required this.documento,
    required this.tipoDoc,
    required this.nombres,
    required this.apellidos,
    required this.activo,
    this.telefono,
    this.email,
    this.direccion,
    this.cargo,
    this.area,
    this.fechaIngreso,
    this.fechaCese,
    this.observacion,
    this.usuarioId,
    this.usuario,
  });

  final int id;

  /// DNI casi siempre; un codigo interno si es extranjero sin DNI. No se repite.
  final String documento;

  /// DNI o CODIGO. Nunca RUC: un empleado es una persona, no una empresa.
  final String tipoDoc;

  final String nombres;
  final String apellidos;

  final String? telefono;
  final String? email;
  final String? direccion;

  /// Que hace: "Repartidor", "Vendedor". Texto libre: cada negocio los llama
  /// a su manera.
  final String? cargo;

  /// Donde: "Reparto", "Almacen", "Ventas".
  final String? area;

  final DateTime? fechaIngreso;

  /// Cuando dejo de trabajar. Con fecha de cese la ficha queda como historico.
  final DateTime? fechaCese;

  final String? observacion;

  final bool activo;

  /// El usuario enlazado a esta ficha, si entra al sistema.
  final int? usuarioId;

  /// Nombre de ese usuario, solo para mostrar: no se envia al guardar.
  final String? usuario;

  /// "Juan Carlos Quispe Mamani", que es como se lo nombra en una lista.
  ///
  /// El backend tambien lo manda armado, pero aqui se recalcula: son las dos
  /// partes que ya estan en la ficha, y guardar una tercera copia significaria
  /// que un nombre recien editado se lea viejo hasta la siguiente recarga.
  String get nombreCompleto => '$nombres $apellidos'.trim();

  String get buscable =>
      '$documento $nombreCompleto ${cargo ?? ''} ${area ?? ''} ${telefono ?? ''}'
          .toLowerCase();

  factory Empleado.desdeJson(Map<String, dynamic> json) => Empleado(
    id: json['id'] as int,
    documento: json['documento'] as String? ?? '',
    tipoDoc: json['tipoDoc'] as String? ?? '',
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    telefono: json['telefono'] as String?,
    email: json['email'] as String?,
    direccion: json['direccion'] as String?,
    cargo: json['cargo'] as String?,
    area: json['area'] as String?,
    fechaIngreso: fechaDeJsonOpcional(json['fechaIngreso']),
    fechaCese: fechaDeJsonOpcional(json['fechaCese']),
    observacion: json['observacion'] as String?,
    activo: json['activo'] as bool? ?? true,
    usuarioId: json['usuarioId'] as int?,
    usuario: json['usuario'] as String?,
  );

  /// Lo que acepta el backend al crear o editar.
  ///
  /// Las fechas viajan en ISO y las vacias como null: el servidor no entiende
  /// una cadena vacia como "sin fecha" y la rechaza.
  Map<String, dynamic> aJson() => {
    'documento': documento,
    'tipoDoc': tipoDoc,
    'nombres': nombres,
    'apellidos': apellidos,
    'telefono': telefono,
    'email': email,
    'direccion': direccion,
    'cargo': cargo,
    'area': area,
    'fechaIngreso': fechaIngreso?.toIso8601String(),
    'fechaCese': fechaCese?.toIso8601String(),
    'observacion': observacion,
  };
}

/// Lo justo para elegir un empleado en un selector, sin arrastrar toda la ficha.
class EmpleadoOpcion {
  const EmpleadoOpcion({
    required this.id,
    required this.documento,
    this.tipoDoc = '',
    required this.nombreCompleto,
    this.cargo,
    this.email,
    this.usuarioId,
  });

  final int id;
  final String documento;

  /// DNI o CODIGO. Solo el DNI sirve para llenar el DNI de la cuenta: el
  /// codigo interno de un extranjero no es un documento de identidad.
  final String tipoDoc;

  final String nombreCompleto;
  final String? cargo;

  /// El correo de su ficha, para proponerlo como el de la cuenta. Puede no
  /// tenerlo.
  final String? email;

  /// Id del usuario que YA lo usa. El selector lo muestra ocupado en vez de
  /// esconderlo: esconderlo dejaria pensando por que no aparece.
  final int? usuarioId;

  /// "Juan Quispe — Repartidor", como se lee en el desplegable.
  String get etiqueta => cargo == null || cargo!.trim().isEmpty
      ? nombreCompleto
      : '$nombreCompleto — $cargo';

  factory EmpleadoOpcion.desdeJson(Map<String, dynamic> json) => EmpleadoOpcion(
    id: json['id'] as int,
    documento: json['documento'] as String? ?? '',
    tipoDoc: json['tipoDoc'] as String? ?? '',
    nombreCompleto: json['nombreCompleto'] as String? ?? '',
    cargo: json['cargo'] as String?,
    email: json['email'] as String?,
    usuarioId: json['usuarioId'] as int?,
  );
}
