import 'package:flutter/material.dart';

/// Colores del sistema.
///
/// Son los mismos tokens del panel web (Frontend/src/styles/theme.css) para que
/// la app y el escritorio se vean como un solo producto. Si un color cambia
/// alla, se cambia aqui.
class Colores {
  const Colores._();

  // --- Identidad Titanic D ---
  static const navy = Color(0xFF14497F);
  static const navyProfundo = Color(0xFF0E3560);
  static const dorado = Color(0xFFF7CB84);
  static const bronce = Color(0xFFB5700B);

  // --- Marca (el azul del boton de login) ---
  static const marca = Color(0xFF2563EB);
  static const marcaHover = Color(0xFF1D4ED8);
  static const marcaSuave = Color(0x142563EB);
  static const sobreMarca = Colors.white;

  // --- Superficies y texto ---
  static const fondo = Color(0xFFF8FAFC);
  static const superficie = Colors.white;
  static const tinta = Color(0xFF0F172A);
  static const tintaSuave = Color(0xFF64748B);
  static const tintaTenue = Color(0xFF94A3B8);
  static const linea = Color(0xFFE2E8F0);
  static const lineaFuerte = Color(0xFFCBD5E1);

  // --- Estados ---
  static const exito = Color(0xFF16A34A);
  static const exitoSuave = Color(0xFFECFDF5);
  static const advertencia = Color(0xFFD97706);
  static const peligro = Color(0xFFDC2626);
  static const peligroSuave = Color(0xFFFEF2F2);

  /// Acento de cada modulo, igual que `data-sys` en el web.
  static const modulos = <String, Color>{
    'maestros': navy,
    'compras': Color(0xFF7C3AED),
    'inv': Color(0xFF0E9F6E),
    'fact': marca,
    'finanzas': Color(0xFF0D9488),
    'tms': Color(0xFF0891B2),
    'dms': Color(0xFFDB2777),
    'rrhh': Color(0xFFD97706),
    'config': Color(0xFF475569),
  };
}
