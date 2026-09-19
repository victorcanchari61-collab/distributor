import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/novedad.dart';
import '../estado/novedades_controlador.dart';

/// Alta y edición de un motivo de novedad.
class MotivoNovedadFormulario extends ConsumerStatefulWidget {
  const MotivoNovedadFormulario({super.key, this.motivo});

  /// Null cuando es un motivo nuevo.
  final MotivoNovedad? motivo;

  @override
  ConsumerState<MotivoNovedadFormulario> createState() => _MotivoNovedadFormularioState();
}

class _MotivoNovedadFormularioState extends ConsumerState<MotivoNovedadFormulario> {
  late final _nombre = TextEditingController(text: widget.motivo?.nombre ?? '');
  late final _descripcion = TextEditingController(text: widget.motivo?.descripcion ?? '');
  late bool _regresa = widget.motivo?.regresaAlAlmacen ?? true;

  bool _guardando = false;
  String? _error;
  String? _errorNombre;

  bool get _esNuevo => widget.motivo == null;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    setState(() => _errorNombre = _nombre.text.trim().isEmpty ? 'Ponle un nombre al motivo.' : null);
    if (_errorNombre != null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    final cuerpo = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim().isNotEmpty ? _descripcion.text.trim() : null,
      'regresaAlAlmacen': _regresa,
      'activo': widget.motivo?.activo ?? true,
    };

    try {
      await ref.read(motivosNovedadProvider.notifier).guardar(id: widget.motivo?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.mostrar(_esNuevo ? 'Motivo creado' : 'Motivo actualizado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo.
    return Acento.modulo(
      'tms',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo motivo' : 'Editar motivo',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            AppCampo(
              controlador: _nombre,
              etiqueta: 'Nombre',
              pista: 'Cliente no quiso, Producto dañado, Faltó en el carro...',
              icono: Icons.label_outline,
              error: _errorNombre,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _descripcion,
              etiqueta: 'Descripción',
              icono: Icons.notes_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio3),

            CheckboxListTile(
              value: _regresa,
              onChanged: _guardando ? null : (v) => setState(() => _regresa = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'La mercadería viaja en el camión y vuelve al almacén',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colores.tinta),
              ),
              subtitle: const Text(
                'Márcalo cuando el producto salió y hay que contarlo al volver (el cliente lo '
                'rechazó, llegó dañado). Déjalo sin marcar si nunca salió del almacén (se '
                'olvidó cargar, no alcanzó).',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBoton(
              texto: _esNuevo ? 'Crear motivo' : 'Guardar cambios',
              cargando: _guardando,
              onPressed: _guardar,
            ),
            const SizedBox(height: Dimen.espacio3),
            AppBoton(
              texto: 'Cancelar',
              variante: BotonVariante.secundario,
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}
