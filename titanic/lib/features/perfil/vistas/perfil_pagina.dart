import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../auth/estado/auth_controlador.dart';
import '../../tms/vistas/campo_foto.dart';
import '../estado/perfil_controlador.dart';

/// Mi perfil: los datos personales y la contrasena de quien tiene la sesion.
///
/// El rol y el estado no aparecen a proposito: son cosa de un administrador
/// desde Usuarios, y el backend tampoco los acepta por esta via.
class PerfilPagina extends ConsumerStatefulWidget {
  const PerfilPagina({super.key});

  static const ruta = '/perfil';

  @override
  ConsumerState<PerfilPagina> createState() => _PerfilPaginaState();
}

class _PerfilPaginaState extends ConsumerState<PerfilPagina> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _dni = TextEditingController();
  final _telefono = TextEditingController();

  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();

  String? _foto;
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendo = false;
  bool _cambiando = false;
  String? _error;
  String? _ok;
  String? _errorPassword;
  String? _okPassword;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _email, _dni, _telefono, _actual, _nueva, _repetir]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final perfil = await ref.read(perfilApiProvider).perfil();
      if (!mounted) return;
      setState(() {
        _nombre.text = perfil.nombre;
        _email.text = perfil.email;
        _dni.text = perfil.dni ?? '';
        _telefono.text = perfil.telefono ?? '';
        _foto = perfil.foto;
        _cargando = false;
      });
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.texto;
      });
    }
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();

    final nombre = _nombre.text.trim();
    final email = _email.text.trim();
    final dni = _dni.text.trim();

    if (nombre.isEmpty) {
      return setState(() => _error = 'Ingresa tu nombre.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return setState(() => _error = 'El correo no es válido.');
    }
    if (dni.isNotEmpty && dni.length != 8) {
      return setState(() => _error = 'El DNI debe tener 8 dígitos.');
    }

    setState(() {
      _guardando = true;
      _error = null;
      _ok = null;
    });

    try {
      final actualizado = await ref
          .read(perfilApiProvider)
          .actualizar({
            'nombre': nombre,
            'email': email,
            'dni': dni.isEmpty ? null : dni,
            'telefono': _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
            'foto': _foto,
          });

      // La sesion guardada se refresca para que la barra superior muestre el
      // nombre y la foto nuevos sin tener que cerrar sesion.
      await ref.read(authProvider.notifier).actualizarUsuario(actualizado);

      if (!mounted) return;
      setState(() {
        _guardando = false;
        _ok = 'Tus datos se guardaron.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  Future<void> _cambiarPassword() async {
    FocusScope.of(context).unfocus();

    if (_actual.text.isEmpty) {
      return setState(() => _errorPassword = 'Ingresa tu contraseña actual.');
    }
    if (_nueva.text.length < 6) {
      return setState(
        () => _errorPassword = 'La nueva contraseña debe tener al menos 6 caracteres.',
      );
    }
    if (_nueva.text != _repetir.text) {
      return setState(() => _errorPassword = 'Las contraseñas nuevas no coinciden.');
    }

    setState(() {
      _cambiando = true;
      _errorPassword = null;
      _okPassword = null;
    });

    try {
      await ref.read(perfilApiProvider).cambiarPassword(
        actual: _actual.text,
        nueva: _nueva.text,
      );

      if (!mounted) return;
      setState(() {
        _cambiando = false;
        _actual.clear();
        _nueva.clear();
        _repetir.clear();
        _okPassword = 'Contraseña actualizada.';
      });
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _cambiando = false;
        _errorPassword = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      titulo: 'Mi perfil',
      subtitulo: 'Mi cuenta',
      rutaActual: PerfilPagina.ruta,
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Dimen.espacio4),
              children: [
                if (_error != null) ...[
                  AppAlerta(_error!),
                  const SizedBox(height: Dimen.espacio4),
                ],

                CampoFoto(
                  ruta: _foto,
                  carpeta: 'usuarios',
                  habilitado: !_guardando,
                  onCambio: (ruta) => setState(() => _foto = ruta),
                  onSubiendo: (subiendo) => setState(() => _subiendo = subiendo),
                ),
                const SizedBox(height: Dimen.espacio4),

                AppCampo(
                  controlador: _nombre,
                  etiqueta: 'Nombre',
                  icono: Icons.person_outline,
                  habilitado: !_guardando,
                ),
                const SizedBox(height: Dimen.espacio4),

                AppCampo(
                  controlador: _email,
                  etiqueta: 'Correo',
                  icono: Icons.mail_outline,
                  tipoTeclado: TextInputType.emailAddress,
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

                AppCampo(
                  controlador: _telefono,
                  etiqueta: 'Teléfono',
                  icono: Icons.phone_outlined,
                  opcional: true,
                  tipoTeclado: TextInputType.phone,
                  maxLargo: 20,
                  habilitado: !_guardando,
                ),
                const SizedBox(height: Dimen.espacio5),

                AppBoton(
                  texto: 'Guardar cambios',
                  cargando: _guardando,
                  onPressed: _subiendo ? null : _guardar,
                ),
                if (_ok != null) ...[
                  const SizedBox(height: Dimen.espacio2),
                  Text(
                    _ok!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colores.exito,
                    ),
                  ),
                ],

                const SizedBox(height: Dimen.espacio6),
                const Divider(),
                const SizedBox(height: Dimen.espacio4),

                const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
                const SizedBox(height: Dimen.espacio1),
                const Text(
                  'Se pide la actual para que nadie la cambie desde una sesión ajena.',
                  style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                ),
                const SizedBox(height: Dimen.espacio4),

                if (_errorPassword != null) ...[
                  AppAlerta(_errorPassword!),
                  const SizedBox(height: Dimen.espacio4),
                ],

                AppCampo(
                  controlador: _actual,
                  etiqueta: 'Contraseña actual',
                  icono: Icons.lock_outline,
                  esPassword: true,
                  habilitado: !_cambiando,
                ),
                const SizedBox(height: Dimen.espacio4),

                AppCampo(
                  controlador: _nueva,
                  etiqueta: 'Nueva contraseña',
                  icono: Icons.lock_reset_outlined,
                  pista: 'Mínimo 6 caracteres',
                  esPassword: true,
                  habilitado: !_cambiando,
                ),
                const SizedBox(height: Dimen.espacio4),

                AppCampo(
                  controlador: _repetir,
                  etiqueta: 'Repetir nueva contraseña',
                  icono: Icons.lock_reset_outlined,
                  esPassword: true,
                  habilitado: !_cambiando,
                ),
                const SizedBox(height: Dimen.espacio5),

                AppBoton(
                  texto: 'Cambiar contraseña',
                  variante: BotonVariante.secundario,
                  cargando: _cambiando,
                  onPressed: _cambiarPassword,
                ),
                if (_okPassword != null) ...[
                  const SizedBox(height: Dimen.espacio2),
                  Text(
                    _okPassword!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colores.exito,
                    ),
                  ),
                ],
                const SizedBox(height: Dimen.espacio5),
              ],
            ),
    );
  }
}
