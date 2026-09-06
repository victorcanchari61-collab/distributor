import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/ruta.dart';
import '../estado/tms_controlador.dart';

/// Alta y edicion de una ruta.
class RutaFormulario extends ConsumerStatefulWidget {
  const RutaFormulario({super.key, this.ruta});

  /// Null cuando es una ruta nueva.
  final Ruta? ruta;

  @override
  ConsumerState<RutaFormulario> createState() => _RutaFormularioState();
}

class _RutaFormularioState extends ConsumerState<RutaFormulario> {
  late final _nombre = TextEditingController(text: widget.ruta?.nombre ?? '');

  bool _guardando = false;
  String? _error;
  String? _errorNombre;

  bool get _esNuevo => widget.ruta == null;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre.' : null;
    });
    return _errorNombre == null;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);

    final cuerpo = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      if (!_esNuevo) 'activo': widget.ruta!.activo,
    };

    try {
      await ref.read(rutasProvider.notifier).guardar(id: widget.ruta?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Ruta creada' : 'Ruta actualizada')),
      );
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
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'tms',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nueva ruta' : 'Editar ruta',
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
              pista: 'Ruta 1, Zona Norte...',
              icono: Icons.route_outlined,
              error: _errorNombre,
              habilitado: !_guardando,
            ),

            const SizedBox(height: Dimen.espacio2),
            AppBoton(
              texto: _esNuevo ? 'Crear ruta' : 'Guardar cambios',
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
