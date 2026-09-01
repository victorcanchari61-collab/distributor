import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_logo.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../estado/auth_controlador.dart';

class LoginPagina extends ConsumerStatefulWidget {
  const LoginPagina({super.key});

  @override
  ConsumerState<LoginPagina> createState() => _LoginPaginaState();
}

/// Credenciales de demostracion, las mismas del panel web.
const _demo = (email: 'admin@distributor.com', password: '123456');

class _LoginPaginaState extends ConsumerState<LoginPagina> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _errorEmail;
  String? _errorPassword;

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
      _errorEmail = email.isEmpty
          ? 'Ingresa tu correo electrónico.'
          : !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
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

  /// Llena el formulario con el usuario de prueba, sin iniciar sesion: el
  /// usuario ve que se completo y decide entrar.
  void _usarDemo() {
    setState(() {
      _email.text = _demo.email;
      _password.text = _demo.password;
      _errorEmail = null;
      _errorPassword = null;
    });
    ref.read(authProvider.notifier).limpiarError();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    await ref
        .read(authProvider.notifier)
        .entrar(email: _email.text, password: _password.text);
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
                    etiqueta: 'Correo electrónico',
                    pista: 'admin@distributor.com',
                    icono: Icons.mail_outline,
                    tipoTeclado: TextInputType.emailAddress,
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
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Pide a tu administrador que la restablezca.',
                              ),
                            ),
                          ),
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
                  const SizedBox(height: Dimen.espacio5),

                  AppBoton(
                    texto: 'Ingresar',
                    iconoDerecha: Icons.arrow_forward,
                    cargando: auth.enviando,
                    onPressed: _entrar,
                  ),
                  const SizedBox(height: Dimen.espacio3),

                  // Wrap y no Row: en pantallas angostas la frase y el boton no
                  // caben en una linea y el boton pasa abajo en vez de cortarse.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        '¿Solo quieres echar un vistazo?',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colores.tintaSuave,
                        ),
                      ),
                      TextButton(
                        onPressed: auth.enviando ? null : _usarDemo,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimen.espacio2,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Usar credenciales de prueba',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
