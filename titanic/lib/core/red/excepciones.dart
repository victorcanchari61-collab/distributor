/// Error del API con la forma que devuelve ExceptionMiddleware del backend:
/// { statusCode, message, errors }.
class ApiExcepcion implements Exception {
  const ApiExcepcion(
    this.mensaje, {
    this.codigo = 0,
    this.errores = const [],
    this.submodulo,
    this.accion,
  });

  final String mensaje;
  final int codigo;
  final List<String> errores;

  /*
   * Que se pidio, cuando el 403 viene del filtro de permisos.
   *
   * El backend no dice solo que negó: dice la pantalla y la accion exactas.
   * Con eso se le puede ofrecer a la persona pedir ESE permiso, en vez de un
   * "no autorizado" del que nadie puede hacer nada.
   */
  final String? submodulo;
  final String? accion;

  /// Un 403 del filtro de permisos, no cualquier otro rechazo del servidor.
  bool get permisoNegado =>
      codigo == 403 && submodulo != null && accion != null;

  /// Mensaje listo para mostrar: si el backend detallo errores de validacion,
  /// se muestran esos en vez del generico.
  String get texto => errores.isNotEmpty ? errores.join(' ') : mensaje;

  bool get sinConexion => codigo == 0;
  bool get noAutorizado => codigo == 401;

  @override
  String toString() => 'ApiExcepcion($codigo): $texto';
}
