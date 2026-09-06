import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';

/// Alta y edicion de un usuario.
class UsuarioFormulario extends ConsumerStatefulWidget {
  const UsuarioFormulario({super.key, this.usuario});

  final Usuario? usuario;

  @override
  ConsumerState<UsuarioFormulario> createState() => _UsuarioFormularioState();
}

class _UsuarioFormularioState extends ConsumerState<UsuarioFormulario> {
  late final _nombre = TextEditingController(text: widget.usuario?.nombre ?? '');
  late final _email = TextEditingController(text: widget.usuario?.email ?? '');
  late final _dni = TextEditingController(text: widget.usuario?.dni ?? '');
  final _password = TextEditingController();

  late int? _rolId = widget.usuario?.rolId;

  bool _guardando = false;
  String? _error;
  String? _errorNombre;
  String? _errorEmail;
  String? _errorPassword;
  String? _errorRol;

  bool get _esNuevo => widget.usuario == null;

  @override
  void dispose() {
    for (final c in [_nombre, _email, _dni, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    final correo = _email.text.trim();
    final clave = _password.text;

    setState(() {
      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre.' : null;

      _errorEmail = correo.isEmpty
          ? 'Ingresa el correo.'
          : !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)
          ? 'Ese correo no tiene un formato válido.'
          : null;

      // Al crear la clave es obligatoria; al editar, vacio significa dejar la
      // que ya tenia.
      _errorPassword = _esNuevo && clave.isEmpty
          ? 'Ingresa una contraseña.'
          : clave.isNotEmpty && clave.length < 6
          ? 'Debe tener al menos 6 caracteres.'
          : null;

      _errorRol = _rolId == null ? 'Elige un rol.' : null;

      final dni = _dni.text.trim();
      if (dni.isNotEmpty && dni.length != 8) {
        _error = 'El DNI debe tener 8 dígitos.';
      } else {
        _error = null;
      }
    });

    return _errorNombre == null &&
        _errorEmail == null &&
        _errorPassword == null &&
        _errorRol == null &&
        _error == null;
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
      'email': _email.text.trim(),
      'dni': _dni.text.trim(),
      'rolId': _rolId,
      if (_esNuevo) 'password': _password.text,
      if (!_esNuevo) ...{
        'activo': widget.usuario!.activo,
        // Vacio: el backend deja la contraseña actual.
        if (_password.text.isNotEmpty) 'password': _password.text,
      },
    };

    try {
      await ref.read(usuariosProvider.notifier).guardar(id: widget.usuario?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Usuario creado' : 'Usuario actualizado')),
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
    final roles = ref.watch(rolesActivosProvider);

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'config',
      Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo usuario' : 'Editar usuario',
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
              icono: Icons.person_outline,
              error: _errorNombre,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _email,
              etiqueta: 'Correo',
              icono: Icons.mail_outline,
              tipoTeclado: TextInputType.emailAddress,
              error: _errorEmail,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _dni,
              etiqueta: 'DNI',
              icono: Icons.badge_outlined,
              opcional: true,
              tipoTeclado: TextInputType.number,
              formateadores: [FilteringTextInputFormatter.digitsOnly],
              maxLargo: 8,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int>(
              valor: _rolId,
              etiqueta: 'Rol',
              icono: Icons.verified_user_outlined,
              habilitado: !_guardando,
              error: _errorRol,
              opciones: [for (final rol in roles) Opcion(rol.id, rol.nombre)],
              onCambio: (v) => setState(() => _rolId = v),
            ),
            if (roles.isEmpty) ...[
              const SizedBox(height: Dimen.espacio2),
              const AppAlerta(
                'No hay roles activos. Crea uno en Roles antes de dar de alta un usuario.',
              ),
            ],
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _password,
              etiqueta: _esNuevo ? 'Contraseña' : 'Nueva contraseña',
              icono: Icons.lock_outline,
              // Al editar se puede dejar en blanco: cambiar el nombre de alguien
              // no deberia obligar a reescribir su clave.
              opcional: !_esNuevo,
              pista: _esNuevo ? 'Mínimo 6 caracteres' : 'Dejar vacío para no cambiarla',
              esPassword: true,
              error: _errorPassword,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBoton(
              texto: _esNuevo ? 'Crear usuario' : 'Guardar cambios',
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
