import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/flota_api.dart';

/// La foto de un vehículo o de un conductor.
///
/// Ofrece cámara y galería: la del camión se toma en el patio, con el vehículo
/// delante, y la del carnet suele estar ya en el teléfono.
///
/// Sube al elegir y no al guardar el formulario: así el error de subida —una
/// imagen de 8 MB, un formato raro— aparece en el momento de elegirla, y no al
/// final, después de haber llenado quince campos.
class CampoFoto extends StatefulWidget {
  const CampoFoto({
    super.key,
    required this.ruta,
    required this.carpeta,
    required this.onCambio,
    required this.onSubiendo,
    this.habilitado = true,
  });

  /// La foto actual, como ruta relativa. Nula si todavía no hay.
  final String? ruta;

  /// Dónde agruparla en el servidor: "vehiculos" o "conductores".
  final String carpeta;

  final ValueChanged<String?> onCambio;

  /// Avisa mientras sube, para que el formulario bloquee su botón de guardar.
  final ValueChanged<bool> onSubiendo;

  final bool habilitado;

  @override
  State<CampoFoto> createState() => _CampoFotoState();
}

class _CampoFotoState extends State<CampoFoto> {
  bool _subiendo = false;
  String? _error;

  Future<void> _elegir(ImageSource origen) async {
    final elegida = await ImagePicker().pickImage(
      source: origen,
      // Se reduce antes de mandarla: una foto de teléfono son varios MB y el
      // servidor rechaza a partir de cinco. Para reconocer un camión o leer
      // una placa, 1600 px sobran.
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (elegida == null) return;

    setState(() {
      _subiendo = true;
      _error = null;
    });
    widget.onSubiendo(true);

    try {
      final ruta = await const ArchivoApi().subirImagen(
        File(elegida.path),
        carpeta: widget.carpeta,
      );
      widget.onCambio(ruta);
    } on ApiExcepcion catch (e) {
      setState(() => _error = e.texto);
    } finally {
      if (mounted) setState(() => _subiendo = false);
      widget.onSubiendo(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ruta = widget.ruta;
    final activo = widget.habilitado && !_subiendo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Foto',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colores.tintaSuave),
        ),
        const SizedBox(height: Dimen.espacio2),

        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colores.fondo,
            border: Border.all(color: Colores.linea),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
          clipBehavior: Clip.antiAlias,
          child: _subiendo
              ? const Center(child: CircularProgressIndicator())
              : ruta == null
              ? Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 36,
                    color: Colores.tintaTenue,
                  ),
                )
              : Image.network(
                  ArchivoApi.url(ruta),
                  fit: BoxFit.cover,
                  // Si la imagen no carga se dice, en vez de dejar un hueco
                  // gris que parece que la foto se perdió.
                  errorBuilder: (_, _, _) => const Center(
                    child: Text(
                      'No se pudo cargar la foto',
                      style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
                    ),
                  ),
                ),
        ),

        if (_error != null) ...[
          const SizedBox(height: Dimen.espacio1),
          Text(_error!, style: const TextStyle(fontSize: 12, color: Colores.peligro)),
        ],

        const SizedBox(height: Dimen.espacio2),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: activo ? () => _elegir(ImageSource.camera) : null,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Cámara'),
              ),
            ),
            const SizedBox(width: Dimen.espacio2),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: activo ? () => _elegir(ImageSource.gallery) : null,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galería'),
              ),
            ),
            if (ruta != null) ...[
              const SizedBox(width: Dimen.espacio2),
              IconButton(
                onPressed: activo ? () => widget.onCambio(null) : null,
                tooltip: 'Quitar la foto',
                icon: const Icon(Icons.delete_outline, color: Colores.peligro),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Campo de fecha con formato local y botón para limpiarla.
///
/// Los vencimientos son opcionales —hay vehículos sin permiso municipal porque
/// no les aplica— así que poder dejarlo en blanco es parte del caso normal, no
/// una excepción.
class CampoFecha extends StatelessWidget {
  const CampoFecha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onCambio,
    this.habilitado = true,
  });

  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime?> onCambio;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: habilitado
          ? () async {
              final elegida = await showDatePicker(
                context: context,
                initialDate: valor ?? DateTime.now(),
                // Hacia atrás también: se da de alta un vehículo cuyo SOAT ya
                // venció, justamente para que salte la alerta.
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
              );
              if (elegida != null) onCambio(elegida);
            }
          : null,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: const Icon(Icons.event_outlined, size: 19, color: Colores.tintaTenue),
          suffixIcon: valor == null
              ? null
              : IconButton(
                  onPressed: habilitado ? () => onCambio(null) : null,
                  icon: const Icon(Icons.close, size: 18, color: Colores.tintaTenue),
                  tooltip: 'Quitar la fecha',
                ),
          constraints: const BoxConstraints(minHeight: Dimen.campoLg),
        ),
        child: Text(
          valor == null
              ? 'Sin fecha'
              : '${valor!.day.toString().padLeft(2, '0')}/'
                    '${valor!.month.toString().padLeft(2, '0')}/${valor!.year}',
          style: TextStyle(
            fontSize: 15,
            color: valor == null ? Colores.tintaTenue : Colores.tinta,
          ),
        ),
      ),
    );
  }
}

/// El color con el que se pinta un estado de documento.
Color colorEstado(BuildContext context, String estado) => switch (estado) {
  'vencido' => Colores.peligro,
  'porVencer' => Colores.advertencia,
  'alDia' => Colores.exito,
  _ => Acento.de(context),
};
