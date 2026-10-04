import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/novedad.dart';
import '../estado/novedades_controlador.dart';

/// Crear o editar un resultado de la revisión. La usan la pestaña Resultados
/// de Motivos de novedad y el "+" de la revisión, para crearlo sin salir.
///
/// Devuelve el resultado guardado, o null si se canceló.
Future<ResultadoRevision?> abrirHojaResultado(
  BuildContext context, {
  ResultadoRevision? editando,
}) {
  return showModalBottomSheet<ResultadoRevision>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    // La hoja cuelga del Navigator y no hereda el acento del modulo.
    builder: (context) =>
        Acento.modulo('tms', (_) => _HojaResultado(editando: editando)),
  );
}

class _HojaResultado extends ConsumerStatefulWidget {
  const _HojaResultado({this.editando});

  final ResultadoRevision? editando;

  @override
  ConsumerState<_HojaResultado> createState() => _HojaResultadoState();
}

class _HojaResultadoState extends ConsumerState<_HojaResultado> {
  late final _nombre = TextEditingController(
    text: widget.editando?.nombre ?? '',
  );
  late final _descripcion = TextEditingController(
    text: widget.editando?.descripcion ?? '',
  );
  late bool _volvioTodo = widget.editando?.volvioTodo ?? false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Ponle un nombre al resultado.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);

    try {
      final guardado = await ref
          .read(resultadosRevisionProvider.notifier)
          .guardar(
            id: widget.editando?.id,
            cuerpo: {
              'nombre': _nombre.text.trim(),
              'descripcion': _descripcion.text.trim().isEmpty
                  ? null
                  : _descripcion.text.trim(),
              'volvioTodo': _volvioTodo,
              'activo': widget.editando?.activo ?? true,
            },
          );
      navegador.pop(guardado);
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Con usos no se cambia si volvió todo: dejaría revisiones con un estado
    // que ya no corresponde a su resultado.
    final bloqueado = (widget.editando?.usos ?? 0) > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Dimen.espacio4,
        0,
        Dimen.espacio4,
        MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.editando == null
                ? 'Nuevo resultado'
                : 'Editar ${widget.editando!.nombre}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimen.espacio4),
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          AppCampo(
            controlador: _nombre,
            etiqueta: 'Nombre',
            pista: 'Pesaron mal el producto',
            icono: Icons.fact_check_outlined,
            maxLargo: 60,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio3),
          AppCampo(
            controlador: _descripcion,
            etiqueta: 'Descripción',
            icono: Icons.notes_outlined,
            opcional: true,
            maxLargo: 250,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio2),
          CheckboxListTile(
            value: _volvioTodo,
            onChanged: _guardando || bloqueado
                ? null
                : (v) => setState(() => _volvioTodo = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Volvió todo lo que no se entregó',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colores.tinta,
              ),
            ),
          ),
          const SizedBox(height: Dimen.espacio4),
          AppBoton(
            texto: widget.editando == null ? 'Crear' : 'Guardar',
            cargando: _guardando,
            onPressed: _guardar,
          ),
        ],
      ),
    );
  }
}
