import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart' show BuildContext, Icons;
import 'package:path_provider/path_provider.dart';

import 'widgets/app_acciones_flotantes.dart';
import 'widgets/app_aviso.dart';

/// Un valor de una celda, listo para un CSV: entre comillas si lleva coma,
/// comillas o salto de línea.
String _celda(Object? valor) {
  final texto = valor?.toString() ?? '';
  if (texto.contains(RegExp(r'[",;\n\r]'))) {
    return '"${texto.replaceAll('"', '""')}"';
  }
  return texto;
}

/// Arma un CSV con esas filas, lo guarda en la carpeta temporal y lo abre con
/// la aplicación del teléfono (Excel, Hojas de cálculo...). Desde ahí ya se
/// puede guardar o compartir.
///
/// Lleva BOM para que Excel lea bien las tildes y la eñe. Devuelve el error
/// para mostrarlo, o null si se abrió.
Future<String?> exportarCsv({
  required String nombre,
  required List<String> encabezados,
  required List<List<Object?>> filas,
}) async {
  try {
    final lineas = [
      encabezados.map(_celda).join(','),
      for (final fila in filas) fila.map(_celda).join(','),
    ];
    final limpio = nombre.replaceAll(RegExp(r'[^A-Za-z0-9.-]'), '-');
    final carpeta = await getTemporaryDirectory();
    final archivo = File('${carpeta.path}/$limpio.csv');
    await archivo.writeAsString('﻿${lineas.join('\r\n')}\r\n');

    final resultado = await OpenFilex.open(archivo.path);
    return resultado.type == ResultType.done
        ? null
        : 'No hay una aplicación para abrir el archivo. Quedó en ${archivo.path}';
  } catch (_) {
    return 'No pudimos exportar el archivo.';
  }
}

/// La acción "Exportar" de un listado: baja a CSV las filas que se ven, con los
/// filtros puestos. Es la versión del teléfono del botón Exportar de la web.
///
/// Las filas se leen al tocar, no al armar la acción: así salen las de ese
/// momento aunque la lista haya cambiado con el abanico cerrado.
AccionGlobal accionExportar<T>(
  BuildContext context, {
  required String nombre,
  required List<T> Function() filas,
  required List<String> encabezados,
  required List<Object?> Function(T fila) fila,
}) {
  return AccionGlobal(
    etiqueta: 'Exportar',
    icono: Icons.description_outlined,
    color: AccionGlobal.turquesa,
    onTap: () async {
      final aviso = Aviso.de(context);
      final lista = filas();
      if (lista.isEmpty) {
        aviso.error('No hay nada para exportar.');
        return;
      }

      final error = await exportarCsv(
        nombre: nombre,
        encabezados: encabezados,
        filas: [for (final f in lista) fila(f)],
      );
      if (error != null) aviso.error(error);
    },
  );
}
