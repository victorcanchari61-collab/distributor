import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Campo de texto del sistema: etiqueta arriba, campo debajo.
///
/// La etiqueta va fuera del recuadro (no flotante) para que se lea igual que en
/// el panel web y no baile al escribir.
class AppCampo extends StatefulWidget {
  const AppCampo({
    super.key,
    required this.controlador,
    required this.etiqueta,
    this.pista,
    this.icono,
    this.opcional = false,
    this.esPassword = false,
    this.tipoTeclado,
    this.formateadores,
    this.maxLargo,
    this.error,
    this.alEnviar,
    this.accionTeclado,
    this.habilitado = true,
    this.ayuda,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final String? pista;
  final IconData? icono;

  /// Marca "(opcional)" junto a la etiqueta, en gris.
  final bool opcional;

  final bool esPassword;
  final TextInputType? tipoTeclado;
  final List<TextInputFormatter>? formateadores;
  final int? maxLargo;
  final String? error;
  final VoidCallback? alEnviar;
  final TextInputAction? accionTeclado;
  final bool habilitado;

  /// Widget a la derecha de la etiqueta, como "¿Olvidaste tu contraseña?".
  final Widget? ayuda;

  @override
  State<AppCampo> createState() => _AppCampoState();
}

class _AppCampoState extends State<AppCampo> {
  late bool _oculto = widget.esPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La etiqueta cede espacio y se recorta: junto a una ayuda larga como
        // "¿Olvidaste tu contraseña?" no cabian las dos en pantallas angostas.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text.rich(
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  text: widget.etiqueta,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colores.tinta,
                  ),
                  children: [
                    if (widget.opcional)
                      const TextSpan(
                        text: '  (opcional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: Colores.tintaTenue,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.ayuda != null) ...[
              const SizedBox(width: Dimen.espacio2),
              Flexible(child: widget.ayuda!),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controlador,
          obscureText: _oculto,
          enabled: widget.habilitado,
          keyboardType: widget.tipoTeclado,
          inputFormatters: widget.formateadores,
          maxLength: widget.maxLargo,
          textInputAction: widget.accionTeclado,
          onSubmitted: (_) => widget.alEnviar?.call(),
          style: const TextStyle(fontSize: 15, color: Colores.tinta),
          decoration: InputDecoration(
            hintText: widget.pista,
            errorText: widget.error,
            counterText: '',
            prefixIcon: widget.icono == null
                ? null
                : Icon(widget.icono, size: 19, color: Colores.tintaTenue),
            suffixIcon: widget.esPassword
                ? IconButton(
                    onPressed: () => setState(() => _oculto = !_oculto),
                    icon: Icon(
                      _oculto
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: Colores.tintaTenue,
                    ),
                    tooltip: _oculto
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                  )
                : null,
            constraints: const BoxConstraints(minHeight: Dimen.campoLg),
          ),
        ),
      ],
    );
  }
}
