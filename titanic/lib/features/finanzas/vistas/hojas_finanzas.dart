import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../compartido/widgets/app_hoja.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';

/// Lo que repiten las hojas y listas de Finanzas: abrir una hoja con el acento
/// del modulo, el margen para el teclado y como se escriben montos y fechas.

/// Abre una hoja inferior de Finanzas, con el aspecto de un modal del panel
/// web: arriba la franja del color del módulo con el título, y debajo el
/// contenido.
///
/// El título lo dice el contenido con [TituloHoja]; la franja lo toma de ahí y
/// queda fija arriba mientras el contenido se desliza.
Future<void> abrirHojaFinanzas(BuildContext context, WidgetBuilder contenido) =>
    abrirHojaTitulada(context, contenido, modulo: 'finanzas');

/// Lo que comparten las hojas con franja: el título que dice el contenido.
class _TituloScope extends InheritedWidget {
  const _TituloScope({required this.titulo, required super.child});

  final ValueNotifier<String?> titulo;

  @override
  bool updateShouldNotify(_TituloScope anterior) => false;
}

/// Abre una hoja inferior con franja de título del módulo indicado.
///
/// La hoja cuelga del Navigator y no hereda el acento del módulo: se vuelve a
/// declarar, igual que en los formularios.
Future<void> abrirHojaTitulada(
  BuildContext context,
  WidgetBuilder contenido, {
  required String modulo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    builder: (context) =>
        Acento.modulo(modulo, (_) => _HojaConFranja(contenido: contenido)),
  );
}

class _HojaConFranja extends StatefulWidget {
  const _HojaConFranja({required this.contenido});

  final WidgetBuilder contenido;

  @override
  State<_HojaConFranja> createState() => _HojaConFranjaState();
}

class _HojaConFranjaState extends State<_HojaConFranja> {
  final _titulo = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: _titulo,
            builder: (context, titulo, _) => EncabezadoHoja(titulo ?? ''),
          ),
          Flexible(
            child: _TituloScope(
              titulo: _titulo,
              child: Builder(builder: widget.contenido),
            ),
          ),
        ],
      ),
    );
  }
}

/// El margen de una hoja, con lugar para el teclado cuando se abre.
EdgeInsets margenHoja(BuildContext context) => EdgeInsets.fromLTRB(
  Dimen.espacio4,
  0,
  Dimen.espacio4,
  MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
);

/// Dinero: como mucho dos decimales.
final soloMonto = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

/// El título de una hoja, con una línea de apoyo opcional debajo.
///
/// Dentro de una hoja con franja el título sube a la franja de color y aquí
/// queda solo la línea de apoyo; fuera de ella se pinta como texto.
class TituloHoja extends StatefulWidget {
  const TituloHoja(this.titulo, {super.key, this.apoyo});

  final String titulo;
  final String? apoyo;

  @override
  State<TituloHoja> createState() => _TituloHojaState();
}

class _TituloHojaState extends State<TituloHoja> {
  ValueNotifier<String?>? _franja;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _franja = context
        .dependOnInheritedWidgetOfExactType<_TituloScope>()
        ?.titulo;
    _publicar();
  }

  @override
  void didUpdateWidget(TituloHoja anterior) {
    super.didUpdateWidget(anterior);
    _publicar();
  }

  /// Le dice a la franja qué título poner. Se hace después del cuadro: avisar
  /// en medio de la construcción rompería a quien escucha.
  void _publicar() {
    final franja = _franja;
    if (franja == null || franja.value == widget.titulo) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) franja.value = widget.titulo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enFranja = _franja != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!enFranja)
          Text(
            widget.titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        if (widget.apoyo != null) ...[
          if (!enFranja) const SizedBox(height: Dimen.espacio1),
          Text(
            widget.apoyo!,
            style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
          ),
        ],
        const SizedBox(height: Dimen.espacio4),
      ],
    );
  }
}

String fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

String fechaHora(DateTime f) =>
    '${fechaCorta(f)} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
