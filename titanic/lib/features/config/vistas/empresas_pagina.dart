import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';
import 'empresa_series_tab.dart';
import 'empresa_whatsapp_tab.dart';

enum _Seccion { datos, facturacion, series, whatsapp }

/// La empresa del sistema: una sola, así que no hay lista. Es un formulario con cuatro pestañas: sus datos (los que
/// salen en documentos y reportes), lo que SUNAT pide para facturar, las series de comprobantes con su numeración y el
/// envío por WhatsApp. Si todavía no existe, el mismo formulario la crea.
class EmpresasPagina extends ConsumerStatefulWidget {
  const EmpresasPagina({super.key});

  static const ruta = '/config/empresa';

  @override
  ConsumerState<EmpresasPagina> createState() => _EmpresasPaginaState();
}

class _EmpresasPaginaState extends ConsumerState<EmpresasPagina> {
  final _ruc = TextEditingController();
  final _razonSocial = TextEditingController();
  final _comercial = TextEditingController();
  final _direccion = TextEditingController();
  final _departamento = TextEditingController();
  final _provincia = TextEditingController();
  final _distrito = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _sitioWeb = TextEditingController();
  final _representante = TextEditingController();
  final _ubigeo = TextEditingController();
  final _usuarioSol = TextEditingController();
  final _claveSol = TextEditingController();
  final _plantilla = TextEditingController();

  bool _modoPrueba = true;
  bool _whatsAppAutomatico = false;

  _Seccion _seccion = _Seccion.datos;

  /// La empresa de la que se llenó el formulario: cuando llega una distinta (al guardar, o al subir el certificado),
  /// se vuelve a llenar.
  Empresa? _origen;
  bool _llenado = false;

  bool _guardando = false;
  bool _consultando = false;
  bool _subiendoCert = false;
  String? _error;
  String? _aviso;
  String? _errorRuc;
  String? _errorRazon;
  String? _errorComercial;

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
      _ubigeo,
      _usuarioSol,
      _claveSol,
      _plantilla,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _llenar(Empresa? e) {
    _origen = e;
    _llenado = true;
    _ruc.text = e?.ruc ?? '';
    _razonSocial.text = e?.razonSocial ?? '';
    _comercial.text = e?.nombreComercial ?? '';
    _direccion.text = e?.direccion ?? '';
    _departamento.text = e?.departamento ?? '';
    _provincia.text = e?.provincia ?? '';
    _distrito.text = e?.distrito ?? '';
    _telefono.text = e?.telefono ?? '';
    _email.text = e?.email ?? '';
    _sitioWeb.text = e?.sitioWeb ?? '';
    _representante.text = e?.representanteLegal ?? '';
    _ubigeo.text = e?.ubigeo ?? '';
    _usuarioSol.text = e?.usuarioSol ?? '';
    // La clave no vuelve del servidor: vacia deja la que esta.
    _claveSol.clear();
    _plantilla.text = e?.whatsAppPlantilla ?? '';
    _modoPrueba = e?.modoPrueba ?? true;
    _whatsAppAutomatico = e?.whatsAppAutomatico ?? false;
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
    final bien =
        _errorRuc == null && _errorRazon == null && _errorComercial == null;
    // Los datos obligatorios viven en la primera pestana: si fallan, se vuelve ahi.
    if (!bien) _seccion = _Seccion.datos;
    return bien;
  }

  Future<void> _guardar(Empresa? existente) async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    final mensajero = Aviso.de(context);

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
      'ubigeo': _ubigeo.text.trim(),
      'usuarioSol': _usuarioSol.text.trim(),
      'claveSol': _claveSol.text,
      'modoPrueba': _modoPrueba,
      'whatsAppAutomatico': _whatsAppAutomatico,
      'whatsAppPlantilla': _plantilla.text.trim(),
      // La empresa del sistema es una sola: siempre es la activa.
      'activa': true,
    };

    try {
      await ref
          .read(empresasProvider.notifier)
          .guardar(id: existente?.id, cuerpo: cuerpo);
      // El formulario se vuelve a llenar con lo que quedo guardado.
      _llenado = false;
      mensajero.mostrar(
        existente == null ? 'Empresa creada' : 'Empresa actualizada',
      );
    } on ApiExcepcion catch (e) {
      setState(() => _error = e.texto);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Lee el .pem del telefono y lo manda al backend, que lo revisa y lo guarda cifrado.
  Future<void> _subirCertificado(Empresa empresa) async {
    final mensajero = Aviso.de(context);
    try {
      final archivo = await FilePicker.pickFile();
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 512 * 1024) {
        mensajero.error('El certificado no debe pasar de 512 KB.');
        return;
      }

      setState(() => _subiendoCert = true);
      final r = await ref
          .read(configApiProvider)
          .subirCertificado(
            empresa.id,
            utf8.decode(bytes, allowMalformed: true),
          );
      final advertencias = (r['advertencias'] as List? ?? const []);
      final mensaje = r['mensaje'] as String? ?? 'Certificado guardado';
      if (advertencias.isEmpty) {
        mensajero.mostrar(mensaje);
      } else {
        mensajero.error(mensaje);
      }
      _llenado = false;
      await ref.read(empresasProvider.notifier).recargar();
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    } finally {
      if (mounted) setState(() => _subiendoCert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupo = resolverRuta(EmpresasPagina.ruta).grupo;
    final estado = ref.watch(empresasProvider);

    return AppShell(
      titulo: 'Empresa',
      subtitulo: grupo?.titulo,
      acentado: grupo?.color ?? Colores.marca,
      rutaActual: EmpresasPagina.ruta,
      child: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Dimen.espacio4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAlerta(
                  e is ApiExcepcion ? e.texto : 'No pudimos cargar la empresa.',
                ),
                const SizedBox(height: Dimen.espacio3),
                AppBoton(
                  texto: 'Reintentar',
                  expandido: false,
                  onPressed: () =>
                      ref.read(empresasProvider.notifier).recargar(),
                ),
              ],
            ),
          ),
        ),
        data: (lista) {
          // Hay una sola; si por herencia hubiera mas, se trabaja con la que opera el sistema.
          final empresa =
              lista.where((e) => e.activa).firstOrNull ?? lista.firstOrNull;
          if (!_llenado || _origen?.id != empresa?.id) _llenar(empresa);
          return _cuerpo(empresa);
        },
      ),
    );
  }

  Widget _cuerpo(Empresa? empresa) {
    final puedeEditar = empresa == null
        ? puede(ref, 'config.empresa', Accion.crear)
        : puede(ref, 'config.empresa', Accion.editar);

    return Column(
      children: [
        AppPestanas<_Seccion>(
          activa: _seccion,
          onCambio: (s) => setState(() => _seccion = s),
          pestanas: const [
            Pestana(_Seccion.datos, 'Datos'),
            Pestana(_Seccion.facturacion, 'Facturación'),
            Pestana(_Seccion.series, 'Series'),
            Pestana(_Seccion.whatsapp, 'WhatsApp'),
          ],
        ),
        Expanded(
          child: switch (_seccion) {
            _Seccion.datos => _datos(empresa, puedeEditar),
            _Seccion.facturacion => _facturacion(empresa, puedeEditar),
            _Seccion.series =>
              empresa == null
                  ? _creaPrimero('las series y su numeración')
                  : EmpresaSeriesTab(
                      empresaId: empresa.id,
                      puedeEditar: puede(ref, 'config.empresa', Accion.editar),
                    ),
            _Seccion.whatsapp => EmpresaWhatsAppTab(
              puedeEditar: puedeEditar,
              automatico: _whatsAppAutomatico,
              plantilla: _plantilla,
              onAutomatico: (v) => setState(() => _whatsAppAutomatico = v),
              onGuardar: () => _guardar(empresa),
              guardando: _guardando,
            ),
          },
        ),
      ],
    );
  }

  Widget _creaPrimero(String que) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Dimen.espacio5),
      child: Text(
        'Crea la empresa primero (pestaña Datos): $que se registran sobre ella.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
      ),
    ),
  );

  Widget _boton(Empresa? empresa, bool puedeEditar) => AppBoton(
    texto: empresa == null ? 'Crear empresa' : 'Guardar cambios',
    cargando: _guardando,
    sinPermiso: !puedeEditar,
    onPressed: () => _guardar(empresa),
  );

  Widget _datos(Empresa? empresa, bool puedeEditar) {
    final habilitado = puedeEditar && !_guardando;
    return ListView(
      padding: const EdgeInsets.all(Dimen.espacio4),
      children: [
        if (empresa == null) ...[
          const AppAlerta(
            'Todavía no se registró la empresa. Completa sus datos y créala para poder facturar.',
            tono: AlertaTono.aviso,
          ),
          const SizedBox(height: Dimen.espacio4),
        ],
        if (_error != null) ...[
          AppAlerta(_error!),
          const SizedBox(height: Dimen.espacio4),
        ],
        if (_aviso != null) ...[
          AppAlerta(_aviso!, tono: AlertaTono.aviso),
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
                habilitado: habilitado && !_consultando,
              ),
            ),
            const SizedBox(width: Dimen.espacio3),
            // Trae razon social y direccion de SUNAT: escribirlo a mano en el celular es donde mas se equivoca uno.
            SizedBox(
              width: 116,
              child: AppBoton(
                texto: 'Buscar',
                icono: Icons.search,
                cargando: _consultando,
                onPressed: habilitado ? _consultarRuc : null,
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
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _comercial,
          etiqueta: 'Nombre comercial',
          icono: Icons.storefront_outlined,
          error: _errorComercial,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _direccion,
          etiqueta: 'Dirección fiscal',
          icono: Icons.place_outlined,
          opcional: true,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        Row(
          children: [
            Expanded(
              child: AppCampo(
                controlador: _departamento,
                etiqueta: 'Departamento',
                opcional: true,
                habilitado: habilitado,
              ),
            ),
            const SizedBox(width: Dimen.espacio3),
            Expanded(
              child: AppCampo(
                controlador: _provincia,
                etiqueta: 'Provincia',
                opcional: true,
                habilitado: habilitado,
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
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _representante,
          etiqueta: 'Representante legal',
          icono: Icons.person_outline,
          opcional: true,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _telefono,
          etiqueta: 'Teléfono',
          icono: Icons.phone_outlined,
          opcional: true,
          tipoTeclado: TextInputType.phone,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _email,
          etiqueta: 'Correo',
          icono: Icons.mail_outline,
          opcional: true,
          tipoTeclado: TextInputType.emailAddress,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _sitioWeb,
          etiqueta: 'Sitio web',
          icono: Icons.language,
          opcional: true,
          pista: 'titanicd.pe',
          tipoTeclado: TextInputType.url,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio5),
        _boton(empresa, puedeEditar),
      ],
    );
  }

  Widget _facturacion(Empresa? empresa, bool puedeEditar) {
    final habilitado = puedeEditar && !_guardando;
    final vence = empresa?.certificadoVenceEl;

    return ListView(
      padding: const EdgeInsets.all(Dimen.espacio4),
      children: [
        if (_error != null) ...[
          AppAlerta(_error!),
          const SizedBox(height: Dimen.espacio4),
        ],
        const Text(
          'Con estos datos se firman y se envían a SUNAT las facturas, boletas y notas de esta empresa.',
          style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
        ),
        const SizedBox(height: Dimen.espacio4),
        AppSelector<bool>(
          valor: _modoPrueba,
          etiqueta: 'Modo',
          icono: Icons.science_outlined,
          habilitado: habilitado,
          opciones: const [
            Opcion(true, 'Pruebas (beta de SUNAT, sin validez tributaria)'),
            Opcion(false, 'Producción (comprobantes reales)'),
          ],
          onCambio: (v) => setState(() => _modoPrueba = v ?? true),
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _ubigeo,
          etiqueta: 'Ubigeo del domicilio fiscal',
          icono: Icons.pin_drop_outlined,
          pista: '150101',
          tipoTeclado: TextInputType.number,
          formateadores: [FilteringTextInputFormatter.digitsOnly],
          maxLargo: 6,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _usuarioSol,
          etiqueta: 'Usuario SOL',
          icono: Icons.person_outline,
          pista: _modoPrueba ? 'MODDATOS' : null,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        AppCampo(
          controlador: _claveSol,
          etiqueta: 'Clave SOL',
          icono: Icons.lock_outline,
          esPassword: true,
          pista: (empresa?.tieneClaveSol ?? false)
              ? 'Guardada · escribe otra para cambiarla'
              : _modoPrueba
              ? 'moddatos'
              : null,
          habilitado: habilitado,
        ),
        const SizedBox(height: Dimen.espacio4),
        // El certificado se sube a una empresa ya guardada.
        Container(
          padding: const EdgeInsets.all(Dimen.espacio3),
          decoration: BoxDecoration(
            border: Border.all(color: Colores.linea),
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Certificado digital (.pem)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Dimen.espacio1),
              Text(
                empresa == null
                    ? 'Crea la empresa primero: el certificado se guarda sobre ella.'
                    : vence != null
                    ? '${empresa.certificadoTitular ?? 'Certificado cargado'} · ${empresa.certificadoVencido ? 'venció' : 'vence'} el ${vence.day.toString().padLeft(2, '0')}/${vence.month.toString().padLeft(2, '0')}/${vence.year}'
                    : empresa.tieneCertificado
                    ? 'Certificado guardado.'
                    : 'Todavía no se subió ninguno. Sin certificado no se pueden firmar comprobantes.',
                style: TextStyle(
                  fontSize: 12,
                  color: (empresa?.certificadoVencido ?? false)
                      ? Colores.peligro
                      : Colores.tintaSuave,
                ),
              ),
              if (empresa != null) ...[
                const SizedBox(height: Dimen.espacio3),
                AppBoton(
                  texto: empresa.tieneCertificado
                      ? 'Reemplazar certificado'
                      : 'Subir certificado',
                  icono: Icons.upload_file,
                  variante: BotonVariante.secundario,
                  cargando: _subiendoCert,
                  sinPermiso: !puede(ref, 'config.empresa', Accion.editar),
                  onPressed: () => _subirCertificado(empresa),
                ),
              ],
            ],
          ),
        ),
        if (!_modoPrueba) ...[
          const SizedBox(height: Dimen.espacio3),
          const AppAlerta(
            'En producción cada comprobante que se emita es real y llega a SUNAT. Sube antes el certificado digital de esta empresa.',
            tono: AlertaTono.aviso,
          ),
        ],
        const SizedBox(height: Dimen.espacio5),
        _boton(empresa, puedeEditar),
      ],
    );
  }
}
