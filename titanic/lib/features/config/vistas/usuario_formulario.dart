import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/datos/empleado.dart';
import '../../maestros/estado/maestros_controlador.dart';
import '../../tms/datos/ruta.dart';
import '../../tms/estado/tms_controlador.dart' as tms;
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
  late final _nombre = TextEditingController(
    text: widget.usuario?.nombre ?? '',
  );
  late final _usuario = TextEditingController(
    text: widget.usuario?.nombreUsuario ?? '',
  );
  late final _email = TextEditingController(text: widget.usuario?.email ?? '');
  late final _dni = TextEditingController(text: widget.usuario?.dni ?? '');
  final _password = TextEditingController();

  /// Todos sus roles, el principal primero. Sus permisos son la UNIÓN de los de todos: tener más
  /// roles nunca le quita nada.
  late List<int> _rolIds = widget.usuario?.rolIds.isNotEmpty ?? false
      ? List.of(widget.usuario!.rolIds)
      : [if (widget.usuario?.rolId != null) widget.usuario!.rolId];

  /// De quien es esta cuenta. Null es "sin empleado".
  late int? _empleadoId = widget.usuario?.empleadoId;

  /// La ruta que tiene a cargo. Null es "sin ruta".
  late int? _rutaId = widget.usuario?.rutaId;

  bool _guardando = false;
  String? _error;
  String? _errorNombre;
  String? _errorEmail;
  String? _errorUsuario;
  String? _errorPassword;
  String? _errorRol;

  bool get _esNuevo => widget.usuario == null;

  @override
  void dispose() {
    for (final c in [_nombre, _usuario, _email, _dni, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    final correo = _email.text.trim();
    final clave = _password.text;

    setState(() {
      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre.' : null;

      // El usuario y el correo son opcionales, pero sin usuario, correo ni DNI la cuenta no tendria con que
      // iniciar sesion. El usuario exige al menos una letra: asi nunca se confunde con un DNI ni un correo.
      final usuario = _usuario.text.trim();
      _errorUsuario =
          usuario.isNotEmpty &&
              !RegExp(r'^(?=.*[A-Za-z])[A-Za-z0-9._-]{3,30}$').hasMatch(usuario)
          ? 'De 3 a 30 caracteres —letras, números, punto o guion— y al menos una letra.'
          : usuario.isEmpty && correo.isEmpty && _dni.text.trim().isEmpty
          ? 'Ingresa el usuario, el correo o el DNI: sin uno no podrá iniciar sesión.'
          : null;

      _errorEmail =
          correo.isNotEmpty &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)
          ? 'Ese correo no tiene un formato válido.'
          : null;

      // Al crear la clave es obligatoria; al editar, vacio significa dejar la
      // que ya tenia.
      _errorPassword = _esNuevo && clave.isEmpty
          ? 'Ingresa una contraseña.'
          : clave.isNotEmpty && clave.length < 6
          ? 'Debe tener al menos 6 caracteres.'
          : null;

      _errorRol = _rolIds.isEmpty ? 'Elige al menos un rol.' : null;

      final dni = _dni.text.trim();
      if (dni.isNotEmpty && dni.length != 8) {
        _error = 'El DNI debe tener 8 dígitos.';
      } else {
        _error = null;
      }
    });

    return _errorNombre == null &&
        _errorUsuario == null &&
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
      'nombreUsuario': _usuario.text.trim().isEmpty
          ? null
          : _usuario.text.trim(),
      'email': _email.text.trim(),
      'dni': _dni.text.trim(),
      // El primero es el principal. El PUT reemplaza el usuario: sin esto, guardar cualquier otro dato le
      // quitaria los roles que no se tocaron aqui.
      'rolIds': _rolIds,
      // Viaja SIEMPRE, tambien cuando nadie toco el selector: el PUT reemplaza
      // el registro, asi que no mandarlo desenlazaria la ficha de quien ya la
      // tenia solo por haber cambiado el nombre.
      'empleadoId': _empleadoId,
      // Igual: viaja siempre, o guardar cualquier otro cambio le quitaria la ruta.
      'rutaId': _rutaId,
      if (_esNuevo) 'password': _password.text,
      if (!_esNuevo) ...{
        'activo': widget.usuario!.activo,
        // Vacio: el backend deja la contraseña actual.
        if (_password.text.isNotEmpty) 'password': _password.text,
      },
    };

    try {
      await ref
          .read(usuariosProvider.notifier)
          .guardar(id: widget.usuario?.id, cuerpo: cuerpo);

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
    final rutas = ref.watch(tms.rutasProvider).valueOrNull ?? const <Ruta>[];
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
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio4),
            ],

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

            // Con lo que la persona entra: el usuario que ELIGE, su correo o su DNI, cualquiera de los tres.
            AppCampo(
              controlador: _usuario,
              etiqueta: 'Usuario',
              pista: 'jperez',
              icono: Icons.alternate_email,
              opcional: true,
              maxLargo: 30,
              formateadores: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
              error: _errorUsuario,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _email,
              etiqueta: 'Correo',
              icono: Icons.mail_outline,
              opcional: true,
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

            // Uno o varios roles: el primero que se marca es el principal. Sus permisos son la union de los de
            // todos, asi que agregar un rol nunca le quita nada de lo que ya tenia.
            _SelectorRoles(
              roles: roles,
              elegidos: _rolIds,
              error: _errorRol,
              habilitado: !_guardando,
              onCambio: (v) => setState(() {
                _rolIds = v;
                _errorRol = null;
              }),
            ),
            if (_rolIds.length > 1) ...[
              const SizedBox(height: Dimen.espacio1),
              Text(
                'Rol principal: ${roles.where((r) => r.id == _rolIds.first).map((r) => r.nombre).firstOrNull ?? ''}'
                '. Tendrá los permisos de todos sus roles juntos.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colores.tintaSuave,
                ),
              ),
            ],
            const SizedBox(height: Dimen.espacio4),

            // La cartera de clientes que atiende, para cualquier usuario y sin depender del rol: el
            // dueño también vende. Sola no restringe nada; lo que limita a "mis clientes" es el
            // alcance del rol, y con ese alcance sin ruta no se ve ningún cliente.
            AppSelector<int?>(
              valor: _rutaId,
              etiqueta: 'Ruta (opcional)',
              icono: Icons.alt_route,
              habilitado: !_guardando,
              opciones: [
                const Opcion<int?>(null, 'Sin ruta'),
                for (final r in rutas)
                  // Una ruta desactivada no se asigna, pero se sigue mostrando a quien ya la tiene.
                  if (r.activo || r.id == _rutaId)
                    Opcion<int?>(
                      r.id,
                      r.vendedores.isEmpty
                          ? 'Ruta ${r.nombre}'
                          : 'Ruta ${r.nombre} · ${r.vendedores.join(', ')}',
                    ),
              ],
              onCambio: (v) => setState(() => _rutaId = v),
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
              pista: _esNuevo
                  ? 'Mínimo 6 caracteres'
                  : 'Dejar vacío para no cambiarla',
              esPassword: true,
              error: _errorPassword,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBotonesFormulario(
              onCancelar: () => Navigator.of(context).pop(),
              onGuardar: _guardar,
              textoGuardar: _esNuevo ? 'Registrar' : 'Guardar',
              cargando: _guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}

/// Uno o varios roles: cada uno se marca sin cerrar nada, y el orden en que se marcan importa (el
/// primero es el principal). Hermano de AppSelector, pero de varios.
class _SelectorRoles extends StatelessWidget {
  const _SelectorRoles({
    required this.roles,
    required this.elegidos,
    required this.onCambio,
    this.error,
    this.habilitado = true,
  });

  final List<Rol> roles;
  final List<int> elegidos;
  final ValueChanged<List<int>> onCambio;
  final String? error;
  final bool habilitado;

  void _alternar(int rolId) {
    final siguientes = elegidos.contains(rolId)
        ? elegidos.where((id) => id != rolId).toList()
        : [...elegidos, rolId];
    onCambio(siguientes);
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Roles',
        prefixIcon: const Icon(
          Icons.verified_user_outlined,
          size: 19,
          color: Colores.tintaTenue,
        ),
        errorText: error,
        enabled: habilitado,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final rol in roles)
              FilterChip(
                label: Text(rol.nombre),
                selected: elegidos.contains(rol.id),
                onSelected: habilitado ? (_) => _alternar(rol.id) : null,
              ),
          ],
        ),
      ),
    );
  }
}
