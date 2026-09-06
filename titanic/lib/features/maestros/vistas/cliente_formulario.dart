import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/dimensiones.dart';
import '../../tms/estado/tms_controlador.dart';
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

  late String _tipoDoc = widget.cliente?.tipoDoc.isNotEmpty == true
      ? widget.cliente!.tipoDoc
      : 'DNI';
  late String? _diaVisita = widget.cliente?.diaVisita;
  late int? _mercadoId = widget.cliente?.mercadoId;

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
      'mercadoId': _mercadoId,
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
                child: AppSelector<String>(
                  valor: _tipoDoc,
                  etiqueta: 'Tipo',
                  habilitado: !_guardando,
                  opciones: const [
                    Opcion('DNI', 'DNI', icono: Icons.badge_outlined),
                    Opcion('RUC', 'RUC', icono: Icons.apartment_outlined),
                    Opcion('CODIGO', 'Código', icono: Icons.tag),
                  ],
                  onCambio: (v) => setState(() {
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
                  icono: Icons.badge_outlined,
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
            icono: Icons.person_outline,
            pista: 'Nombre del cliente o del puesto',
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
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _distrito,
            etiqueta: 'Distrito',
            icono: Icons.map_outlined,
            opcional: true,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _telefono,
            etiqueta: 'Teléfono',
            icono: Icons.phone_outlined,
            opcional: true,
            tipoTeclado: TextInputType.phone,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppSelector<String?>(
            valor: _diaVisita,
            etiqueta: 'Día de visita',
            icono: Icons.event_outlined,
            habilitado: !_guardando,
            opciones: [
              const Opcion<String?>(null, 'Sin definir'),
              for (final d in _dias) Opcion(d, d),
            ],
            onCambio: (v) => setState(() => _diaVisita = v),
          ),
          const SizedBox(height: Dimen.espacio4),

          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: _ruta,
                  etiqueta: 'Ruta',
                  icono: Icons.route_outlined,
                  opcional: true,
                  habilitado: !_guardando,
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppSelector<int?>(
                  valor: _mercadoId,
                  etiqueta: 'Mercado',
                  icono: Icons.storefront_outlined,
                  habilitado: !_guardando,
                  opciones: [
                    const Opcion<int?>(null, 'Sin mercado'),
                    for (final m in ref.watch(mercadosActivosProvider))
                      Opcion<int?>(m.id, m.nombre),
                  ],
                  onCambio: (v) => setState(() => _mercadoId = v),
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
