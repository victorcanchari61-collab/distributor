import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';

/// Alta y edicion de la empresa.
class EmpresaFormulario extends ConsumerStatefulWidget {
  const EmpresaFormulario({super.key, this.empresa});

  final Empresa? empresa;

  @override
  ConsumerState<EmpresaFormulario> createState() => _EmpresaFormularioState();
}

class _EmpresaFormularioState extends ConsumerState<EmpresaFormulario> {
  late final _ruc = TextEditingController(text: widget.empresa?.ruc ?? '');
  late final _razonSocial = TextEditingController(
    text: widget.empresa?.razonSocial ?? '',
  );
  late final _comercial = TextEditingController(
    text: widget.empresa?.nombreComercial ?? '',
  );
  late final _direccion = TextEditingController(
    text: widget.empresa?.direccion ?? '',
  );
  late final _departamento = TextEditingController(
    text: widget.empresa?.departamento ?? '',
  );
  late final _provincia = TextEditingController(
    text: widget.empresa?.provincia ?? '',
  );
  late final _distrito = TextEditingController(
    text: widget.empresa?.distrito ?? '',
  );
  late final _telefono = TextEditingController(
    text: widget.empresa?.telefono ?? '',
  );
  late final _email = TextEditingController(text: widget.empresa?.email ?? '');
  late final _sitioWeb = TextEditingController(
    text: widget.empresa?.sitioWeb ?? '',
  );
  late final _representante = TextEditingController(
    text: widget.empresa?.representanteLegal ?? '',
  );

  bool _guardando = false;
  bool _consultando = false;
  String? _error;
  String? _aviso;
  String? _errorRuc;
  String? _errorRazon;
  String? _errorComercial;

  bool get _esNuevo => widget.empresa == null;

  @override
  void dispose() {
    for (final c in [
      _ruc,
      _razonSocial,
      _comercial,
      _direccion,
      _departamento,
      _provincia,
      _distrito,
      _telefono,
      _email,
      _sitioWeb,
      _representante,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Trae los datos de SUNAT y llena el formulario.
  Future<void> _consultarRuc() async {
    FocusScope.of(context).unfocus();
    final ruc = _ruc.text.trim();

    if (ruc.length != 11) {
      setState(() => _errorRuc = 'Un RUC tiene 11 dígitos.');
      return;
    }

    setState(() {
      _consultando = true;
      _errorRuc = null;
      _error = null;
      _aviso = null;
    });

    try {
      final datos = await ref.read(configApiProvider).consultarRuc(ruc);

      setState(() {
        _razonSocial.text = datos.razonSocial;
        if (_comercial.text.trim().isEmpty) {
          _comercial.text = datos.nombreComercial?.isNotEmpty == true
              ? datos.nombreComercial!
              : datos.razonSocial;
        }
        _direccion.text = datos.direccion ?? '';
        _departamento.text = datos.departamento ?? '';
        _provincia.text = datos.provincia ?? '';
        _distrito.text = datos.distrito ?? '';
        _consultando = false;

        // Se avisa pero no se bloquea: el usuario sabra si igual quiere
        // registrarla.
        if (datos.estado != null && datos.estado != 'ACTIVO') {
          _aviso = 'SUNAT reporta este RUC como ${datos.estado}.';
        }
      });
    } on ApiExcepcion catch (e) {
      setState(() {
        _consultando = false;
        _error = e.texto;
      });
    }
  }

  bool _validar() {
    setState(() {
      final ruc = _ruc.text.trim();
      _errorRuc = ruc.isEmpty
          ? 'Ingresa el RUC.'
          : ruc.length != 11
          ? 'Un RUC tiene 11 dígitos.'
          : null;

      _errorRazon = _razonSocial.text.trim().isEmpty
          ? 'Ingresa la razón social.'
          : null;

      _errorComercial = _comercial.text.trim().isEmpty
          ? 'Ingresa el nombre comercial.'
          : null;
    });

    return _errorRuc == null && _errorRazon == null && _errorComercial == null;
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
      'ruc': _ruc.text.trim(),
      'razonSocial': _razonSocial.text.trim(),
      'nombreComercial': _comercial.text.trim(),
      'direccion': _direccion.text.trim(),
      'departamento': _departamento.text.trim(),
      'provincia': _provincia.text.trim(),
      'distrito': _distrito.text.trim(),
      'telefono': _telefono.text.trim(),
      'email': _email.text.trim(),
      'sitioWeb': _sitioWeb.text.trim(),
      'representanteLegal': _representante.text.trim(),
      // Al crear no se activa sola: se activa desde el listado, para que quede
      // claro que se apaga la anterior.
      'activa': widget.empresa?.activa ?? false,
    };

    try {
      await ref
          .read(empresasProvider.notifier)
          .guardar(id: widget.empresa?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(
          content: Text(_esNuevo ? 'Empresa creada' : 'Empresa actualizada'),
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
          _esNuevo ? 'Nueva empresa' : 'Editar empresa',
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
          if (_aviso != null) ...[
            AppAlerta(_aviso!),
            const SizedBox(height: Dimen.espacio4),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppCampo(
                  controlador: _ruc,
                  etiqueta: 'RUC',
                  icono: Icons.badge_outlined,
                  tipoTeclado: TextInputType.number,
                  formateadores: [FilteringTextInputFormatter.digitsOnly],
                  maxLargo: 11,
                  error: _errorRuc,
                  habilitado: !_guardando && !_consultando,
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              // Trae razon social y direccion de SUNAT: escribirlo a mano en
              // el celular es donde mas se equivoca uno.
              SizedBox(
                width: 116,
                child: AppBoton(
                  texto: 'Buscar',
                  tam: BotonTam.lg,
                  icono: Icons.search,
                  cargando: _consultando,
                  onPressed: _guardando ? null : _consultarRuc,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _razonSocial,
            etiqueta: 'Razón social',
            icono: Icons.apartment_outlined,
            error: _errorRazon,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _comercial,
            etiqueta: 'Nombre comercial',
            icono: Icons.storefront_outlined,
            error: _errorComercial,
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

          Row(
            children: [
              Expanded(
                child: AppCampo(
                  controlador: _departamento,
                  etiqueta: 'Departamento',
                  opcional: true,
                  habilitado: !_guardando,
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppCampo(
                  controlador: _provincia,
                  etiqueta: 'Provincia',
                  opcional: true,
                  habilitado: !_guardando,
                ),
              ),
            ],
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

          AppCampo(
            controlador: _email,
            etiqueta: 'Correo',
            icono: Icons.mail_outline,
            opcional: true,
            tipoTeclado: TextInputType.emailAddress,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _sitioWeb,
            etiqueta: 'Sitio web',
            icono: Icons.language_outlined,
            opcional: true,
            tipoTeclado: TextInputType.url,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),

          AppCampo(
            controlador: _representante,
            etiqueta: 'Representante legal',
            icono: Icons.person_outline,
            opcional: true,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio6),

          AppBoton(
            texto: _esNuevo ? 'Crear empresa' : 'Guardar cambios',
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
