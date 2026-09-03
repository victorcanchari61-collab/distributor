// Script de un solo uso: rasteriza AppLogo a un PNG para generar el icono de
// la app. Se corre con `flutter test test/_exportar_icono.dart` y se borra
// despues — no es una prueba real, es una herramienta de generacion.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titanic/compartido/widgets/app_logo.dart';
import 'package:titanic/core/tema/colores.dart';

void main() {
  testWidgets('exportar icono', (tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colores.navy,
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: const SizedBox(
                width: 1024,
                height: 1024,
                child: Center(child: AppLogo(tam: 900)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final imagen = await boundary.toImage(pixelRatio: 1.0);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);

    File(
      'assets/icon/app_icon.png',
    ).writeAsBytesSync(datos!.buffer.asUint8List());
  });
}
