/// Una fila del archivo: el título normalizado de cada columna y su valor.
typedef FilaCsv = Map<String, String>;

/// Quita tildes, pasa a minúsculas y junta los espacios: "Razón  Social" y
/// "razon social" son la misma columna. Es lo que permite aceptar archivos de
/// distintos orígenes sin que cada uno tenga que respetar al milímetro los
/// títulos.
String normalizarTitulo(String texto) {
  const con = 'áàäâéèëêíìïîóòöôúùüûñÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
  const sin = 'aaaaeeeeiiiioooouuuunAAAAEEEEIIIIOOOOUUUUN';
  final b = StringBuffer();
  for (final c in texto.runes) {
    final letra = String.fromCharCode(c);
    final i = con.indexOf(letra);
    b.write(i >= 0 ? sin[i] : letra);
  }
  return b.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// El valor de la primera columna que exista entre esos nombres, ya sin
/// espacios de más. Vacío si ninguna está o no trae nada.
String valorDe(FilaCsv fila, List<String> nombres) {
  for (final nombre in nombres) {
    final valor = fila[normalizarTitulo(nombre)];
    if (valor != null && valor.trim().isNotEmpty) return valor.trim();
  }
  return '';
}

/// El número de ese texto si es mayor que cero; null si no. Precios en 0 o
/// negativos no son reales. Acepta coma decimal.
double? numeroPositivo(String texto) {
  final n = double.tryParse(texto.trim().replaceAll(',', '.'));
  return n != null && n > 0 ? n : null;
}

/// Lo leído de un CSV.
class TablaCsv {
  const TablaCsv(this.columnas, this.filas);

  /// Los títulos tal como vienen en el archivo, para mostrarlos.
  final List<String> columnas;
  final List<FilaCsv> filas;
}

/// Lee un CSV: acepta coma o punto y coma (Excel en español guarda con punto y
/// coma), comillas con comillas dobles escapadas, saltos de línea dentro de una
/// celda entre comillas, y el BOM del inicio. Las filas totalmente vacías se
/// descartan.
TablaCsv leerCsv(String contenido) {
  var texto = contenido;
  if (texto.startsWith('﻿')) texto = texto.substring(1);

  // El separador es el que más aparece en la primera línea, fuera de comillas.
  final primera = texto.split(RegExp(r'\r?\n')).first;
  final separador =
      ';'.allMatches(primera).length > ','.allMatches(primera).length
      ? ';'
      : ',';

  final filas = <List<String>>[];
  var fila = <String>[];
  final celda = StringBuffer();
  var entreComillas = false;

  void cerrarCelda() {
    fila.add(celda.toString());
    celda.clear();
  }

  void cerrarFila() {
    cerrarCelda();
    if (fila.any((c) => c.trim().isNotEmpty)) filas.add(fila);
    fila = <String>[];
  }

  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];

    if (entreComillas) {
      if (c == '"') {
        if (i + 1 < texto.length && texto[i + 1] == '"') {
          celda.write('"');
          i++;
        } else {
          entreComillas = false;
        }
      } else {
        celda.write(c);
      }
      continue;
    }

    if (c == '"') {
      entreComillas = true;
    } else if (c == separador) {
      cerrarCelda();
    } else if (c == '\n') {
      cerrarFila();
    } else if (c == '\r') {
      // El \n que sigue cierra la fila.
    } else {
      celda.write(c);
    }
  }
  if (celda.isNotEmpty || fila.isNotEmpty) cerrarFila();

  if (filas.isEmpty) return const TablaCsv([], []);

  final titulos = filas.first.map((t) => t.trim()).toList();
  final claves = titulos.map(normalizarTitulo).toList();

  final datos = <FilaCsv>[];
  for (final f in filas.skip(1)) {
    final registro = <String, String>{};
    for (var i = 0; i < claves.length; i++) {
      if (claves[i].isEmpty) continue;
      registro[claves[i]] = i < f.length ? f[i].trim() : '';
    }
    datos.add(registro);
  }

  return TablaCsv(titulos, datos);
}
