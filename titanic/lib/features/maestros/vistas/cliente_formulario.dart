import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/cliente.dart';
import '../estado/maestros_controlador.dart';

const _dias = [
  'LUNES',
  'MARTES',
  'MIERCOLES',
  'JUEVES',
  'VIERNES',
  'SABADO',
  'DOMINGO',
];
const _tipos = ['DNI', 'RUC', 'CODIGO'];

/// Alta y edicion de un cliente.
class ClienteFormulario extends ConsumerStatefulWidget {
  const ClienteFormulario({super.key, this.cliente});

  /// Null cuando es un cliente nuevo.
  final Cliente? cliente;

  @override
  ConsumerState<ClienteFormulario> createState() => _ClienteFormularioState();
}

class _ClienteFormularioState extends ConsumerState<ClienteFormulario> {
  late final _documento = TextEditingController(
    text: widget.cliente?.documento ?? '',
  );
  late final _nombre = TextEditingController(
    text: widget.cliente?.nombre ?? '',
  );
  late final _direccion = TextEditingController(
    text: widget.cliente?.direccion ?? '',
  );
  late final _distrito = TextEditingController(
    text: widget.cliente?.distrito ?? '',
  );
  late final _telefono = TextEditingController(
    text: widget.cliente?.telefono ?? '',
  );
  late final _ruta = TextEditingController(text: widget.cliente?.ruta ?? '');
  late final _mercado = TextEditingController(
    text: widget.cliente?.mercado ?? '',
  );

  late String _tipoDoc = widget.cliente?.tipoDoc.isNotEmpty == true
      ? widget.cliente!.tipoDoc
      : 'DNI';
  late String? _diaVisita = widget.cliente?.diaVisita;

  bool _guardando = false;
  String? _error;
  String? _errorDocumento;
  String? _errorNombre;

  bool get _esNuevo => widget.cliente == null;

  @override
  void dispose() {
    for (final c in [
      _documento,
      _nombre,
      _direccion,
      _distrito,
      _telefono,
      _ruta,
      _mercado,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Largo que exige cada tipo, igual que en el panel web.
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

      _errorNombre = _nombre.text.trim().isEmpty ? 'Ingresa el nombre.' : null;
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
      'direccion': _direccion.text.trim(),
      'distrito': _distrito.text.trim(),
      'telefono': _telefono.text.trim(),
      'diaVisita': _diaVisita,
      'ruta': _ruta.text.trim(),
      'mercado': _mercado.text.trim(),
      if (!_esNuevo) 'activo': widget.cliente!.activo,
    };

    try {
      await ref
          .read(clientesProvider.notifier)
          .guardar(id: widget.cliente?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(
          content: Text(_esNuevo ? 'Cliente creado' : 'Cliente actualizado'),
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
          _esNuevo ? 'Nuevo cliente' : 'Editar cliente',
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

          // Tipo y numero juntos: el tipo cambia cuantos digitos se piden.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 132,
                child: DropdownButtonFormField<String>(
                  initialValue: _tipoDoc,
                  // isExpanded: sin esto el texto no cede espacio y el
                  // desplegable se desborda por unos pixeles.
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Dimen.espacio3,
                      vertical: Dimen.espacio3,
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
                    _tipoDoc = v ?? 'DNI';
                    // Se recorta si el nuevo tipo admite menos digitos.
                    final max = _largo.max;
                    if (_documento.text.length > max) {
                      _documento.text = _documento.text.substring(0, max);
                    }
                  }),
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
            etiqueta: 'Nombre',
            pista: 'Nombre del cliente o del puesto',
            error: _errorNombre,
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

          AppCampo(
            controlador: _distrito,
            etiqueta: 'Distrito',
            opcional: true,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _telefono,
            etiqueta: 'Teléfono',
            opcional: true,
            tipoTeclado: TextInputType.phone,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          DropdownButtonFormField<String?>(
            initialValue: _diaVisita,
            decoration: const InputDecoration(labelText: 'Día de visita'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin definir')),
              for (final d in _dias) DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: _guardando
                ? null
                : (v) => setState(() => _diaVisita = v),
          ),
          const SizedBox(height: Dimen.espacio4),

          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: _ruta,
                  etiqueta: 'Ruta',
                  opcional: true,
                  habilitado: !_guardando,
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppCampo(
                  controlador: _mercado,
                  etiqueta: 'Mercado',
                  opcional: true,
                  habilitado: !_guardando,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio6),

          AppBoton(
            texto: _esNuevo ? 'Crear cliente' : 'Guardar cambios',
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
