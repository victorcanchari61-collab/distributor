import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart' show BuildContext, Icons;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'widgets/app_acciones_flotantes.dart';
import 'widgets/app_aviso.dart';

/// Un valor de una celda de Excel: los números salen como numero (para poder sumarlos o filtrarlos) y el resto como
/// texto.
CellValue _celda(Object? valor) => switch (valor) {
  null => TextCellValue(''),
  int n => IntCellValue(n),
  double n => DoubleCellValue(n),
  _ => TextCellValue(valor.toString()),
};

/// Arma un libro de Excel (.xlsx) con esas filas, lo guarda en la carpeta temporal y lo abre con la aplicación del
/// teléfono. Desde ahí ya se puede guardar o compartir.
///
/// Devuelve el error para mostrarlo, o null si se abrió.
Future<String?> exportarExcel({
  required String nombre,
  required String hoja,
  required List<String> encabezados,
  required List<List<Object?>> filas,
}) async {
  try {
    final libro = Excel.createExcel();
    final porDefecto = libro.getDefaultSheet()!;
    libro.rename(porDefecto, hoja);
    final h = libro[hoja];

    h.appendRow([for (final t in encabezados) TextCellValue(t)]);
    for (final fila in filas) {
      h.appendRow([for (final v in fila) _celda(v)]);
    }

    final bytes = libro.encode();
    if (bytes == null) return 'No pudimos armar el archivo de Excel.';

    final limpio = nombre.replaceAll(RegExp(r'[^A-Za-z0-9.-]'), '-');
    final carpeta = await getTemporaryDirectory();
    final archivo = File('${carpeta.path}/$limpio.xlsx');
    await archivo.writeAsBytes(bytes);

    final resultado = await OpenFilex.open(archivo.path);
    return resultado.type == ResultType.done
        ? null
        : 'No hay una aplicación para abrir el archivo. Quedó en ${archivo.path}';
  } catch (_) {
    return 'No pudimos exportar el archivo.';
  }
}

/// La acción "Exportar a Excel" de un listado: baja a .xlsx las filas que se ven, con los filtros puestos. Es la versión
/// del teléfono del botón de la web.
AccionGlobal accionExportarExcel<T>(
  BuildContext context, {
  required String nombre,
  required String hoja,
  required List<T> Function() filas,
  required List<String> encabezados,
  required List<Object?> Function(T fila) fila,
}) {
  return AccionGlobal(
    etiqueta: 'Exportar Excel',
    icono: Icons.table_chart_outlined,
    color: AccionGlobal.turquesa,
    onTap: () async {
      final aviso = Aviso.de(context);
      final lista = filas();
      if (lista.isEmpty) {
        aviso.error('No hay nada para exportar.');
        return;
      }

      final error = await exportarExcel(
        nombre: nombre,
        hoja: hoja,
        encabezados: encabezados,
        filas: [for (final f in lista) fila(f)],
      );
      if (error != null) aviso.error(error);
    },
  );
}
