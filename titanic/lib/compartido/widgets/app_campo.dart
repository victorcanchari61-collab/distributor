import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Campo de texto del sistema.
///
/// La etiqueta va encajada en la muesca del borde y se queda ahi siempre, este
/// el campo vacio o lleno: no baila al escribir y el formulario ocupa menos
/// alto que con la etiqueta puesta encima.
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
    final campo = TextField(
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
        // "(opcional)" viaja dentro de la etiqueta: en la muesca se lee como
        // una sola frase y no necesita un hueco aparte.
        label: Text.rich(
          TextSpan(
            text: widget.etiqueta,
            children: [
              if (widget.opcional)
                const TextSpan(
                  text: ' (opcional)',
                  style: TextStyle(color: Colores.tintaTenue),
                ),
            ],
          ),
        ),
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
                tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
              )
            : null,
        constraints: const BoxConstraints(minHeight: Dimen.campoLg),
      ),
    );

    if (widget.ayuda == null) return campo;

    // La ayuda ("¿Olvidaste tu contraseña?") ya no cabe junto a la etiqueta:
    // ahora va bajo el campo, alineada a la derecha.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        campo,
        const SizedBox(height: Dimen.espacio1),
        Align(alignment: Alignment.centerRight, child: widget.ayuda!),
      ],
    );
  }
}
