import 'package:flutter/material.dart';

import 'colores.dart';
import 'dimensiones.dart';

/// Tema de la aplicacion.
///
/// Es el unico lugar donde se define como se ven los controles del sistema:
/// campos, botones, tarjetas y tipografia. Las pantallas no repiten estilos,
/// los toman de aqui.
class Tema {
  const Tema._();

  static ThemeData claro() {
    final base = ThemeData.light(useMaterial3: true);

    final esquema = ColorScheme.fromSeed(
      seedColor: Colores.marca,
      primary: Colores.marca,
      onPrimary: Colores.sobreMarca,
      surface: Colores.superficie,
      error: Colores.peligro,
    );

    return base.copyWith(
      colorScheme: esquema,
      scaffoldBackgroundColor: Colores.fondo,
      textTheme: _texto(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colores.superficie,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colores.tinta,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: _campos(),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colores.marca,
          foregroundColor: Colores.sobreMarca,
          disabledBackgroundColor: Colores.marca.withValues(alpha: 0.5),
          disabledForegroundColor: Colores.sobreMarca.withValues(alpha: 0.8),
          minimumSize: const Size.fromHeight(Dimen.campoLg),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colores.tinta,
          side: const BorderSide(color: Colores.linea),
          minimumSize: const Size.fromHeight(Dimen.campoMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colores.marca,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colores.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioPanel),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Colores.linea, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colores.tinta,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
      ),
    );
  }

  static TextTheme _texto(TextTheme base) => base
      .apply(bodyColor: Colores.tinta, displayColor: Colores.tinta)
      .copyWith(
        headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyMedium: const TextStyle(fontSize: 14, color: Colores.tinta),
        bodySmall: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
        labelLarge: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  /// El foco solo oscurece el borde, sin anillo de color: mismo criterio que el
  /// panel web, donde el anillo llamaba mas la atencion que el propio dato.
  static InputDecorationTheme _campos() {
    OutlineInputBorder borde(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
          borderSide: BorderSide(color: color),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: Colores.superficie,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimen.espacio3,
        vertical: Dimen.espacio3,
      ),
      enabledBorder: borde(Colores.linea),
      focusedBorder: borde(Colores.tintaTenue),
      errorBorder: borde(Colores.peligro),
      focusedErrorBorder: borde(Colores.peligro),
      hintStyle: const TextStyle(color: Colores.tintaTenue, fontSize: 14),
      errorStyle: const TextStyle(color: Colores.peligro, fontSize: 12),
    );
  }
}
