import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/mercado.dart';
import '../estado/tms_controlador.dart';

/// Alta y edicion de un mercado.
class MercadoFormulario extends ConsumerStatefulWidget {
  const MercadoFormulario({super.key, this.mercado});

  /// Null cuando es un mercado nuevo.
  final Mercado? mercado;

  @override
  ConsumerState<MercadoFormulario> createState() => _MercadoFormularioState();
}

class _MercadoFormularioState extends ConsumerState<MercadoFormulario> {
  late final _nombre = TextEditingController(text: widget.mercado?.nombre ?? '');
  late final _direccion = TextEditingController(text: widget.mercado?.direccion ?? '');
  late final _distrito = TextEditingController(text: widget.mercado?.distrito ?? '');

  bool _guardando = false;
  String? _error;
  String? _errorNombre;

  bool get _esNuevo => widget.mercado == null;

  @override
  void dispose() {
    for (final c in [_nombre, _direccion, _distrito]) {
      c.dispose();
    }
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
      'direccion': _direccion.text.trim().isNotEmpty ? _direccion.text.trim() : null,
      'distrito': _distrito.text.trim().isNotEmpty ? _distrito.text.trim() : null,
      if (!_esNuevo) 'activo': widget.mercado!.activo,
    };

    try {
      await ref
          .read(mercadosProvider.notifier)
          .guardar(id: widget.mercado?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Mercado creado' : 'Mercado actualizado')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esNuevo ? 'Nuevo mercado' : 'Editar mercado',
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

          AppCampo(
            controlador: _nombre,
            etiqueta: 'Nombre',
            pista: 'Mercado Central, Tienda Norte...',
            icono: Icons.storefront_outlined,
            error: _errorNombre,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _direccion,
            etiqueta: 'Dirección',
            icono: Icons.location_on_outlined,
            opcional: true,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _distrito,
            etiqueta: 'Distrito',
            icono: Icons.map_outlined,
            opcional: true,
            habilitado: !_guardando,
          ),

          const SizedBox(height: Dimen.espacio2),
          AppBoton(
            texto: _esNuevo ? 'Crear mercado' : 'Guardar cambios',
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
    );
  }
}
