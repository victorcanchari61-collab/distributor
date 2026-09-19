/// Un filtro puesto sobre una columna, como lo espera el servidor.
///
/// Calca `FiltroTablaRequest` del backend: el mismo objeto que arma la tabla
/// del panel web, para que un listado filtrado aquí y allá pida lo mismo.
class FiltroTabla {
  const FiltroTabla({
    required this.columna,
    required this.valor,
    this.operador = 'equals',
    this.valorHasta,
  });

  /// Un rango de días, de `desde` a `hasta` inclusive.
  ///
  /// Viaja como yyyy-MM-dd y sin hora: el servidor lo cuenta como día de calle
  /// (hora local), no como un instante UTC.
  factory FiltroTabla.dias(String columna, DateTime desde, DateTime hasta) =>
      FiltroTabla(
        columna: columna,
        operador: 'between',
        valor: _dia(desde),
        valorHasta: _dia(hasta),
      );

  final String columna;

  /// contains, equals o between.
  final String operador;
  final String valor;

  /// Solo en `between`: el extremo de arriba del rango.
  final String? valorHasta;

  Map<String, dynamic> aJson() => {
    'columna': columna,
    'operador': operador,
    'valor': valor,
    'valorHasta': valorHasta,
  };

  static String _dia(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';
}

/// Lo que un listado le pide al servidor: qué página, qué texto busca, cómo
/// ordena y qué filtros tiene puestos.
///
/// Calca `ConsultaTablaRequest`. Es UN solo objeto para el listado y para lo
/// que actúa sobre lo listado (contar, depurar): así lo que se cuenta o se
/// borra es exactamente lo que la consulta deja a la vista.
class ConsultaTabla {
  const ConsultaTabla({
    this.pagina = 1,
    this.porPagina = 30,
    this.buscar = '',
    this.orden,
    this.sentido,
    this.filtros = const [],
  });

  /// Empieza en 1.
  final int pagina;

  /// El servidor corta en 200: pedir más no trae más.
  final int porPagina;

  final String buscar;

  /// Columna por la que se ordena. Null es el orden natural del listado.
  final String? orden;

  /// asc o desc.
  final String? sentido;

  final List<FiltroTabla> filtros;

  /// La misma consulta pero pidiendo otra página.
  ConsultaTabla conPagina(int pagina, {int? porPagina}) => ConsultaTabla(
    pagina: pagina,
    porPagina: porPagina ?? this.porPagina,
    buscar: buscar,
    orden: orden,
    sentido: sentido,
    filtros: filtros,
  );

  Map<String, dynamic> aJson() => {
    'pagina': pagina,
    'porPagina': porPagina,
    'buscar': buscar,
    'orden': orden,
    'sentido': sentido,
    'filtros': [for (final f in filtros) f.aJson()],
  };
}
