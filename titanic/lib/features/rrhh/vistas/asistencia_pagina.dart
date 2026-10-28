import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_pdf.dart';
import '../../../compartido/fechas.dart';
import '../../../compartido/exportar_csv.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/asistencia.dart';
import '../estado/asistencia_controlador.dart';
import 'asistencia_calendario.dart';
import 'pase_lista_pagina.dart';

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', //
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// El tono de cada estado, el mismo en la tarjeta, el filtro y el pase de lista.
EtiquetaTono tonoAsistencia(String estado) => switch (estado) {
  EstadoAsistencia.presente => EtiquetaTono.exito,
  EstadoAsistencia.tardanza => EtiquetaTono.aviso,
  EstadoAsistencia.falta => EtiquetaTono.peligro,
  _ => EtiquetaTono.modulo,
};

/// Asistencia del personal: quien vino, quien falto, quien llego tarde.
///
/// Se marca con el pase de lista de un dia —todos juntos— y aqui queda el
/// registro del mes, donde se corrige o se anula una marca puesta por error.
/// Es lo mismo que el panel web, en dos pestañas: el calendario del mes
/// (marcados de los que trabajaban cada dia; tocar uno abre su pase de lista,
/// y ahi mismo los feriados) y el registro de las marcas. Pasar lista va en el
/// boton flotante, a la vista en las dos pestañas.
class AsistenciaPagina extends ConsumerWidget {
  const AsistenciaPagina({super.key});

  static const ruta = '/rrhh/asistencia';

  /// El reporte del mes que se mira, con un solo empleado si hay uno filtrado.
  static String _rutaReporte(WidgetRef ref) {
    final r = rangoDelMes(ref.watch(mesAsistenciaProvider));
    final empleado = ref.watch(empleadoAsistenciaFiltroProvider);
    return '/asistencia/pdf?desde=${diaIso(r.desde)}&hasta=${diaIso(r.hasta)}'
        '${empleado == null ? '' : '&empleadoId=$empleado'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final resumen = ref.watch(resumenAsistenciaProvider).valueOrNull;
    final mes = ref.watch(mesAsistenciaProvider);
    final pestana = ref.watch(pestanaAsistenciaProvider);
    final puedeCrear = puede(ref, 'rrhh.asistencia', Accion.crear);

    final pestanas = AppPestanas<PestanaAsistencia>(
      activa: pestana,
      onCambio: (p) => ref.read(pestanaAsistenciaProvider.notifier).state = p,
      pestanas: [
        const Pestana(
          PestanaAsistencia.calendario,
          'Calendario',
          icono: Icons.calendar_month_outlined,
        ),
        Pestana(
          PestanaAsistencia.registro,
          'Registro',
          icono: Icons.table_rows_outlined,
          // Todas las marcas del mes, como la web: tambien las anuladas.
          contador: ref.watch(asistenciasProvider).valueOrNull?.length,
        ),
      ],
    );

    final indicadores = [
      AppTarjetaDato(
        etiqueta: 'Presentes',
        valor: '${resumen?.presentes ?? 0}',
        icono: Icons.how_to_reg_outlined,
        color: color,
      ),
      AppTarjetaDato(
        etiqueta: 'Tardanzas',
        valor: '${resumen?.tardanzas ?? 0}',
        icono: Icons.schedule,
        tono: DatoTono.aviso,
      ),
      AppTarjetaDato(
        etiqueta: 'Faltas',
        valor: '${resumen?.faltas ?? 0}',
        icono: Icons.person_off_outlined,
        tono: DatoTono.peligro,
      ),
      AppTarjetaDato(
        etiqueta: 'Permisos',
        valor: '${resumen?.permisos ?? 0}',
        icono: Icons.event_note_outlined,
        tono: DatoTono.neutral,
      ),
    ];

    void cambiarMes(DateTime m) =>
        ref.read(mesAsistenciaProvider.notifier).state = m;
    final onPaseLista = puedeCrear ? () => _abrirPaseLista(context, ref) : null;

    if (pestana == PestanaAsistencia.calendario) {
      return _PestanaCalendario(
        color: color,
        pestanas: pestanas,
        indicadores: indicadores,
        barraMes: _BarraMes(
          mes: mes,
          onMes: cambiarMes,
          onFeriados: () => abrirFeriados(context),
        ),
        onPaseLista: onPaseLista,
        // Tocar un dia del calendario abre su pase de lista.
        onDia: puedeCrear ? (dia) => _pasarLista(context, ref, dia) : null,
        onRecargar: () => _recargar(ref),
      );
    }

    return AppListaPagina<Asistencia>(
      titulo: 'Asistencia',
      ruta: ruta,
      pestanas: pestanas,
      estado: ref.watch(asistenciasProvider),
      visibles: ref.watch(asistenciasFiltradasProvider),
      busqueda: ref.watch(busquedaAsistenciaProvider),
      onBuscar: (t) => ref.read(busquedaAsistenciaProvider.notifier).state = t,
      pistaBusqueda: 'Buscar empleado',
      onRecargar: () => _recargar(ref),
      acciones: [
        if (puede(ref, 'rrhh.asistencia', Accion.exportar))
          accionReportePdf(
            context,
            ruta: _rutaReporte(ref),
            nombre: 'asistencia.pdf',
          ),
        if (puede(ref, 'rrhh.asistencia', Accion.exportar))
          accionExportar<Asistencia>(
            context,
            nombre: 'asistencia',
            filas: () => ref.read(asistenciasFiltradasProvider),
            encabezados: const [
              'Fecha',
              'Empleado',
              'Cargo',
              'Estado',
              'Observación',
              'Usuario',
            ],
            fila: (a) => [
              diaIso(a.fecha),
              a.empleado,
              a.cargo,
              a.anulado ? 'Anulada' : a.estado,
              a.observacion,
              a.usuario,
            ],
          ),
      ],
      onNuevo: onPaseLista,
      textoNuevo: 'Pasar lista',
      iconoVacio: Icons.event_available_outlined,
      singular: 'marca',
      plural: 'marcas',
      tituloVacio: 'Sin marcas',
      detalleVacio: 'No hay asistencia registrada en este mes.',
      indicadores: indicadores,
      // El registro es el del mes: sin las flechas no se sabria de cual.
      encabezado: _BarraMes(mes: mes, onMes: cambiarMes),
      filtro: BotonFiltros(
        activos: ref.watch(filtrosAsistenciaActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, a) => _TarjetaAsistencia(
        asistencia: a,
        color: color,
        onEditar: !a.anulado && puede(ref, 'rrhh.asistencia', Accion.editar)
            ? () => _editar(context, ref, a)
            : null,
        onAnular: !a.anulado && puede(ref, 'rrhh.asistencia', Accion.anular)
            ? () => _anular(context, ref, a)
            : null,
      ),
    );
  }

  /// Vuelve a pedir el mes, y con el lo que pinta el calendario: quienes
  /// trabajaban cada dia y los feriados.
  Future<void> _recargar(WidgetRef ref) async {
    ref.invalidate(asistenciasProvider);
    ref.invalidate(resumenAsistenciaProvider);
    ref.invalidate(empleadosAsistenciaProvider);
    ref.invalidate(feriadosProvider);
    try {
      await ref.read(asistenciasProvider.future);
    } catch (_) {
      // El fallo ya se ve en la pantalla, con su botón de reintentar.
    }
  }

  Future<void> _abrirPaseLista(BuildContext context, WidgetRef ref) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final fecha = await showDatePicker(
      context: context,
      helpText: 'Día del pase de lista',
      initialDate: hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
    );
    if (fecha == null || !context.mounted) return;
    await _pasarLista(context, ref, fecha);
  }

  Future<void> _pasarLista(
    BuildContext context,
    WidgetRef ref,
    DateTime fecha,
  ) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PaseListaPagina(fecha: fecha)));
    // Se vuelve a pedir el mes de ese dia, que es donde quedo lo marcado.
    ref.read(mesAsistenciaProvider.notifier).state = DateTime(
      fecha.year,
      fecha.month,
    );
    ref.invalidate(asistenciasProvider);
    ref.invalidate(resumenAsistenciaProvider);
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosAsistenciaActivosProvider),
      onLimpiar: () {
        ref.read(empleadoAsistenciaFiltroProvider.notifier).state = null;
        ref.read(estadoAsistenciaFiltroProvider.notifier).state = null;
        ref.read(registroAsistenciaFiltroProvider.notifier).state =
            RegistroAsistencia.activas;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoAsistenciaFiltroProvider),
            opciones: [
              const OpcionFiltro<String?>(null, 'Todos'),
              for (final e in EstadoAsistencia.todos)
                OpcionFiltro<String?>(e, EstadoAsistencia.etiqueta(e)),
            ],
            onCambio: (v) =>
                ref.read(estadoAsistenciaFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final empleados = ref.watch(empleadosEnAsistenciaProvider);
            if (empleados.isEmpty) return const SizedBox.shrink();
            return GrupoFiltro<int?>(
              titulo: 'Empleado',
              valor: ref.watch(empleadoAsistenciaFiltroProvider),
              opciones: [
                const OpcionFiltro<int?>(null, 'Todos'),
                for (final e in empleados) OpcionFiltro<int?>(e.id, e.nombre),
              ],
              onCambio: (v) =>
                  ref.read(empleadoAsistenciaFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<RegistroAsistencia>(
            titulo: 'Registro',
            valor: ref.watch(registroAsistenciaFiltroProvider),
            opciones: const [
              OpcionFiltro(RegistroAsistencia.activas, 'Vigentes'),
              OpcionFiltro(RegistroAsistencia.anuladas, 'Anuladas'),
              OpcionFiltro(RegistroAsistencia.todas, 'Todas'),
            ],
            onCambio: (v) =>
                ref.read(registroAsistenciaFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, Asistencia a) {
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
      builder: (context) =>
          Acento.modulo('rrhh', (_) => _HojaEditar(asistencia: a)),
    );
  }

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    Asistencia a,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular marca',
      mensaje:
          '${a.empleado}, ${_fecha(a.fecha)}: ${EstadoAsistencia.etiqueta(a.estado)}. '
          'Deja de contar para la planilla, pero queda en el historial.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(rrhhApiProvider).anularAsistencia(a.id);
      ref.invalidate(asistenciasProvider);
      ref.invalidate(resumenAsistenciaProvider);
      mensajero.mostrar('Marca anulada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// El mes que se mira, con sus flechas. En el calendario lleva al lado los
/// feriados, en el mismo lugar que la web.
class _BarraMes extends StatelessWidget {
  const _BarraMes({required this.mes, required this.onMes, this.onFeriados});

  final DateTime mes;
  final ValueChanged<DateTime> onMes;
  final VoidCallback? onFeriados;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final esActual = mes.year == hoy.year && mes.month == hoy.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            onPressed: () => onMes(DateTime(mes.year, mes.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '${_meses[mes.month - 1][0].toUpperCase()}${_meses[mes.month - 1].substring(1)} ${mes.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            // No hay asistencia del futuro que mirar.
            onPressed: esActual
                ? null
                : () => onMes(DateTime(mes.year, mes.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          if (onFeriados != null) ...[
            const SizedBox(width: Dimen.espacio2),
            AppBoton(
              texto: 'Feriados',
              icono: Icons.flag_outlined,
              variante: BotonVariante.secundario,
              tam: BotonTam.sm,
              expandido: false,
              onPressed: onFeriados,
            ),
          ],
        ],
      ),
    );
  }
}

/// La pestaña del calendario: el mes en una grilla en lugar de la lista.
///
/// No es un listado, asi que no pasa por `AppListaPagina`; arma lo mismo que
/// ella —pestañas, indicadores y boton flotante— para que cambiar de pestaña
/// no mueva nada mas que el contenido.
class _PestanaCalendario extends ConsumerWidget {
  const _PestanaCalendario({
    required this.color,
    required this.pestanas,
    required this.indicadores,
    required this.barraMes,
    required this.onPaseLista,
    required this.onDia,
    required this.onRecargar,
  });

  final Color color;
  final Widget pestanas;
  final List<Widget> indicadores;
  final Widget barraMes;
  final VoidCallback? onPaseLista;
  final ValueChanged<DateTime>? onDia;
  final Future<void> Function() onRecargar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(asistenciasProvider);
    final error = estado.isLoading ? null : estado.error;

    return AppShell(
      titulo: 'Asistencia',
      subtitulo: resolverRuta(AsistenciaPagina.ruta).grupo?.titulo,
      acentado: color,
      rutaActual: AsistenciaPagina.ruta,
      accionFlotante: onPaseLista == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onPaseLista,
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Pasar lista'),
            ),
      child: Column(
        children: [
          pestanas,
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRecargar,
              child: ListView(
                // Hueco al final para que el boton flotante no tape la
                // ultima semana.
                padding: const EdgeInsets.only(
                  top: Dimen.espacio3,
                  bottom: Dimen.espacio6 * 2,
                ),
                children: [
                  AppFilaDatos(tarjetas: indicadores),
                  const SizedBox(height: Dimen.espacio3),
                  barraMes,
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimen.espacio4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (estado.isLoading && !estado.hasValue) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: Dimen.espacio2),
                        ],
                        if (error != null) ...[
                          AppAlerta(
                            error is ApiExcepcion
                                ? error.texto
                                : 'No pudimos cargar la asistencia del mes.',
                          ),
                          const SizedBox(height: Dimen.espacio2),
                        ],
                        CalendarioAsistencia(onDia: onDia),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAsistencia extends StatelessWidget {
  const _TarjetaAsistencia({
    required this.asistencia,
    required this.color,
    this.onEditar,
    this.onAnular,
  });

  final Asistencia asistencia;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Fecha', _fecha(asistencia.fecha)),
    CampoDetalle('Cargo', asistencia.cargo),
    CampoDetalle('Observación', asistencia.observacion),
    CampoDetalle('Registró', asistencia.usuario),
  ];

  Widget get _insignia => asistencia.anulado
      ? const AppEtiqueta('Anulada', tono: EtiquetaTono.neutral)
      : AppEtiqueta(
          EstadoAsistencia.etiqueta(asistencia.estado),
          tono: tonoAsistencia(asistencia.estado),
        );

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.person_outline,
      color: color,
      titulo: asistencia.empleado,
      insignia: _insignia,
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            tooltip: 'Corregir',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
        if (onAnular != null)
          IconButton(
            onPressed: onAnular,
            tooltip: 'Anular',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.block, size: 18, color: Colores.advertencia),
          ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.person_outline,
      color: color,
      titulo: asistencia.empleado,
      subtitulo: _fecha(asistencia.fecha),
      estado: _insignia,
      campos: _campos,
      acciones: [
        if (onAnular != null)
          AppBoton(
            texto: 'Anular',
            variante: BotonVariante.secundario,
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onAnular!();
            },
          ),
        if (onEditar != null)
          AppBoton(
            texto: 'Corregir',
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onEditar!();
            },
          ),
      ],
    );
  }
}

/// Corregir una marca: solo el estado y la observacion. Si el error fue de
/// empleado o de dia, se anula y se marca de nuevo.
class _HojaEditar extends ConsumerStatefulWidget {
  const _HojaEditar({required this.asistencia});

  final Asistencia asistencia;

  @override
  ConsumerState<_HojaEditar> createState() => _HojaEditarState();
}

class _HojaEditarState extends ConsumerState<_HojaEditar> {
  late String _estado = widget.asistencia.estado;
  late final _observacion = TextEditingController(
    text: widget.asistencia.observacion ?? '',
  );
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref
          .read(rrhhApiProvider)
          .editarAsistencia(
            widget.asistencia.id,
            estado: _estado,
            observacion: _observacion.text.trim().isEmpty
                ? null
                : _observacion.text.trim(),
          );
      ref.invalidate(asistenciasProvider);
      ref.invalidate(resumenAsistenciaProvider);
      navegador.pop();
      mensajero.mostrar('Marca corregida');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Dimen.espacio4,
        0,
        Dimen.espacio4,
        MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Corregir marca',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimen.espacio1),
          Text(
            '${widget.asistencia.empleado} · ${_fecha(widget.asistencia.fecha)}',
            style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio4),
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          AppSelector<String>(
            valor: _estado,
            etiqueta: 'Estado',
            icono: Icons.fact_check_outlined,
            habilitado: !_guardando,
            opciones: [
              for (final e in EstadoAsistencia.todos)
                Opcion(e, EstadoAsistencia.etiqueta(e)),
            ],
            onCambio: (v) => setState(() => _estado = v ?? _estado),
          ),
          const SizedBox(height: Dimen.espacio4),
          AppCampo(
            controlador: _observacion,
            etiqueta: 'Observación',
            icono: Icons.notes_outlined,
            opcional: true,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio5),
          AppBoton(texto: 'Guardar', cargando: _guardando, onPressed: _guardar),
        ],
      ),
    );
  }
}
