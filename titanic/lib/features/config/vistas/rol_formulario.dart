import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';

/// Alta y edicion de un rol.
class RolFormulario extends ConsumerStatefulWidget {
  const RolFormulario({super.key, this.rol});

  final Rol? rol;

  @override
  ConsumerState<RolFormulario> createState() => _RolFormularioState();
}

class _RolFormularioState extends ConsumerState<RolFormulario> {
  late final _nombre = TextEditingController(text: widget.rol?.nombre ?? '');
  late final _descripcion = TextEditingController(text: widget.rol?.descripcion ?? '');

  bool _guardando = false;
  String? _error;
  String? _errorNombre;

  bool get _esNuevo => widget.rol == null;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre del rol.' : null;
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
      'descripcion': _descripcion.text.trim(),
      if (!_esNuevo) 'activo': widget.rol!.activo,
    };

    try {
      await ref.read(rolesProvider.notifier).guardar(id: widget.rol?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(SnackBar(content: Text(_esNuevo ? 'Rol creado' : 'Rol actualizado')));
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
      'config',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo rol' : 'Editar rol',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            if (widget.rol?.delSistema == true) ...[
              const AppAlerta(
                'Es un rol que trae el sistema. Puedes cambiar su descripción, pero conviene no renombrarlo.',
              ),
              const SizedBox(height: Dimen.espacio4),
            ],

            AppCampo(
              controlador: _nombre,
              etiqueta: 'Nombre',
              icono: Icons.verified_user_outlined,
              pista: 'Ej. Vendedor',
              error: _errorNombre,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _descripcion,
              etiqueta: 'Descripción',
              icono: Icons.notes_outlined,
              pista: 'Qué puede hacer quien tenga este rol',
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBoton(
              texto: _esNuevo ? 'Crear rol' : 'Guardar cambios',
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
