import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/features/crm/datos/crm.dart';

/// "Evolución de ventas" de Clientes con caída: lo vendido mes a mes, este año
/// contra el anterior.
void main() {
  Map<String, dynamic> respuesta({Object? evolucion}) => {
    'periodo': {
      'actual': {'desde': '2026-11-01T00:00:00', 'hasta': '2026-11-15T00:00:00'},
      'anterior': {'desde': '2026-10-01T00:00:00', 'hasta': '2026-10-15T00:00:00'},
      'etiqueta': '01/11/2026 al 15/11/2026',
      'etiquetaAnterior': '01/10/2026 al 15/10/2026',
    },
    'estados': const [],
    'ventaAnterior': 0,
    'ventaActual': 0,
    'soloPropios': false,
    'items': const [],
    'evolucion': ?evolucion,
  };

  test('lee los doce meses de los dos años y sus totales', () {
    final datos = CaidaClientes.desdeJson(
      respuesta(
        evolucion: {
          'anio': 2026,
          'actual': [0, 0, 0, 0, 0, 0, 0, 0, 1325.91, 1253.55, 338.5, null],
          'anterior': [10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5.5],
        },
      ),
    );

    final e = datos.evolucion!;
    expect(e.anio, 2026);
    expect(e.actual, hasLength(12));
    // Diciembre todavía no llega: sin punto, no cero.
    expect(e.actual.last, isNull);
    expect(e.totalActual, closeTo(2917.96, 0.001));
    expect(e.totalAnterior, 15.5);
  });

  test('con un backend que todavía no la manda, no falla', () {
    final datos = CaidaClientes.desdeJson(respuesta());
    expect(datos.evolucion, isNull);
  });
}
