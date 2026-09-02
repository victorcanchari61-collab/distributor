import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/proveedor.dart';
import '../estado/maestros_controlador.dart';

const _tipos = ['RUC', 'DNI', 'CODIGO'];

/// Alta y edicion de un proveedor.
class ProveedorFormulario extends ConsumerStatefulWidget {
  const ProveedorFormulario({super.key, this.proveedor});

  final Proveedor? proveedor;

  @override
  ConsumerState<ProveedorFormulario> createState() =>
      _ProveedorFormularioState();
}

class _ProveedorFormularioState extends ConsumerState<ProveedorFormulario> {
  late final _documento = TextEditingController(
    text: widget.proveedor?.documento ?? '',
  );
  late final _nombre = TextEditingController(
    text: widget.proveedor?.nombre ?? '',
  );
  late final _comercial = TextEditingController(
    text: widget.proveedor?.nombreComercial ?? '',
  );
  late final _rubro = TextEditingController(
    text: widget.proveedor?.rubro ?? '',
  );
  late final _direccion = TextEditingController(
    text: widget.proveedor?.direccion ?? '',
  );
  late final _distrito = TextEditingController(
    text: widget.proveedor?.distrito ?? '',
  );
  late final _telefono = TextEditingController(
    text: widget.proveedor?.telefono ?? '',
  );

  late String _tipoDoc = widget.proveedor?.tipoDoc.isNotEmpty == true
      ? widget.proveedor!.tipoDoc
      : 'RUC';

  bool _guardando = false;
  String? _error;
  String? _errorDocumento;
  String? _errorNombre;

  bool get _esNuevo => widget.proveedor == null;

  @override
  void dispose() {
    for (final c in [
      _documento,
      _nombre,
      _comercial,
      _rubro,
      _direccion,
      _distrito,
      _telefono,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  ({int min, int max}) get _largo => switch (_tipoDoc) {
    'DNI' => (min: 8, max: 8),
    'RUC' => (min: 11, max: 11),
    _ => (min: 3, max: 15),
  };

  bool _validar() {
    final doc = _documento.text.trim();
    final l = _largo;

    setState(() {
      _errorDocumento = doc.isEmpty
          ? 'Ingresa el documento.'
          : doc.length < l.min || doc.length > l.max
          ? l.min == l.max
                ? 'Un $_tipoDoc tiene ${l.min} dígitos.'
                : 'Entre ${l.min} y ${l.max} dígitos.'
          : null;

      _errorNombre = _nombre.text.trim().isEmpty
          ? 'Ingresa la razón social.'
          : null;
    });

    return _errorDocumento == null && _errorNombre == null;
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
      'documento': _documento.text.trim(),
      'tipoDoc': _tipoDoc,
      'nombre': _nombre.text.trim(),
      'nombreComercial': _comercial.text.trim(),
      'rubro': _rubro.text.trim(),
      'direccion': _direccion.text.trim(),
      'distrito': _distrito.text.trim(),
      'telefono': _telefono.text.trim(),
      if (!_esNuevo) 'activo': widget.proveedor!.activo,
    };

    try {
      await ref
          .read(proveedoresProvider.notifier)
          .guardar(id: widget.proveedor?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            _esNuevo ? 'Proveedor creado' : 'Proveedor actualizado',
          ),
        ),
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
          _esNuevo ? 'Nuevo proveedor' : 'Editar proveedor',
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

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colores.tinta,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _tipoDoc,
                      // isExpanded: sin esto el texto no cede espacio y el
                      // desplegable se desborda por unos pixeles.
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Dimen.espacio2,
                        ),
                      ),
                      items: [
                        for (final t in _tipos)
                          DropdownMenuItem(
                            value: t,
                            child: Text(t == 'CODIGO' ? 'Código' : t),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _tipoDoc = v ?? 'RUC';
                        final max = _largo.max;
                        if (_documento.text.length > max) {
                          _documento.text = _documento.text.substring(0, max);
                        }
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppCampo(
                  controlador: _documento,
                  etiqueta: 'Documento',
                  tipoTeclado: TextInputType.number,
                  formateadores: [FilteringTextInputFormatter.digitsOnly],
                  maxLargo: _largo.max,
                  error: _errorDocumento,
                  habilitado: !_guardando,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _nombre,
            etiqueta: 'Razón social',
            error: _errorNombre,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _comercial,
            etiqueta: 'Nombre comercial',
            opcional: true,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _rubro,
            etiqueta: 'Rubro',
            pista: 'Ej. Fideos y harinas',
            opcional: true,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _direccion,
            etiqueta: 'Dirección',
            opcional: true,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: _distrito,
                  etiqueta: 'Distrito',
                  opcional: true,
                  habilitado: !_guardando,
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppCampo(
                  controlador: _telefono,
                  etiqueta: 'Teléfono',
                  opcional: true,
                  tipoTeclado: TextInputType.phone,
                  habilitado: !_guardando,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio6),

          AppBoton(
            texto: _esNuevo ? 'Crear proveedor' : 'Guardar cambios',
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
