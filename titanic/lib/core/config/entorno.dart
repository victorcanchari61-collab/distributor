import 'dart:io';

import 'package:flutter/foundation.dart';

/// Configuracion por entorno.
///
/// La URL se puede fijar al compilar sin tocar codigo:
///   flutter run --dart-define=API_URL=http://192.168.1.20:5220/api
class Entorno {
  const Entorno._();

  static const _definida = String.fromEnvironment('API_URL');

  /// Base del API.
  ///
  /// El emulador de Android no ve "localhost" del PC: para el, la maquina
  /// anfitriona es 10.0.2.2. En iOS y escritorio si es localhost.
  static String get apiUrl {
    if (_definida.isNotEmpty) return _definida;

    if (!kIsWeb && Platform.isAndroid) return 'http://83.147.39.5:8080/api';
    return 'http://83.147.39.5:8080/api';
  }

  static const nombreApp = 'Titanic D';
  static const timeout = Duration(seconds: 20);
}
