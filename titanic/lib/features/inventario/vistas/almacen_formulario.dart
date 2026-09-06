import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/almacen.dart';
import '../estado/inventario_controlador.dart';

/// Alta y edicion de un almacen.
class AlmacenFormulario extends ConsumerStatefulWidget {
  const AlmacenFormulario({super.key, this.almacen});

  /// Null cuando es un almacen nuevo.
  final Almacen? almacen;

  @override
  ConsumerState<AlmacenFormulario> createState() => _AlmacenFormularioState();
}

class _AlmacenFormularioState extends ConsumerState<AlmacenFormulario> {
  late final _codigo = TextEditingController(text: widget.almacen?.codigo ?? '');
  late final _nombre = TextEditingController(text: widget.almacen?.nombre ?? '');
  late final _direccion = TextEditingController(text: widget.almacen?.direccion ?? '');

  late bool _esPrincipal = widget.almacen?.esPrincipal ?? false;

  bool _guardando = false;
  String? _error;
  String? _errorCodigo;
  String? _errorNombre;

  bool get _esNuevo => widget.almacen == null;

  @override
  void dispose() {
    for (final c in [_codigo, _nombre, _direccion]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorCodigo = _codigo.text.trim().isEmpty ? 'Ingresa el código.' : null;
      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre.' : null;
    });
    return _errorCodigo == null && _errorNombre == null;
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
      'codigo': _codigo.text.trim(),
      'nombre': _nombre.text.trim(),
      'direccion': _direccion.text.trim(),
      'esPrincipal': _esPrincipal,
      if (!_esNuevo) 'activo': widget.almacen!.activo,
    };

    try {
      await ref.read(almacenesProvider.notifier).guardar(id: widget.almacen?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(_esNuevo ? 'Almacén creado' : 'Almacén actualizado')),
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
      'inv',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo almacén' : 'Editar almacén',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            AppCampo(
              controlador: _codigo,
              etiqueta: 'Código',
              icono: Icons.tag,
              pista: 'ALM-02',
              maxLargo: 20,
              error: _errorCodigo,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _nombre,
              etiqueta: 'Nombre',
              icono: Icons.warehouse_outlined,
              pista: 'Depósito norte',
              error: _errorNombre,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _direccion,
              etiqueta: 'Dirección',
              icono: Icons.place_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio3),

            CheckboxListTile(
              value: _esPrincipal,
              onChanged: _guardando ? null : (v) => setState(() => _esPrincipal = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Almacén principal',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colores.tinta),
              ),
              subtitle: const Text(
                'Solo uno puede serlo: sale por defecto en pedidos y ventas, y es del que se '
                'muestra el stock al buscar productos. Marcarlo desmarca al anterior.',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBoton(
              texto: _esNuevo ? 'Crear almacén' : 'Guardar cambios',
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
