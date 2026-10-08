import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/fechas.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/asistencia.dart';
import '../estado/asistencia_controlador.dart';

String _dmy(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// Si esa persona trabajaba ese dia: ya habia entrado y todavia no cesaba.
/// Desactivado sin fecha de cese no cuenta (el servidor tampoco lo deja marcar).
bool trabajabaEse(EmpleadoAsistencia e, DateTime dia) {
  final ingreso = e.fechaIngreso;
  final cese = e.fechaCese;
  return (e.activo || cese != null) &&
      (ingreso == null || !DateUtils.dateOnly(ingreso).isAfter(dia)) &&
      (cese == null || !DateUtils.dateOnly(cese).isBefore(dia));
}

/// El mes en una grilla: cuantos se marcaron de los que trabajaban cada dia.
///
/// Los domingos y feriados no se esperan (no se pagan ni descuentan), asi que
/// no se pintan como incompletos. Tocar un dia abre su pase de lista.
class CalendarioAsistencia extends ConsumerWidget {
  const CalendarioAsistencia({super.key, required this.onDia});

  /// Al tocar un dia ya pasado (o hoy). Null si no se puede pasar lista.
  final ValueChanged<DateTime>? onDia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAsistenciaProvider);
    final marcas =
        (ref.watch(asistenciasProvider).valueOrNull ?? const <Asistencia>[])
            .where((m) => !m.anulado);
    final empleados =
        ref.watch(empleadosAsistenciaProvider).valueOrNull ??
        const <EmpleadoAsistencia>[];
    final feriados = {
      for (final f
          in ref.watch(feriadosProvider).valueOrNull ?? const <Feriado>[])
        DateUtils.dateOnly(f.fecha): f.nombre,
    };

    // Quien tiene marca cada dia, sin contar dos veces a nadie.
    final marcadosPorDia = <DateTime, Set<int>>{};
    for (final m in marcas) {
      marcadosPorDia
          .putIfAbsent(DateUtils.dateOnly(m.fecha), () => {})
          .add(m.empleadoId);
    }

    final hoy = DateUtils.dateOnly(DateTime.now());
    final primero = DateTime(mes.year, mes.month);
    final dias = DateUtils.getDaysInMonth(mes.year, mes.month);
    final huecos = primero.weekday - DateTime.monday;
    final acento = Acento.de(context);

    return Container(
      padding: const EdgeInsets.all(Dimen.espacio2),
      decoration: BoxDecoration(
        color: Colores.superficie,
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
        border: Border.all(color: Colores.linea),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colores.tintaSuave,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.95,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            children: [
              for (var i = 0; i < huecos; i++) const SizedBox.shrink(),
              for (var n = 1; n <= dias; n++)
                _Dia(
                  dia: DateTime(mes.year, mes.month, n),
                  hoy: hoy,
                  feriado: feriados[DateTime(mes.year, mes.month, n)],
                  marcados:
                      marcadosPorDia[DateTime(mes.year, mes.month, n)]
                          ?.length ??
                      0,
                  esperados: empleados
                      .where(
                        (e) =>
                            trabajabaEse(e, DateTime(mes.year, mes.month, n)),
                      )
                      .length,
                  acento: acento,
                  onTap: onDia,
                ),
            ],
          ),
          const SizedBox(height: Dimen.espacio1),
          const Text(
            'Marcados / los que trabajaban. Toca un día para pasar lista.',
            style: TextStyle(fontSize: 11, color: Colores.tintaSuave),
          ),
        ],
      ),
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({
    required this.dia,
    required this.hoy,
    required this.feriado,
    required this.marcados,
    required this.esperados,
    required this.acento,
    required this.onTap,
  });

  final DateTime dia;
  final DateTime hoy;
  final String? feriado;
  final int marcados;
  final int esperados;
  final Color acento;
  final ValueChanged<DateTime>? onTap;

  @override
  Widget build(BuildContext context) {
    final futuro = dia.isAfter(hoy);
    final domingo = dia.weekday == DateTime.sunday;
    // Solo los dias que se pagan de lunes a sabado se esperan completos.
    final seEspera = !futuro && !domingo && feriado == null && esperados > 0;

    final Color? color = !seEspera
        ? null
        : marcados >= esperados
        ? Colores.exito
        : marcados == 0
        ? Colores.peligro
        : Colores.advertencia;

    final texto = feriado != null
        ? 'Feriado'
        : futuro || esperados == 0
        ? ''
        : '$marcados/$esperados';

    return Material(
      color: feriado != null
          ? acento.withValues(alpha: 0.08)
          : color?.withValues(alpha: 0.1) ?? Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: futuro || onTap == null ? null : () => onTap!(dia),
        child: Container(
          decoration: dia == hoy
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: acento, width: 1.5),
                )
              : null,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dia.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: futuro || domingo ? Colores.tintaTenue : Colores.tinta,
                ),
              ),
              if (texto.isNotEmpty)
                Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: feriado != null ? acento : color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Los feriados: los dias que no se trabajan y no se descuentan. Quien
/// trabaja uno cobra ese dia doble en la planilla.
Future<void> abrirFeriados(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colores.superficie,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimen.radioPanel),
      ),
    ),
    // La hoja cuelga del Navigator y no hereda el acento del modulo.
    builder: (context) => Acento.modulo('rrhh', (_) => const _HojaFeriados()),
  );
}

class _HojaFeriados extends ConsumerStatefulWidget {
  const _HojaFeriados();

  @override
  ConsumerState<_HojaFeriados> createState() => _HojaFeriadosState();
}

class _HojaFeriadosState extends ConsumerState<_HojaFeriados> {
  /// El que se edita; null con el formulario abierto es uno nuevo.
  Feriado? _editando;
  bool _formulario = false;
  DateTime? _fecha;
  final _nombre = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _abrir([Feriado? f]) => setState(() {
    _editando = f;
    _formulario = true;
    _fecha = f?.fecha;
    _nombre.text = f?.nombre ?? '';
    _error = null;
  });

  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(hoy.year - 2),
      lastDate: DateTime(hoy.year + 2, 12, 31),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_fecha == null || _nombre.text.trim().isEmpty) {
      setState(() => _error = 'Indica la fecha y el nombre del feriado.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final mensajero = Aviso.de(context);
    final api = ref.read(rrhhApiProvider);

    try {
      final cuerpo = {'fecha': diaIso(_fecha!), 'nombre': _nombre.text.trim()};
      if (_editando == null) {
        await api.crearFeriado(cuerpo);
      } else {
        await api.actualizarFeriado(_editando!.id, cuerpo);
      }
      ref.invalidate(feriadosProvider);
      mensajero.mostrar(
        _editando == null ? 'Feriado agregado' : 'Feriado actualizado',
      );
      setState(() {
        _guardando = false;
        _formulario = false;
      });
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  Future<void> _eliminar(Feriado f) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar feriado',
      mensaje:
          '${f.nombre} (${_dmy(f.fecha)}). Ese día vuelve a ser laborable: '
          'quien no tenga marca, se pagará como trabajado o se le descontará si faltó.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(rrhhApiProvider).eliminarFeriado(f.id);
      ref.invalidate(feriadosProvider);
      mensajero.mostrar('Feriado eliminado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feriados = ref.watch(feriadosProvider);
    final puedeCrear = puede(ref, 'rrhh.asistencia', Accion.crear);
    final puedeEditar = puede(ref, 'rrhh.asistencia', Accion.editar);
    final puedeEliminar = puede(ref, 'rrhh.asistencia', Accion.eliminar);
    final acento = Acento.de(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Dimen.espacio4,
        0,
        Dimen.espacio4,
        MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Feriados',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Dimen.espacio1),
            const Text(
              'No se trabajan y no se descuentan. Quien trabaja uno cobra ese día doble.',
              style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),
            if (_formulario) ...[
              if (_error != null) ...[
                AppAlerta(_error!),
                const SizedBox(height: Dimen.espacio3),
              ],
              InkWell(
                onTap: _guardando ? null : _elegirFecha,
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    prefixIcon: Icon(
                      Icons.event_outlined,
                      size: 19,
                      color: Colores.tintaTenue,
                    ),
                  ),
                  child: Text(_fecha == null ? 'Elegir' : _dmy(_fecha!)),
                ),
              ),
              const SizedBox(height: Dimen.espacio4),
              AppCampo(
                controlador: _nombre,
                etiqueta: 'Nombre',
                icono: Icons.flag_outlined,
                pista: 'Fiestas Patrias',
                maxLargo: 100,
                habilitado: !_guardando,
              ),
              const SizedBox(height: Dimen.espacio4),
              Row(
                children: [
                  Expanded(
                    child: AppBoton(
                      texto: 'Cancelar',
                      variante: BotonVariante.secundario,
                      onPressed: _guardando
                          ? null
                          : () => setState(() => _formulario = false),
                    ),
                  ),
                  const SizedBox(width: Dimen.espacio2),
                  Expanded(
                    child: AppBoton(
                      texto: _editando == null ? 'Agregar' : 'Guardar',
                      cargando: _guardando,
                      onPressed: _guardar,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimen.espacio4),
            ] else if (puedeCrear) ...[
              AppBoton(
                texto: 'Agregar feriado',
                icono: Icons.add,
                variante: BotonVariante.secundario,
                onPressed: () => _abrir(),
              ),
              const SizedBox(height: Dimen.espacio3),
            ],
            feriados.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar los feriados.',
              ),
              data: (lista) {
                if (lista.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: Dimen.espacio3),
                    child: Text(
                      'Todavía no hay feriados registrados.',
                      style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                    ),
                  );
                }
                // Los que vienen primero, y los pasados al final.
                final hoy = DateUtils.dateOnly(DateTime.now());
                final ordenados = [...lista]
                  ..sort((a, b) {
                    final pa = a.fecha.isBefore(hoy);
                    final pb = b.fecha.isBefore(hoy);
                    if (pa != pb) return pa ? 1 : -1;
                    return pa
                        ? b.fecha.compareTo(a.fecha)
                        : a.fecha.compareTo(b.fecha);
                  });
                return Column(
                  children: [
                    for (final f in ordenados)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.flag_outlined,
                          color: f.fecha.isBefore(hoy)
                              ? Colores.tintaTenue
                              : acento,
                        ),
                        title: Text(
                          f.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(_dmy(f.fecha)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (puedeEditar)
                              IconButton(
                                tooltip: 'Editar',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _abrir(f),
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: acento,
                                ),
                              ),
                            if (puedeEliminar)
                              IconButton(
                                tooltip: 'Eliminar',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _eliminar(f),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colores.advertencia,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
