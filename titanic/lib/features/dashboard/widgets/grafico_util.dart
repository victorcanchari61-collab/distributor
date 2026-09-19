import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/tema/colores.dart';

/// Colores de los gráficos.
///
/// Son los de `Frontend/src/components/charts/util.ts`, no los de `Colores`:
/// el tablero web usa esta paleta y el semáforo propios, y con otros tonos el
/// mismo gráfico se leería distinto según el dispositivo.
class PaletaDash {
  const PaletaDash._();

  /// Los colores de las series, en orden: cada una toma el siguiente.
  static const serie = <Color>[
    Color(0xFF2563EB),
    Color(0xFF0E9F6E),
    Color(0xFFF59E0B),
    Color(0xFFDB2777),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFEA580C),
    Color(0xFF64748B),
  ];

  /// Lo bueno, lo dudoso, lo malo y lo que no dice nada.
  static const bien = Color(0xFF0E9F6E);
  static const alerta = Color(0xFFF59E0B);
  static const mal = Color(0xFFDC2626);
  static const neutro = Color(0xFF94A3B8);

  /// Fondo de las barras vacías, de los esqueletos y de los casilleros sin dato.
  static const fondoSuave = Color(0xFFF1F5F9);

  static const lima = Color(0xFF65A30D);
  static const naranja = Color(0xFFEA580C);

  static Color deSerie(int i) => serie[i % serie.length];
}

/// Color de cada estado de salud del stock. Null si el backend trae uno nuevo:
/// la dona cae entonces a la paleta.
Color? colorSalud(String estado) => switch (estado) {
  'Agotado' => const Color(0xFF991B1B),
  'Crítico' => PaletaDash.mal,
  'Atención' => PaletaDash.alerta,
  'Sano' => PaletaDash.bien,
  'Sobrestock' => const Color(0xFF7C3AED),
  'Sin rotación' => PaletaDash.neutro,
  _ => null,
};

/// De lo reciente a lo vencido: verde a rojo.
const coloresDeuda = <Color>[
  PaletaDash.bien,
  PaletaDash.lima,
  PaletaDash.alerta,
  PaletaDash.naranja,
  PaletaDash.mal,
];

/// Del ya vencido a lo que vence lejos: rojo a verde.
const coloresVence = <Color>[
  PaletaDash.mal,
  PaletaDash.naranja,
  PaletaDash.alerta,
  PaletaDash.lima,
  PaletaDash.bien,
];

/// El color de una lista de colores para el puesto `i`, sin salirse si el
/// backend trae más tramos de los que el tablero conoce.
Color colorDeTramo(List<Color> colores, int i) =>
    colores[math.min(i, colores.length - 1)];

Color semaforoDias(int dias) => dias <= 15
    ? PaletaDash.bien
    : dias <= 30
    ? PaletaDash.alerta
    : PaletaDash.mal;

Color semaforoCobertura(double dias) => dias < 7
    ? PaletaDash.mal
    : dias < 15
    ? PaletaDash.alerta
    : PaletaDash.bien;

/// Texto pequeño de los ejes y de las etiquetas.
const estiloEje = TextStyle(fontSize: 10.5, color: Colores.tintaTenue);

// ------------------------------------------------------------------ Formatos

/// Número con miles separados por coma y decimales con punto: es-PE.
///
/// A mano y no con `intl`: el proyecto no la usa y un solo formato no justifica
/// una dependencia. Siempre `dec` decimales, como `toLocaleString` con mínimo y
/// máximo iguales.
String numeroEs(double n, [int dec = 0]) {
  if (n.isNaN) return '0';
  if (n.isInfinite) return n < 0 ? '-∞' : '∞';

  final texto = n.abs().toStringAsFixed(dec);
  final partes = texto.split('.');
  final entero = partes[0];

  final agrupado = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) agrupado.write(',');
    agrupado.write(entero[i]);
  }

  // Un -0.4 que se redondea a 0 se escribe "0", no "-0".
  final negativo = n < 0 && double.parse(texto) != 0;
  return '${negativo ? '-' : ''}$agrupado${partes.length > 1 ? '.${partes[1]}' : ''}';
}

/// "S/ 1,234".
String moneda(double n, [int dec = 0]) => 'S/ ${numeroEs(n, dec)}';

/// 12 345 → "12.3 mil", 1 250 000 → "1.3 M". Para ejes y etiquetas donde no
/// cabe el número entero.
String compacto(double n) {
  String limpio(double v) {
    final r = double.parse(v.toStringAsFixed(1));
    if (r == 0) return '0';
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
  }

  final a = n.abs();
  if (a >= 1e6) return '${limpio(n / 1e6)} M';
  if (a >= 1e3) return '${limpio(n / 1e3)} mil';
  return numeroEs(n);
}

String porcentaje(double n, [int dec = 1]) => '${numeroEs(n, dec)}%';

/// Variación entre dos valores, en %. Null si no hay base: con el período
/// anterior en cero decir "+∞%" no informa nada.
double? variacion(double actual, double anterior) {
  if (anterior <= 0) return null;
  return (actual - anterior) / anterior * 100;
}

/// "+12% frente a los 30 días anteriores": la conclusión de un gráfico en
/// palabras.
String fraseVariacion(double? cambio, String contra) {
  if (cambio == null) return 'Sin $contra con qué comparar';
  if (cambio.abs() < 0.5) return 'Igual que $contra';
  return '${cambio > 0 ? '+' : '−'}${numeroEs(cambio.abs())}% frente a $contra';
}

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'set', 'oct', 'nov', 'dic', //
];
const _dias = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];

/// "5 set".
String diaCorto(DateTime d) => '${d.day} ${_meses[d.month - 1]}';

/// "lun 5 set".
String diaLargo(DateTime d) =>
    '${_dias[d.weekday % 7]} ${d.day} ${_meses[d.month - 1]}';

double mediana(List<double> valores) {
  if (valores.isEmpty) return 0;
  final orden = [...valores]..sort();
  final m = orden.length ~/ 2;
  return orden.length.isOdd ? orden[m] : (orden[m - 1] + orden[m]) / 2;
}

double maximoDe(Iterable<double> valores, [double piso = 0]) =>
    valores.fold(piso, math.max);

double minimoDe(Iterable<double> valores, [double techo = 0]) =>
    valores.fold(techo, math.min);

// -------------------------------------------------------------------- Escala

typedef Escala = ({double min, double max, List<double> pasos});

/// Una escala "redonda" que contiene [min, max]: los saltos son 1, 2, 2.5, 5 o
/// 10 por una potencia de diez, así el eje dice 0 · 5 mil · 10 mil y no
/// 0 · 4 173 · 8 346.
///
/// El cero siempre entra. Si no hay rango (todo en cero) devuelve 0–1 para que
/// nada divida entre cero.
Escala escala(double min, double max, [int marcas = 4]) {
  final bajo = math.min(0.0, min.isFinite ? min : 0.0);
  final alto = math.max(0.0, max.isFinite ? max : 0.0);
  if (alto == bajo) return (min: 0, max: 1, pasos: [0, 1]);

  final bruto = (alto - bajo) / marcas;
  final mag = math.pow(10, (math.log(bruto) / math.ln10).floor()).toDouble();
  final norm = bruto / mag;
  final paso =
      (norm <= 1
          ? 1
          : norm <= 2
          ? 2
          : norm <= 2.5
          ? 2.5
          : norm <= 5
          ? 5
          : 10) *
      mag;

  final inicio = (bajo / paso).floor() * paso;
  final fin = (alto / paso).ceil() * paso;
  final pasos = <double>[];
  for (var v = inicio; v <= fin + paso / 2; v += paso) {
    pasos.add(double.parse(v.toStringAsFixed(10)));
  }

  return (min: inicio, max: fin, pasos: pasos);
}

/// El salto entre una marca del eje y la siguiente.
double pasoDe(Escala e) => e.pasos.length > 1 ? e.pasos[1] - e.pasos[0] : 1;
