import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_logo.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../estado/auth_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

class LoginPagina extends ConsumerStatefulWidget {
  const LoginPagina({super.key});

  @override
  ConsumerState<LoginPagina> createState() => _LoginPaginaState();
}

/// Credenciales de demostracion, las mismas del panel web.
class _LoginPaginaState extends ConsumerState<LoginPagina> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _errorEmail;
  String? _errorPassword;
  bool _recordar = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Valida en el dispositivo antes de gastar una llamada al servidor.
  bool _validar() {
    final email = _email.text.trim();
    final password = _password.text;

    setState(() {
      // Usuario, correo o DNI: quien no tiene correo entra con lo que tenga.
      _errorEmail = email.isEmpty
          ? 'Ingresa tu usuario, correo o DNI.'
          : email.contains('@') &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
          ? 'El correo no tiene un formato válido.'
          : null;

      _errorPassword = password.isEmpty
          ? 'Ingresa tu contraseña.'
          : password.length < 6
          ? 'La contraseña debe tener al menos 6 caracteres.'
          : null;
    });

    return _errorEmail == null && _errorPassword == null;
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    await ref
        .read(authProvider.notifier)
        .entrar(
          email: _email.text,
          password: _password.text,
          recordar: _recordar,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colores.superficie,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimen.espacio5,
              vertical: Dimen.espacio6,
            ),
            child: ConstrainedBox(
              // En tablet el formulario no se estira a lo ancho de la pantalla.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Dimen.espacio4),
                  const Center(child: AppLogo(tam: 92, conTexto: true)),
                  const SizedBox(height: Dimen.espacio5),

                  const Text(
                    'Inicia sesión para tomar pedidos, cobrar y registrar tus visitas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colores.tintaSuave,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: Dimen.espacio5),

                  if (auth.error != null) ...[
                    AppAlerta(auth.error!),
                    const SizedBox(height: Dimen.espacio4),
                  ],

                  AppCampo(
                    controlador: _email,
                    etiqueta: 'Usuario, correo o DNI',
                    pista: 'usuario, correo o DNI',
                    icono: Icons.mail_outline,
                    // Texto y no correo: quien no tiene correo escribe su DNI.
                    tipoTeclado: TextInputType.text,
                    accionTeclado: TextInputAction.next,
                    error: _errorEmail,
                    habilitado: !auth.enviando,
                  ),
                  const SizedBox(height: Dimen.espacio4),

                  AppCampo(
                    controlador: _password,
                    etiqueta: 'Contraseña',
                    pista: 'Mínimo 6 caracteres',
                    icono: Icons.lock_outline,
                    esPassword: true,
                    accionTeclado: TextInputAction.done,
                    alEnviar: _entrar,
                    error: _errorPassword,
                    habilitado: !auth.enviando,
                    ayuda: TextButton(
                      onPressed: () => Aviso.de(
                        context,
                      ).mostrar('Pide a tu administrador que la restablezca.'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: _recordar,
                    onChanged: auth.enviando
                        ? null
                        : (v) => setState(() => _recordar = v ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Mantener sesión iniciada en este equipo',
                      style: TextStyle(fontSize: 13, color: Colores.tinta),
                    ),
                  ),
                  const SizedBox(height: Dimen.espacio3),

                  AppBoton(
                    texto: 'Ingresar',
                    iconoDerecha: Icons.arrow_forward,
                    cargando: auth.enviando,
                    onPressed: _entrar,
                  ),
                  const SizedBox(height: Dimen.espacio5),

                  const _PieVersion(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PieVersion extends StatelessWidget {
  const _PieVersion();

  @override
  Widget build(BuildContext context) {
    return Text(
      '© ${DateTime.now().year} Titanic D · Suite operativa',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11, color: Colores.tintaTenue),
    );
  }
}
