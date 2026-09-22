import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../compartido/widgets/app_alerta.dart';
import '../../compartido/widgets/app_boton.dart';
import '../../compartido/widgets/app_campo.dart';
import '../navegacion/menu.dart';
import '../red/cliente_api.dart';
import '../red/excepciones.dart';
import '../tema/colores.dart';
import '../tema/dimensiones.dart';
import 'solicitud_api.dart';

/// Como se lee la accion negada dentro de la frase.
const _accionNegada = {
  'ver': 'entrar a',
  'crear': 'crear en',
  'editar': 'editar en',
  'anular': 'anular en',
  'eliminar': 'eliminar en',
  'exportar': 'exportar de',
  'importar': 'importar en',
  'confirmar': 'confirmar en',
  'cobrar': 'registrar cobros en',
};

/// Lo que ve alguien cuando el servidor le niega una acción.
///
/// Un "no autorizado" a secas deja a la persona sin salida: sabe que no puede
/// y nada más. Aquí la negativa es el punto donde se pide el permiso, que es
/// justo cuando se sabe para qué hace falta — el motivo lo escribe quien lo
/// necesita, no quien lo aprueba.
///
/// Se engancha una sola vez al cliente HTTP, no pantalla por pantalla: son
/// treinta y nueve, y pedirle a cada una que se acuerde garantiza que la mitad
/// no lo haga.
class VigilantePermisos extends ConsumerStatefulWidget {
  const VigilantePermisos({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VigilantePermisos> createState() => _VigilantePermisosState();
}

class _VigilantePermisosState extends ConsumerState<VigilantePermisos> {
  /// Evita dos hojas encima: una pantalla puede lanzar varias llamadas a la
  /// vez y recibir dos 403 seguidos por lo mismo.
  bool _abierta = false;

  @override
  void initState() {
    super.initState();
    ClienteApi.alNegarPermiso = _abrir;
  }

  @override
  void dispose() {
    ClienteApi.alNegarPermiso = null;
    super.dispose();
  }

  void _abrir(ApiExcepcion e) {
    if (_abierta || !mounted) return;
    _abierta = true;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colores.superficie,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimen.radioPanel),
        ),
      ),
      builder: (_) => _Hoja(submodulo: e.submodulo!, accion: e.accion!),
    ).whenComplete(() => _abierta = false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Hoja extends ConsumerStatefulWidget {
  const _Hoja({required this.submodulo, required this.accion});

  final String submodulo;
  final String accion;

  @override
  ConsumerState<_Hoja> createState() => _HojaState();
}

class _HojaState extends ConsumerState<_Hoja> {
  final _motivo = TextEditingController();
  bool _enviando = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _pedir() async {
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await ref
          .read(solicitudApiProvider)
          .solicitar(
            submodulo: widget.submodulo,
            accion: widget.accion,
            motivo: _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
          );
      setState(() {
        _enviando = false;
        _enviado = true;
      });
    } on ApiExcepcion catch (e) {
      setState(() {
        _enviando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantalla = vistaPorId(widget.submodulo)?.titulo ?? widget.submodulo;
    final accion = _accionNegada[widget.accion] ?? widget.accion;

    return Padding(
      padding: EdgeInsets.only(
        left: Dimen.espacio4,
        right: Dimen.espacio4,
        bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_person_outlined,
                size: 20,
                color: Colores.advertencia,
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: Text(
                  _enviado ? 'Pedido enviado' : 'No puedes $accion $pantalla',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio3),

          if (_enviado) ...[
            const Text(
              'Un administrador lo verá en su bandeja. Cuando te lo conceda '
              'podrás seguir sin volver a entrar.',
              style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppBoton(
              texto: 'Entendido',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ] else ...[
            const Text(
              'Tu rol no lo incluye. Puedes pedírselo a un administrador desde '
              'aquí mismo.',
              style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio3),

            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],

            // El motivo es lo único que explica para qué hace falta. Va aquí y
            // no en la bandeja porque aquí es donde se sabe: quien aprueba no
            // tiene por qué adivinar qué documento había delante.
            AppCampo(
              controlador: _motivo,
              etiqueta: 'Para qué lo necesitas',
              pista: 'Ej.: la NV-000002 salió con el cliente equivocado',
              opcional: true,
              maxLargo: 250,
              habilitado: !_enviando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppBoton(
              texto: 'Pedir permiso',
              cargando: _enviando,
              onPressed: _pedir,
            ),
            const SizedBox(height: Dimen.espacio2),
            AppBoton(
              texto: 'Ahora no',
              variante: BotonVariante.secundario,
              onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            ),
          ],
          const SizedBox(height: Dimen.espacio2),
        ],
      ),
    );
  }
}
