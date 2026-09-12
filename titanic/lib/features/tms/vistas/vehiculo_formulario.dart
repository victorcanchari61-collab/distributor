import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/flota.dart';
import '../estado/tms_controlador.dart';
import 'campo_foto.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Alta y edicion de un vehiculo.
class VehiculoFormulario extends ConsumerStatefulWidget {
  const VehiculoFormulario({super.key, this.vehiculo});

  /// Null cuando es un vehiculo nuevo.
  final Vehiculo? vehiculo;

  @override
  ConsumerState<VehiculoFormulario> createState() => _VehiculoFormularioState();
}

/// Escribe un decimal sin el ".0" que sobra al editar: la capacidad se teclea
/// como "1200", no como "1200.0".
String _textoDecimal(double? valor) {
  if (valor == null) return '';
  return valor == valor.roundToDouble() ? valor.round().toString() : valor.toString();
}

class _VehiculoFormularioState extends ConsumerState<VehiculoFormulario> {
  late final _placa = TextEditingController(text: widget.vehiculo?.placa ?? '');
  late final _marca = TextEditingController(text: widget.vehiculo?.marca ?? '');
  late final _modelo = TextEditingController(text: widget.vehiculo?.modelo ?? '');
  late final _anio = TextEditingController(text: widget.vehiculo?.anio?.toString() ?? '');
  late final _color = TextEditingController(text: widget.vehiculo?.color ?? '');
  late final _capacidad = TextEditingController(
    text: _textoDecimal(widget.vehiculo?.capacidadKg),
  );
  late final _soatNumero = TextEditingController(text: widget.vehiculo?.soatNumero ?? '');
  late final _observacion = TextEditingController(text: widget.vehiculo?.observacion ?? '');

  late int? _tipoVehiculoId = widget.vehiculo?.tipoVehiculoId;
  late int? _conductorId = widget.vehiculo?.conductorId;

  late DateTime? _soatVence = widget.vehiculo?.soatVence;
  late DateTime? _revisionVence = widget.vehiculo?.revisionTecnicaVence;
  late DateTime? _permisoVence = widget.vehiculo?.permisoCirculacionVence;

  late String? _foto = widget.vehiculo?.foto;
  late bool _activo = widget.vehiculo?.activo ?? true;

  bool _guardando = false;
  bool _subiendoFoto = false;
  String? _error;
  String? _errorPlaca;
  String? _errorTipo;

  bool get _esNuevo => widget.vehiculo == null;

  @override
  void dispose() {
    for (final c in [
      _placa,
      _marca,
      _modelo,
      _anio,
      _color,
      _capacidad,
      _soatNumero,
      _observacion,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _errorPlaca = _placa.text.trim().isEmpty ? 'Ingresa la placa.' : null;
      _errorTipo = _tipoVehiculoId == null ? 'Elige el tipo de vehículo.' : null;
    });
    return _errorPlaca == null && _errorTipo == null;
  }

  String? _texto(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
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

    final cuerpo = <String, dynamic>{
      // La placa va tal cual: el backend la normaliza a mayusculas y es el
      // que decide si choca con otra.
      'placa': _placa.text.trim(),
      'tipoVehiculoId': _tipoVehiculoId,
      'marca': _texto(_marca),
      'modelo': _texto(_modelo),
      'anio': int.tryParse(_anio.text.trim()),
      'color': _texto(_color),
      'capacidadKg': double.tryParse(_capacidad.text.trim().replaceAll(',', '.')),
      'soatNumero': _texto(_soatNumero),
      'soatVence': _soatVence?.toIso8601String(),
      'revisionTecnicaVence': _revisionVence?.toIso8601String(),
      'permisoCirculacionVence': _permisoVence?.toIso8601String(),
      'foto': _foto,
      'conductorId': _conductorId,
      'observacion': _texto(_observacion),
      'activo': _activo,
    };

    try {
      await ref.read(vehiculosProvider.notifier).guardar(
        id: widget.vehiculo?.id,
        cuerpo: cuerpo,
      );

      navegador.pop();
      mensajero.mostrar(_esNuevo ? 'Vehículo creado' : 'Vehículo actualizado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipos = ref.watch(tiposVehiculoActivosProvider);
    final conductores = ref.watch(conductoresActivosProvider);
    final sinTipos = tipos.isEmpty;

    // Su propio Scaffold: no cuelga de AppShell, asi que declara aqui el
    // acento del modulo. Sin esto los componentes compartidos y las hojas que
    // se abran desde dentro saldrian con el azul de marca.
    return Acento.modulo(
      'tms',
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(
            _esNuevo ? 'Nuevo vehículo' : 'Editar vehículo',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Dimen.espacio4),
          children: [
            if (_error != null) ...[AppAlerta(_error!), const SizedBox(height: Dimen.espacio4)],

            AppCampo(
              controlador: _placa,
              etiqueta: 'Placa',
              pista: 'ABC-123',
              icono: Icons.confirmation_number_outlined,
              maxLargo: 15,
              error: _errorPlaca,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int>(
              valor: _tipoVehiculoId,
              etiqueta: 'Tipo de vehículo',
              icono: Icons.category_outlined,
              error: _errorTipo,
              habilitado: !_guardando,
              opciones: [for (final t in tipos) Opcion(t.id, t.nombre)],
              onCambio: (v) => setState(() {
                _tipoVehiculoId = v;
                _errorTipo = null;
              }),
            ),
            if (sinTipos) ...[
              const SizedBox(height: Dimen.espacio2),
              const AppAlerta(
                'No hay tipos de vehículo activos. Crea uno en "Tipos de vehículo", '
                'en la pantalla de Flota, antes de dar de alta un vehículo.',
              ),
            ],
            const SizedBox(height: Dimen.espacio4),

            AppSelector<int?>(
              valor: _conductorId,
              etiqueta: 'Conductor habitual',
              icono: Icons.person_outline,
              habilitado: !_guardando,
              opciones: [
                const Opcion(null, 'Sin asignar'),
                for (final c in conductores) Opcion(c.id, c.nombre),
              ],
              onCambio: (v) => setState(() => _conductorId = v),
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _marca,
              etiqueta: 'Marca',
              icono: Icons.badge_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _modelo,
              etiqueta: 'Modelo',
              icono: Icons.directions_car_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _anio,
              etiqueta: 'Año',
              icono: Icons.calendar_today_outlined,
              opcional: true,
              tipoTeclado: TextInputType.number,
              formateadores: [FilteringTextInputFormatter.digitsOnly],
              maxLargo: 4,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _color,
              etiqueta: 'Color',
              icono: Icons.palette_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _capacidad,
              etiqueta: 'Capacidad en kg',
              icono: Icons.scale_outlined,
              opcional: true,
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _soatNumero,
              etiqueta: 'Número de SOAT',
              icono: Icons.description_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            CampoFecha(
              etiqueta: 'Vence el SOAT',
              valor: _soatVence,
              onCambio: (v) => setState(() => _soatVence = v),
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            CampoFecha(
              etiqueta: 'Vence la revisión técnica',
              valor: _revisionVence,
              onCambio: (v) => setState(() => _revisionVence = v),
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            CampoFecha(
              etiqueta: 'Vence el permiso de circulación',
              valor: _permisoVence,
              onCambio: (v) => setState(() => _permisoVence = v),
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            CampoFoto(
              ruta: _foto,
              carpeta: 'vehiculos',
              onCambio: (r) => setState(() => _foto = r),
              onSubiendo: (s) => setState(() => _subiendoFoto = s),
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),

            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 300,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio3),

            CheckboxListTile(
              value: _activo,
              onChanged: _guardando ? null : (v) => setState(() => _activo = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Activo',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colores.tinta),
              ),
              subtitle: const Text(
                'Un vehículo inactivo deja de ofrecerse para repartos, pero conserva su '
                'historial.',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
            const SizedBox(height: Dimen.espacio6),

            AppBoton(
              texto: _esNuevo ? 'Crear vehículo' : 'Guardar cambios',
              cargando: _guardando,
              // Mientras sube la foto no se guarda: se iria con la ruta vieja
              // o sin ninguna, y quien pulsa creeria que la mando.
              onPressed: _subiendoFoto || sinTipos ? null : _guardar,
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
