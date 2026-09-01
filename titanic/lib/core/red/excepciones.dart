/// Error del API con la forma que devuelve ExceptionMiddleware del backend:
/// { statusCode, message, errors }.
class ApiExcepcion implements Exception {
  const ApiExcepcion(this.mensaje, {this.codigo = 0, this.errores = const []});

  final String mensaje;
  final int codigo;
  final List<String> errores;

  /// Mensaje listo para mostrar: si el backend detallo errores de validacion,
  /// se muestran esos en vez del generico.
  String get texto => errores.isNotEmpty ? errores.join(' ') : mensaje;

  bool get sinConexion => codigo == 0;
  bool get noAutorizado => codigo == 401;

  @override
  String toString() => 'ApiExcepcion($codigo): $texto';
}
