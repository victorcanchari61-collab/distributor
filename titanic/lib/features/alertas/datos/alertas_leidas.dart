import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Qué alertas ya se marcaron como leídas.
///
/// Las alertas del backend no tienen estado propio: cada `GET /alertas` recalcula lo que sigue mal
/// ahora mismo (el mismo stock bajo, el mismo lote por vencer), así que la campana salía siempre
/// igual — no había forma de decir "ya lo vi" y que dejara de insistir mientras el problema no
/// cambiara.
///
/// Cada alerta tiene un id estable por su causa ("stock-45", "lote-812"): marcar una como leída se
/// guarda aquí, por dispositivo, y vuelve a aparecer sola si:
///   - la causa se resuelve y se repite más adelante (nunca deja de avisar del todo), o
///   - pasa más de una semana marcada, para que un problema que sigue sin arreglarse no quede
///     silenciado para siempre por haberlo visto una vez.
class AlertasLeidasAlmacen {
  const AlertasLeidasAlmacen();

  static const _almacen = FlutterSecureStorage();
  static const _clave = 'titanic.alertasLeidas';
  static const _vigencia = Duration(days: 7);

  Future<Map<String, DateTime>> leidas() async {
    final crudo = await _almacen.read(key: _clave);
    if (crudo == null) return {};

    try {
      final guardado = jsonDecode(crudo) as Map<String, dynamic>;
      final ahora = DateTime.now();
      final vigentes = <String, DateTime>{
        for (final entrada in guardado.entries)
          if (ahora.difference(
                DateTime.fromMillisecondsSinceEpoch(entrada.value as int),
              ) <
              _vigencia)
            entrada.key: DateTime.fromMillisecondsSinceEpoch(
              entrada.value as int,
            ),
      };
      // Se reescribe solo si de verdad se limpio algo: evita un write en cada lectura.
      if (vigentes.length != guardado.length) await _escribir(vigentes);
      return vigentes;
    } catch (_) {
      // Dato corrupto: se sigue sin marcar nada como leido, no se rompe la app.
      return {};
    }
  }

  Future<void> marcar(String id) async {
    final actuales = await leidas();
    actuales[id] = DateTime.now();
    await _escribir(actuales);
  }

  Future<void> marcarTodas(List<String> ids) async {
    final actuales = await leidas();
    final ahora = DateTime.now();
    for (final id in ids) {
      actuales[id] = ahora;
    }
    await _escribir(actuales);
  }

  Future<void> _escribir(Map<String, DateTime> mapa) => _almacen.write(
    key: _clave,
    value: jsonEncode(
      mapa.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
    ),
  );
}
