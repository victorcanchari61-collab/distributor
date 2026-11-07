import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/features/compras/datos/solicitud_compra.dart';

void main() {
  group('SolicitudCompra', () {
    final json = {
      'id': 7,
      'numero': 'SC-0007',
      'fecha': '2026-11-05T15:00:00Z',
      'almacenId': 1,
      'almacen': 'TIENDA 1',
      'urgencia': 'URGENTE',
      'estado': 'PENDIENTE',
      'observacion': 'se acaba el aceite',
      'solicitante': 'Almacenero',
      'lineas': 2,
      'ordenes': [
        {'id': 3, 'numero': 'OC-0003', 'estado': 'PENDIENTE'},
      ],
      'detalle': [
        {
          'id': 1,
          'productoId': 9,
          'codigo': '7486',
          'producto': 'ACEITE PATRONA',
          'unidadBase': 'UND',
          'presentacionId': 549,
          'presentacion': '5 cajas',
          'cantidadPresentacion': 2,
          'cantidad': 10,
        },
      ],
    };

    test('se lee con sus líneas y sus órdenes', () {
      final s = SolicitudCompra.desdeJson(json);

      expect(s.numero, 'SC-0007');
      expect(s.esUrgente, isTrue);
      expect(s.estaPendiente, isTrue);
      expect(s.ordenes.single.numero, 'OC-0003');
      expect(s.detalle.single.cantidadPresentacion, 2);
      expect(s.detalle.single.cantidad, 10);
    });

    test('un borrador se edita y se envía; una atendida ya no', () {
      final borrador = SolicitudCompra.desdeJson({...json, 'estado': 'BORRADOR'});
      final atendida = SolicitudCompra.desdeJson({...json, 'estado': 'ATENDIDA'});

      expect(borrador.esBorrador, isTrue);
      expect(borrador.estaPendiente, isFalse);
      expect(borrador.seEdita, isTrue);
      expect(atendida.seEdita, isFalse);
    });

    test('el listado no trae líneas y no se rompe', () {
      final sinLineas = Map<String, dynamic>.of(json)..remove('detalle');
      final s = SolicitudCompra.desdeJson(sinLineas);

      expect(s.detalle, isEmpty);
      expect(s.lineas, 2);
    });

    test('se busca por número, almacén, quien pidió y su orden', () {
      final s = SolicitudCompra.desdeJson(json);

      expect(s.buscable, contains('sc-0007'));
      expect(s.buscable, contains('tienda 1'));
      expect(s.buscable, contains('almacenero'));
      expect(s.buscable, contains('oc-0003'));
    });

    test('una sugerencia trae lo que falta para llegar al mínimo', () {
      final s = SugerenciaSolicitud.desdeJson({
        'productoId': 1,
        'codigo': '7678',
        'producto': 'CAMANEJO',
        'unidadBase': 'KG',
        'stock': 2,
        'stockMinimo': 10,
        'cantidadSugerida': 18,
      });

      expect(s.cantidadSugerida, 18);
      expect(s.stock, lessThan(s.stockMinimo));
    });
  });
}
