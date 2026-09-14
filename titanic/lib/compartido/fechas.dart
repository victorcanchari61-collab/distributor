/// Una fecha que viene del servidor, en la hora del reloj de aquí.
///
/// El backend guarda en UTC pero la serializa sin la "Z" que lo dice, así que
/// `DateTime.parse` la toma por hora local y no convierte nada: una venta de
/// las 6:18 de la tarde se mostraba como 11:18 de la noche, y un documento
/// registrado después de las 7 salía con la fecha del día siguiente.
///
/// El sistema guarda dos cosas distintas en el mismo campo:
///
///   - Un INSTANTE —cuándo se registró un pago, cuándo salió el stock— va en
///     UTC y hay que traerlo a la hora de aquí.
///   - Un DÍA —la fecha escrita a mano en el formulario de una compra— va a
///     las 00:00 sin zona y significa ese día; tratarlo como UTC lo correría
///     al anterior.
///
/// Se distinguen por la hora: las 00:00:00 clavadas son un día escrito a mano.
/// Un instante que caiga justo en ese segundo —las 7 p. m. exactas de aquí— se
/// leería como día; es un segundo de cada 86 400 y el precio de no tener que
/// migrar lo ya guardado.
DateTime fechaDeJson(String valor) {
  final tieneZona = RegExp(r'([zZ]|[+-]\d{2}:?\d{2})$').hasMatch(valor);
  final esDiaSuelto =
      !valor.contains('T') || RegExp(r'T00:00:00(\.0+)?$').hasMatch(valor);

  if (tieneZona) return DateTime.parse(valor).toLocal();
  if (esDiaSuelto) return DateTime.parse(valor);

  return DateTime.parse('${valor}Z').toLocal();
}

/// Lo mismo, pero tolerando que el campo no venga.
DateTime? fechaDeJsonOpcional(Object? valor) =>
    valor is String && valor.isNotEmpty ? fechaDeJson(valor) : null;
