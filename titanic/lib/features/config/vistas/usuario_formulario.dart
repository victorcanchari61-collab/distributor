import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/empleado.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

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

  /// De quien es esta cuenta. Null es "sin empleado".
  late int? _empleadoId = widget.usuario?.empleadoId;

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

  /*
   * Elegir empleado llena los datos de la cuenta con los de su ficha.
   *
   * Se pisa lo que haya, no solo lo vacio: elegir a alguien es decir "esta
   * cuenta es de esta persona", y al cambiar de empleado los datos del
   * anterior tienen que irse con el. Lo que la ficha NO tiene se deja como
   * esta en vez de borrarlo —un empleado sin correo cargado no deberia vaciar
   * el que se acaba de escribir— y "Sin empleado" tampoco borra nada: lo
   * escrito sigue sirviendo aunque la cuenta no sea de nadie del padron.
   */
  void _elegirEmpleado(int? empleadoId, List<EmpleadoOpcion> empleados) {
    final empleado = empleados.where((e) => e.id == empleadoId).firstOrNull;

    setState(() {
      _empleadoId = empleadoId;
      if (empleado == null) return;

      _nombre.text = empleado.nombreCompleto;
      // El codigo interno de un extranjero no es un DNI: ese campo solo acepta
      // ocho digitos y lo rechazaria al guardar.
      if (empleado.tipoDoc == 'DNI') _dni.text = empleado.documento;
      final correo = empleado.email?.trim() ?? '';
      if (correo.isNotEmpty) _email.text = correo;
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    final cuerpo = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'email': _email.text.trim(),
      'dni': _dni.text.trim(),
      'rolId': _rolId,
      // Viaja SIEMPRE, tambien cuando nadie toco el selector: el PUT reemplaza
      // el registro, asi que no mandarlo desenlazaria la ficha de quien ya la
      // tenia solo por haber cambiado el nombre.
      'empleadoId': _empleadoId,
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
      mensajero.mostrar(_esNuevo ? 'Usuario creado' : 'Usuario actualizado');
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
    // Si el padron no carga se sigue sin el: el enlace es opcional, y quedarse
    // sin poder crear un usuario porque Empleados fallo seria peor.
    final empleados =
        ref.watch(empleadosOpcionesProvider).valueOrNull ??
        const <EmpleadoOpcion>[];

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'config',
      (context) => Scaffold(
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

            /*
             * De quien es esta cuenta, lo primero que se elige.
             *
             * Es OPCIONAL: hay cuentas que no son de nadie del padron
             * —soporte, la del dueño— y empleados que nunca entran al sistema.
             * Va arriba porque al elegir a alguien se llenan solos su DNI, su
             * nombre y su correo, y lo de abajo queda para corregir y no para
             * teclear.
             */
            AppSelector<int?>(
              valor: _empleadoId,
              etiqueta: 'Empleado (opcional)',
              icono: Icons.groups_outlined,
              habilitado: !_guardando,
              opciones: [
                const Opcion<int?>(null, 'Sin empleado'),
                for (final e in empleados)
                  Opcion<int?>(
                    e.id,
                    // El que ya tiene cuenta sale en la lista pero ocupado; el
                    // suyo propio no, o al editarlo el selector saldria vacio.
                    e.usuarioId != null && e.usuarioId != widget.usuario?.id
                        ? '${e.etiqueta} (ya tiene usuario)'
                        : e.etiqueta,
                    habilitada:
                        e.usuarioId == null ||
                        e.usuarioId == widget.usuario?.id,
                  ),
              ],
              onCambio: (v) => _elegirEmpleado(v, empleados),
            ),
            const SizedBox(height: Dimen.espacio2),
            Text(
              empleados.isEmpty
                  ? 'Todavía no hay empleados registrados. Se dan de alta en Maestros → Empleados.'
                  : 'Al elegirlo se llenan el DNI, el nombre y el correo de su ficha.',
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),

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
