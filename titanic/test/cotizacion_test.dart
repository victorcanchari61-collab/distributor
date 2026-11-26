import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/compartido/widgets/app_etiqueta.dart';
import 'package:titanic/features/ventas/datos/cotizacion.dart';

Map<String, dynamic> _json({
  String estado = 'EN_ESPERA',
  String? nota,
  String? pedidoNumero,
}) => {
  'id': 4,
  'numero': 'CT-0004',
  'fecha': '2026-11-26T05:11:00Z',
  'estado': estado,
  'clienteId': 1934,
  'cliente': 'BODEGA PRUEBA PORTAL',
  'clienteDocumento': '70000003',
  'ruta': 'Ruta 5',
  'vendedor': 'WILMER',
  'listaPrecioId': null,
  'nota': nota,
  'total': 326,
  'pedidoNumero': pedidoNumero,
  'detalle': [
    {
      'id': 9,
      'productoId': 6,
      'codigo': '100',
      'producto': 'ACEITE BELTRAN',
      'presentacionId': 6,
      'presentacion': 'Caja',
      'cantidad': 3,
      'precioPresentacion': 86,
      'subtotal': 258,
    },
  ],
};

void main() {
  test('una cotizacion en espera se lee con sus lineas', () {
    final c = Cotizacion.desdeJson(_json(nota: 'Para el jueves'));

    expect(c.enEspera, isTrue);
    expect(c.numero, 'CT-0004');
    expect(c.total, 326);
    expect(c.nota, 'Para el jueves');
    expect(c.detalle.single.presentacionId, 6);
    expect(c.detalle.single.cantidad, 3);
    expect(c.detalle.single.precioPresentacion, 86);
    expect(c.buscable, contains('bodega prueba'));
  });

  test('atendida trae el pedido que salio de ella', () {
    final c = Cotizacion.desdeJson(
      _json(estado: 'ATENDIDA', pedidoNumero: 'PD-0058'),
    );

    expect(c.enEspera, isFalse);
    expect(c.pedidoNumero, 'PD-0058');
    expect(EstadoCotizacion.etiqueta(c.estado), 'Atendida');
    expect(EstadoCotizacion.tono(c.estado), EtiquetaTono.exito);
  });

  test('cada estado tiene su etiqueta', () {
    expect(EstadoCotizacion.etiqueta(EstadoCotizacion.enEspera), 'En espera');
    expect(
      EstadoCotizacion.etiqueta(EstadoCotizacion.descartada),
      'Descartada',
    );
    expect(EstadoCotizacion.etiqueta(EstadoCotizacion.cancelada), 'Cancelada');
    expect(
      EstadoCotizacion.tono(EstadoCotizacion.enEspera),
      EtiquetaTono.aviso,
    );
  });
}
