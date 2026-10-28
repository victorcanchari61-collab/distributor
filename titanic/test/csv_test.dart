import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/compartido/csv.dart';

void main() {
  test('lee comas, comillas, saltos dentro de comillas y el BOM', () {
    final t = leerCsv(
      '﻿Documento,Razón social,Dirección\r\n'
      '20123,"PEREZ, JUAN ""EL TIO""","JR. A\nLIMA"\r\n'
      '\r\n'
      '20456,SUR SAC,\r\n',
    );

    expect(t.columnas, ['Documento', 'Razón social', 'Dirección']);
    expect(t.filas, hasLength(2));
    expect(valorDe(t.filas[0], ['razon social']), 'PEREZ, JUAN "EL TIO"');
    expect(valorDe(t.filas[0], ['direccion']), 'JR. A\nLIMA');
    expect(valorDe(t.filas[1], ['direccion']), '');
  });

  test('detecta el punto y coma de Excel en español', () {
    final t = leerCsv('Codigo;Descripcion;Costo\nA1;Aceite;6,50\n');

    expect(t.filas.single['costo'], '6,50');
    expect(numeroPositivo(t.filas.single['costo']!), 6.5);
  });

  test(
    'valorDe prueba los nombres en orden y numeroPositivo descarta ceros',
    () {
      final fila = {'ruc': ' 20123 ', 'dni': ''};

      expect(valorDe(fila, ['dni', 'ruc']), '20123');
      expect(valorDe(fila, ['otro']), '');
      expect(numeroPositivo('0'), isNull);
      expect(numeroPositivo('abc'), isNull);
    },
  );

  test('un archivo vacío no trae filas', () {
    expect(leerCsv('').filas, isEmpty);
    expect(leerCsv('Documento,Nombre\n').filas, isEmpty);
  });
}
