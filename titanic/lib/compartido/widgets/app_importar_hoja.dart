import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/red/excepciones.dart';
import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';
import '../csv.dart';
import '../exportar_csv.dart';
import 'app_acciones_flotantes.dart';
import 'app_alerta.dart';
import 'app_aviso.dart';
import 'app_boton.dart';
import 'app_botones_formulario.dart';
import 'app_hoja.dart';

/// Lo que el backend responde por cada importación.
class ResultadoImportacion {
  const ResultadoImportacion({
    required this.creados,
    required this.actualizados,
    required this.omitidos,
    required this.errores,
  });

  final int creados;
  final int actualizados;
  final int omitidos;

  /// Las filas que no se guardaron: número de fila, documento y motivo.
  final List<({int fila, String documento, String motivo})> errores;

  factory ResultadoImportacion.desdeJson(Map<String, dynamic> json) =>
      ResultadoImportacion(
        creados: (json['creados'] as num?)?.toInt() ?? 0,
        actualizados: (json['actualizados'] as num?)?.toInt() ?? 0,
        omitidos: (json['omitidos'] as num?)?.toInt() ?? 0,
        errores: [
          for (final e in (json['errores'] as List?) ?? const [])
            (
              fila: ((e as Map)['fila'] as num?)?.toInt() ?? 0,
              documento: e['documento']?.toString() ?? '',
              motivo: e['motivo']?.toString() ?? '',
            ),
        ],
      );
}

/// Lo que cambia entre una importación y otra: qué se importa, qué columnas se
/// esperan, cómo se arma el cuerpo de cada fila y a dónde se manda.
class ImportacionConfig {
  const ImportacionConfig({
    required this.titulo,
    required this.columnas,
    required this.ejemplo,
    required this.mapear,
    required this.enviar,
    required this.onListo,
  });

  /// Qué se importa, en plural: "clientes", "proveedores".
  final String titulo;

  /// Los títulos que lleva la plantilla y que se muestran como ayuda.
  final List<String> columnas;

  /// Una fila de ejemplo para la plantilla, una celda por columna.
  final List<String> ejemplo;

  /// Convierte una fila del archivo al cuerpo que espera la API.
  final Map<String, dynamic> Function(FilaCsv fila) mapear;

  final Future<ResultadoImportacion> Function(
    List<Map<String, dynamic>> filas,
    bool actualizarExistentes,
  )
  enviar;

  /// Se llama al cerrar si algo se guardó, para recargar el listado.
  final VoidCallback onListo;
}

/// Las dos acciones de importar de un listado: subir el archivo y bajar la
/// plantilla. Van juntas en el abanico, igual que en la web van juntos el botón
/// Importar y la ayuda de las columnas.
List<AccionGlobal> accionesImportar(
  BuildContext context,
  ImportacionConfig config,
) {
  return [
    AccionGlobal(
      etiqueta: 'Subir ${config.titulo}',
      icono: Icons.file_upload_outlined,
      color: AccionGlobal.naranja,
      onTap: () => mostrarImportar(context, config),
    ),
    AccionGlobal(
      etiqueta: 'Descargar plantilla',
      icono: Icons.file_download_outlined,
      color: AccionGlobal.azul,
      onTap: () async {
        final aviso = Aviso.de(context);
        final error = await exportarCsv(
          nombre: 'plantilla-${config.titulo}',
          encabezados: config.columnas,
          filas: [config.ejemplo],
        );
        if (error != null) aviso.error(error);
      },
    ),
  ];
}

/// La hoja de importar: se elige el archivo, se ve cuántas filas trae, se
/// importa y se muestra lo que pasó con cada una.
Future<void> mostrarImportar(BuildContext context, ImportacionConfig config) =>
    abrirHoja<void>(context, (_) => _HojaImportar(config: config));

class _HojaImportar extends StatefulWidget {
  const _HojaImportar({required this.config});

  final ImportacionConfig config;

  @override
  State<_HojaImportar> createState() => _HojaImportarState();
}

class _HojaImportarState extends State<_HojaImportar> {
  String? _archivo;
  List<FilaCsv> _filas = const [];
  bool _actualizar = false;
  bool _leyendo = false;
  bool _enviando = false;
  String? _error;
  ResultadoImportacion? _resultado;

  ImportacionConfig get _c => widget.config;

  Future<void> _elegir() async {
    setState(() {
      _leyendo = true;
      _error = null;
      _resultado = null;
    });

    try {
      // Cualquier tipo: Android no siempre reconoce el CSV por su extensión.
      final archivo = await FilePicker.pickFile();
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();

      final nombre = archivo.name.toLowerCase();
      if (nombre.endsWith('.xlsx') || nombre.endsWith('.xls')) {
        setState(
          () => _error =
              'Guarda el Excel como CSV (Archivo > Guardar como > CSV) y súbelo de nuevo.',
        );
        return;
      }

      final tabla = leerCsv(utf8.decode(bytes, allowMalformed: true));
      if (tabla.filas.isEmpty) {
        setState(() => _error = 'El archivo no tiene filas con datos.');
        return;
      }

      setState(() {
        _archivo = archivo.name;
        _filas = tabla.filas;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos leer el archivo.');
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
  }

  Future<void> _importar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final resultado = await _c.enviar([
        for (final f in _filas) _c.mapear(f),
      ], _actualizar);
      if (mounted) setState(() => _resultado = resultado);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos importar el archivo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _cerrar() {
    final r = _resultado;
    if (r != null && r.creados + r.actualizados > 0) _c.onListo();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final acento = Acento.de(context);
    final r = _resultado;

    return HojaBase(
      titulo: 'Importar ${_c.titulo}',
      pie: r != null
          ? AppBoton(texto: 'Cerrar', onPressed: _cerrar)
          : AppBotonesFormulario(
              onCancelar: () => Navigator.of(context).pop(),
              onGuardar: _filas.isEmpty ? null : _importar,
              textoGuardar: _filas.isEmpty
                  ? 'Importar'
                  : 'Importar ${_filas.length} filas',
              cargando: _enviando,
            ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Desde un archivo CSV. Cada fila se procesa por separado.',
            style: TextStyle(color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio4),

          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],

          if (r != null) ...[
            AppAlerta(
              '${r.creados} creados'
              '${r.actualizados > 0 ? ', ${r.actualizados} actualizados' : ''}'
              '${r.omitidos > 0 ? ', ${r.omitidos} omitidos' : ''}.',
              tono: AlertaTono.exito,
            ),
            if (r.errores.isNotEmpty) ...[
              const SizedBox(height: Dimen.espacio3),
              Text(
                'No se guardaron ${r.errores.length}:',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Dimen.espacio2),
              for (final e in r.errores.take(30))
                Padding(
                  padding: const EdgeInsets.only(bottom: Dimen.espacio1),
                  child: Text(
                    'Fila ${e.fila}'
                    '${e.documento.isEmpty ? '' : ' (${e.documento})'}: ${e.motivo}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colores.peligro,
                    ),
                  ),
                ),
              if (r.errores.length > 30)
                Text(
                  'y ${r.errores.length - 30} más.',
                  style: const TextStyle(color: Colores.tintaSuave),
                ),
            ],
          ] else ...[
            const Text(
              'Columnas esperadas',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Dimen.espacio2),
            Wrap(
              spacing: Dimen.espacio2,
              runSpacing: Dimen.espacio2,
              children: [
                for (final col in _c.columnas)
                  Chip(
                    label: Text(col, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: acento.withValues(alpha: 0.08),
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),

            OutlinedButton.icon(
              onPressed: _leyendo || _enviando ? null : _elegir,
              icon: _leyendo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
              label: Text(_archivo ?? 'Elegir archivo CSV'),
            ),

            if (_filas.isNotEmpty) ...[
              const SizedBox(height: Dimen.espacio3),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _actualizar,
                onChanged: _enviando
                    ? null
                    : (v) => setState(() => _actualizar = v),
                title: const Text('Actualizar los que ya existen'),
                subtitle: const Text(
                  'Si el documento ya está, se actualiza en vez de omitirse.',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
