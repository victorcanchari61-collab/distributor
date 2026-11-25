import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/features/compras/datos/compra.dart';
import 'package:titanic/features/compras/datos/devolucion_proveedor.dart';

void main() {
  group('pago con saldo a favor', () {
    test('llega sin metodo de pago y se lee como saldo a favor', () {
      final pago = PagoCompra.desdeJson({
        'id': 7,
        'metodoPagoId': null,
        'metodoPago': 'Saldo a favor',
        'monto': 150,
        'fecha': '2026-11-24T10:00:00Z',
        'anulado': false,
        'desdeBoveda': false,
        'saldoFavor': true,
      });

      expect(pago.metodoPagoId, isNull);
      expect(pago.saldoFavor, isTrue);
      expect(pago.nombreMetodo, 'Saldo a favor');
      // El selector de metodo no tiene a que volver: queda sin elegir.
      expect(pago.metodoElegido, 0);
    });

    test('un servidor anterior no manda saldoFavor: es un pago normal', () {
      final pago = PagoCompra.desdeJson({
        'id': 8,
        'metodoPagoId': 17,
        'metodoPago': 'Transferencia',
        'monto': 20,
        'fecha': '2026-11-24T10:00:00Z',
      });

      expect(pago.saldoFavor, isFalse);
      expect(pago.metodoElegido, 17);
      expect(pago.nombreMetodo, 'Transferencia');
    });
  });

  test('una devolucion se lee con sus lineas y montos', () {
    final d = DevolucionProveedor.desdeJson({
      'id': 3,
      'numero': 'DVP-0003',
      'compraId': 17,
      'compraNumero': 'CP-0017',
      'proveedorId': 1,
      'proveedor': 'Proveedor XYZ',
      'fecha': '2026-11-24T10:00:00Z',
      'estado': 'CONFIRMADA',
      'motivo': 'No lo trajo',
      'fechaReposicion': null,
      'montoDescuento': 200,
      'saldoFavorGenerado': 200,
      'montoReposicion': 0,
      'detalle': [
        {
          'id': 1,
          'producto': 'CAMANEJO',
          'codigo': '7678',
          'unidadBase': 'KG',
          'cantidad': 50,
          'importe': 200,
          'origen': 'PENDIENTE',
          'resolucion': 'DESCUENTO',
        },
      ],
    });

    expect(d.anulada, isFalse);
    expect(d.saldoFavorGenerado, 200);
    expect(d.fechaReposicion, isNull);
    expect(d.detalle.single.origen, OrigenDevolucion.pendiente);
    expect(
      ResolucionDevolucion.etiqueta(d.detalle.single.resolucion),
      'Descuento',
    );
    expect(d.buscable, contains('cp-0017'));
  });
}
