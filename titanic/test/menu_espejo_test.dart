import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/navegacion/menu.dart';

/// Lee el menu del panel web para compararlo con el de la app.
///
/// Los dos menus tienen que decir lo mismo: si alguien agrega un modulo en el
/// web y no aqui, quien usa las dos cosas encuentra opciones distintas segun el
/// dispositivo. Este test lo delata en vez de que se descubra en produccion.
({List<String> grupos, List<String> vistas}) _menuDelWeb() {
  final archivo = File('../Frontend/src/components/layout/navigation.ts');
  if (!archivo.existsSync()) return (grupos: [], vistas: []);

  final texto = archivo.readAsStringSync();

  final grupos = <String>[];
  for (final linea in texto.split('\n')) {
    final grupo = RegExp(r"^\s{4}id: '([a-z]+)',").firstMatch(linea);
    if (grupo != null) grupos.add(grupo.group(1)!);
  }

  // Se lee el objeto entero de cada vista, no linea por linea: `hidden: true`
  // puede quedar varias lineas debajo del id cuando el objeto viene formateado
  // en varias lineas, y entonces la vista oculta se colaba en la comparacion.
  final vistas = <String>[];
  final objeto = RegExp(
    r"\{[^{}]*?id: '([a-z]+\.[a-z]+)'[^{}]*?\}",
    dotAll: true,
  );

  for (final coincidencia in objeto.allMatches(texto)) {
    if (coincidencia.group(0)!.contains('hidden: true')) continue;
    vistas.add(coincidencia.group(1)!);
  }

  return (grupos: grupos, vistas: vistas);
}

void main() {
  final web = _menuDelWeb();

  test(
    'el menu de la app tiene los mismos modulos que el web, en el mismo orden',
    () {
      if (web.grupos.isEmpty) {
        markTestSkipped('no se encontró navigation.ts del panel web');
        return;
      }

      expect(menuGrupos.map((g) => g.id).toList(), web.grupos);
    },
  );

  test('el menu de la app tiene las mismas vistas que el web', () {
    if (web.vistas.isEmpty) {
      markTestSkipped('no se encontró navigation.ts del panel web');
      return;
    }

    final enApp = [for (final g in menuGrupos) ...g.items.map((i) => i.id)];
    expect(enApp, web.vistas);
  });
}
