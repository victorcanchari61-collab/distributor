import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/empleado.dart';
import '../estado/maestros_controlador.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Alta y edicion de un empleado.
class EmpleadoFormulario extends ConsumerStatefulWidget {
  const EmpleadoFormulario({super.key, this.empleado});

  /// Null cuando es un empleado nuevo.
  final Empleado? empleado;

  @override
  ConsumerState<EmpleadoFormulario> createState() => _EmpleadoFormularioState();
}

class _EmpleadoFormularioState extends ConsumerState<EmpleadoFormulario> {
  late final _documento = TextEditingController(
    text: widget.empleado?.documento ?? '',
  );
  late final _nombres = TextEditingController(
    text: widget.empleado?.nombres ?? '',
  );
  late final _apellidos = TextEditingController(
    text: widget.empleado?.apellidos ?? '',
  );
  late final _cargo = TextEditingController(text: widget.empleado?.cargo ?? '');
  late final _area = TextEditingController(text: widget.empleado?.area ?? '');
  late final _telefono = TextEditingController(
    text: widget.empleado?.telefono ?? '',
  );
  late final _email = TextEditingController(text: widget.empleado?.email ?? '');
  late final _direccion = TextEditingController(
    text: widget.empleado?.direccion ?? '',
  );
  late final _observacion = TextEditingController(
    text: widget.empleado?.observacion ?? '',
  );

  // Un empleado es una persona: DNI, o un codigo interno si es extranjero sin
  // DNI. RUC no, a diferencia de clientes y proveedores.
  late String _tipoDoc = widget.empleado?.tipoDoc.isNotEmpty == true
      ? widget.empleado!.tipoDoc
      : 'DNI';

  late DateTime? _fechaIngreso = widget.empleado?.fechaIngreso;
  late DateTime? _fechaCese = widget.empleado?.fechaCese;

  bool _guardando = false;
  String? _error;
  String? _errorDocumento;
  String? _errorNombres;
  String? _errorApellidos;

  bool get _esNuevo => widget.empleado == null;

  @override
  void dispose() {
    for (final c in [
      _documento,
      _nombres,
      _apellidos,
      _cargo,
      _area,
      _telefono,
      _email,
      _direccion,
      _observacion,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Largo que exige cada tipo, igual que en el panel web.
  ({int min, int max}) get _largo =>
      _tipoDoc == 'DNI' ? (min: 8, max: 8) : (min: 3, max: 15);

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

      _errorNombres = _nombres.text.trim().isEmpty
          ? 'Ingresa los nombres.'
          : null;
      _errorApellidos = _apellidos.text.trim().isEmpty
          ? 'Ingresa los apellidos.'
          : null;

      // El backend tambien lo rechaza, pero decirlo aqui evita el viaje y deja
      // el aviso junto a las fechas que hay que corregir.
      _error =
          _fechaIngreso != null &&
              _fechaCese != null &&
              _fechaCese!.isBefore(_fechaIngreso!)
          ? 'La fecha de cese no puede ser anterior a la de ingreso.'
          : null;
    });

    return _errorDocumento == null &&
        _errorNombres == null &&
        _errorApellidos == null &&
        _error == null;
  }

  Future<void> _elegirFecha({required bool ingreso}) async {
    final actual = ingreso ? _fechaIngreso : _fechaCese;
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      // Cuarenta años atras: una ficha puede ser de alguien que entro hace
      // mucho y se esta registrando recien ahora.
      firstDate: DateTime(DateTime.now().year - 40),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida == null) return;

    setState(() {
      if (ingreso) {
        _fechaIngreso = elegida;
      } else {
        _fechaCese = elegida;
      }
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    // Se arma con el modelo y no a mano: asi el cuerpo que se envia y lo que
    // se lee de la respuesta salen del mismo sitio.
    final cuerpo = Empleado(
      id: widget.empleado?.id ?? 0,
      documento: _documento.text.trim(),
      tipoDoc: _tipoDoc,
      nombres: _nombres.text.trim(),
      apellidos: _apellidos.text.trim(),
      telefono: _telefono.text.trim(),
      email: _email.text.trim(),
      direccion: _direccion.text.trim(),
      cargo: _cargo.text.trim(),
      area: _area.text.trim(),
      fechaIngreso: _fechaIngreso,
      fechaCese: _fechaCese,
      observacion: _observacion.text.trim(),
      activo: widget.empleado?.activo ?? true,
    ).aJson();

    if (!_esNuevo) cuerpo['activo'] = widget.empleado!.activo;

    try {
      await ref
          .read(empleadosProvider.notifier)
          .guardar(id: widget.empleado?.id, cuerpo: cuerpo);

      navegador.pop();
      mensajero.mostrar(
        _esNuevo ? 'Empleado registrado' : 'Empleado actualizado',
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
      'maestros',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo empleado' : 'Editar empleado',
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
              controlador: _nombres,
              etiqueta: 'Nombres',
              icono: Icons.person_outline,
              pista: 'Ej. Juan Carlos',
              error: _errorNombres,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _apellidos,
              etiqueta: 'Apellidos',
              icono: Icons.person_outline,
              pista: 'Ej. Quispe Mamani',
              error: _errorApellidos,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            Row(
              children: [
                Expanded(
                  child: AppCampo(
                    controlador: _cargo,
                    etiqueta: 'Cargo',
                    icono: Icons.work_outline,
                    pista: 'Ej. Repartidor',
                    opcional: true,
                    habilitado: !_guardando,
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: AppCampo(
                    controlador: _area,
                    etiqueta: 'Área',
                    icono: Icons.apartment_outlined,
                    pista: 'Ej. Reparto',
                    opcional: true,
                    habilitado: !_guardando,
                  ),
                ),
              ],
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
              controlador: _direccion,
              etiqueta: 'Dirección',
              icono: Icons.place_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            _CampoFecha(
              etiqueta: 'Fecha de ingreso',
              valor: _fechaIngreso,
              vacio: 'Sin definir',
              habilitado: !_guardando,
              onTocar: () => _elegirFecha(ingreso: true),
              onBorrar: () => setState(() => _fechaIngreso = null),
            ),
            const SizedBox(height: Dimen.espacio4),

            _CampoFecha(
              etiqueta: 'Fecha de cese',
              valor: _fechaCese,
              vacio: 'Solo si ya dejó de trabajar',
              habilitado: !_guardando,
              onTocar: () => _elegirFecha(ingreso: false),
              onBorrar: () => setState(() => _fechaCese = null),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBotonesFormulario(
              onCancelar: () => Navigator.of(context).pop(),
              onGuardar: _guardar,
              textoGuardar: _esNuevo ? 'Registrar' : 'Guardar',
              cargando: _guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
          ],
        ),
      ),
    );
  }
}

/// Campo de fecha opcional: se toca para elegirla y tiene aspa para quitarla.
///
/// El aspa no es un adorno: una fecha de cese puesta por error dejaria a la
/// persona marcada como que ya no trabaja, y sin forma de deshacerlo el
/// formulario obligaria a inventar una fecha.
class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.valor,
    required this.vacio,
    required this.habilitado,
    required this.onTocar,
    required this.onBorrar,
  });

  final String etiqueta;
  final DateTime? valor;

  /// Que se lee cuando no hay fecha.
  final String vacio;

  final bool habilitado;
  final VoidCallback onTocar;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: habilitado ? onTocar : null,
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
      child: InputDecorator(
        decoration: InputDecoration(
          label: Text.rich(
            TextSpan(
              text: etiqueta,
              children: const [
                TextSpan(
                  text: ' (opcional)',
                  style: TextStyle(color: Colores.tintaTenue),
                ),
              ],
            ),
          ),
          prefixIcon: const Icon(
            Icons.event_outlined,
            size: 19,
            color: Colores.tintaTenue,
          ),
          suffixIcon: valor == null || !habilitado
              ? null
              : IconButton(
                  onPressed: onBorrar,
                  tooltip: 'Quitar la fecha',
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colores.tintaTenue,
                  ),
                ),
          constraints: const BoxConstraints(minHeight: Dimen.campoLg),
        ),
        child: Text(
          valor == null ? vacio : _fechaTexto(valor!),
          style: TextStyle(
            fontSize: 15,
            color: valor == null ? Colores.tintaTenue : Colores.tinta,
          ),
        ),
      ),
    );
  }
}

String _fechaTexto(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
