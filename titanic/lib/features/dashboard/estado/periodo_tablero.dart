/// El período que mira un dashboard: uno de los atajos (7 días, 30 días, este
/// mes, 90 días) o un rango propio.
///
/// Son días de calle, no instantes: la hora del reloj no interviene, así que
/// todo se guarda a las 00:00 y se compara por fecha.
class PeriodoTablero {
  const PeriodoTablero({
    required this.id,
    required this.etiqueta,
    required this.desde,
    required this.hasta,
  });

  /// '7', '30', 'mes', '90' o 'custom'. Es lo que marca el chip activo.
  final String id;
  final String etiqueta;
  final DateTime desde;
  final DateTime hasta;

  /// Un rango elegido a mano en el selector de fechas.
  factory PeriodoTablero.propio(DateTime desde, DateTime hasta) =>
      PeriodoTablero(
        id: 'custom',
        etiqueta: 'Personalizado',
        desde: DateTime(desde.year, desde.month, desde.day),
        hasta: DateTime(hasta.year, hasta.month, hasta.day),
      );

  /// Los cuatro atajos, contados hacia atrás desde hoy (incluido).
  ///
  /// `ahora` existe para las pruebas: con el reloj real un test dependería del
  /// día en que se corre.
  static List<PeriodoTablero> atajos([DateTime? ahora]) {
    final n = ahora ?? DateTime.now();
    final hoy = DateTime(n.year, n.month, n.day);
    DateTime atras(int dias) => DateTime(hoy.year, hoy.month, hoy.day - dias);

    return [
      PeriodoTablero(id: '7', etiqueta: '7 días', desde: atras(6), hasta: hoy),
      PeriodoTablero(id: '30', etiqueta: '30 días', desde: atras(29), hasta: hoy),
      PeriodoTablero(
        id: 'mes',
        etiqueta: 'Este mes',
        desde: DateTime(hoy.year, hoy.month, 1),
        hasta: hoy,
      ),
      PeriodoTablero(id: '90', etiqueta: '90 días', desde: atras(89), hasta: hoy),
    ];
  }

  /// Con el que abre cada tablero: 30 días, igual que en el panel web.
  static PeriodoTablero predeterminado([DateTime? ahora]) => atajos(ahora)[1];

  /// Cuántos días abarca, ambos extremos incluidos.
  ///
  /// Se cuenta en UTC para que un cambio de hora del reloj no reste un día.
  int get dias =>
      DateTime.utc(hasta.year, hasta.month, hasta.day)
          .difference(DateTime.utc(desde.year, desde.month, desde.day))
          .inDays +
      1;

  @override
  bool operator ==(Object other) =>
      other is PeriodoTablero &&
      other.id == id &&
      other.desde == desde &&
      other.hasta == hasta;

  @override
  int get hashCode => Object.hash(id, desde, hasta);
}
