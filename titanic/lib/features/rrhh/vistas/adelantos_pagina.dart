import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/fechas.dart';
import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../finanzas/vistas/hojas_finanzas.dart'
    show TituloHoja, margenHoja, soloMonto, fechaCorta, fechaHora;
import '../datos/adelanto.dart';
import '../estado/adelantos_controlador.dart';
import '../estado/asistencia_controlador.dart';
import '../estado/planilla_controlador.dart';

EtiquetaTono _tonoEstado(String estado) => switch (estado) {
  EstadoAdelanto.pendiente => EtiquetaTono.aviso,
  EstadoAdelanto.descontado => EtiquetaTono.exito,
  _ => EtiquetaTono.neutral,
};

String _dm(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';

/// "del 06/10 al 12/10".
String _semana(DateTime lunes) =>
    'del ${_dm(lunes)} al ${_dm(lunes.add(const Duration(days: 6)))}';

/// Abre una hoja con el acento de RR. HH.
Future<void> _hoja(BuildContext context, WidgetBuilder contenido) {
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
    builder: (context) => Acento.modulo('rrhh', contenido),
  );
}

void _recargar(WidgetRef ref) {
  ref.invalidate(adelantosProvider);
  ref.invalidate(resumenAdelantosProvider);
  ref.invalidate(empleadosAdelantoProvider);
}

/// Plata a cuenta del sueldo. Sale de una cuenta al darla y se descuenta en la
/// planilla: todo de una vez o en partes, desde la semana que se elija. En
/// cada planilla se ajusta cuanto se descuenta esa semana. Igual que la web.
class AdelantosPagina extends ConsumerWidget {
  const AdelantosPagina({super.key});

  static const ruta = '/rrhh/adelantos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final resumen =
        ref.watch(resumenAdelantosProvider).valueOrNull ??
        const ResumenAdelantos();
    final puedeEditar = puede(ref, 'rrhh.adelantos', Accion.editar);
    final puedeAnular = puede(ref, 'rrhh.adelantos', Accion.anular);

    return AppListaPagina<Adelanto>(
      titulo: 'Adelantos',
      ruta: ruta,
      estado: ref.watch(adelantosProvider),
      visibles: ref.watch(adelantosFiltradosProvider),
      busqueda: ref.watch(busquedaAdelantosProvider),
      onBuscar: (t) => ref.read(busquedaAdelantosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar empleado',
      onRecargar: () async {
        _recargar(ref);
        try {
          await ref.read(adelantosProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      onNuevo: puede(ref, 'rrhh.adelantos', Accion.crear)
          ? () => _hoja(context, (_) => const _HojaNuevo())
          : null,
      textoNuevo: 'Nuevo adelanto',
      iconoVacio: Icons.payments_outlined,
      singular: 'adelanto',
      plural: 'adelantos',
      detalleVacio: 'Todavía no se dio ningún adelanto.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Por descontar',
          valor: formatoSoles(resumen.saldoPendiente),
          icono: Icons.payments_outlined,
          tono: DatoTono.aviso,
          nota: '${resumen.vigentes} vigentes',
        ),
        AppTarjetaDato(
          etiqueta: 'Trabajadores que deben',
          valor: '${resumen.empleados}',
          icono: Icons.people_outline,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Entregado este mes',
          valor: formatoSoles(resumen.entregadoMes),
          icono: Icons.account_balance_wallet_outlined,
          tono: DatoTono.peligro,
        ),
      ],
      filtro: BotonFiltros(
        activos: ref.watch(filtrosAdelantosActivosProvider),
        color: color,
        onAbrir: () => mostrarFiltros(
          context,
          activos: ref.read(filtrosAdelantosActivosProvider),
          onLimpiar: () {
            ref.read(estadoAdelantosFiltroProvider.notifier).state =
                EstadoAdelanto.pendiente;
            ref.read(empleadoAdelantosFiltroProvider.notifier).state = null;
          },
          grupos: [
            Consumer(
              builder: (context, ref, _) => GrupoFiltro<String?>(
                titulo: 'Estado',
                valor: ref.watch(estadoAdelantosFiltroProvider),
                opciones: [
                  for (final e in EstadoAdelanto.todos)
                    OpcionFiltro<String?>(e, EstadoAdelanto.etiqueta(e)),
                  const OpcionFiltro<String?>(null, 'Todos'),
                ],
                onCambio: (v) =>
                    ref.read(estadoAdelantosFiltroProvider.notifier).state = v,
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final empleados = ref.watch(empleadosEnAdelantosProvider);
                if (empleados.isEmpty) return const SizedBox.shrink();
                return GrupoFiltro<String?>(
                  titulo: 'Empleado',
                  valor: ref.watch(empleadoAdelantosFiltroProvider),
                  opciones: [
                    const OpcionFiltro<String?>(null, 'Todos'),
                    for (final e in empleados) OpcionFiltro<String?>(e, e),
                  ],
                  onCambio: (v) =>
                      ref.read(empleadoAdelantosFiltroProvider.notifier).state =
                          v,
                );
              },
            ),
          ],
        ),
      ),
      fila: (context, a) => _TarjetaAdelanto(
        adelanto: a,
        color: color,
        onVer: () => _hoja(context, (_) => _HojaDetalle(id: a.id)),
        onPlan: a.pendiente && puedeEditar
            ? () => _hoja(context, (_) => _HojaPlan(adelanto: a))
            : null,
        // Solo sin descuentos: lo descontado ya se le pagó de menos.
        onAnular:
            puedeAnular &&
                a.estado != EstadoAdelanto.anulado &&
                a.descontado == 0
            ? () => _anular(context, ref, a)
            : null,
      ),
    );
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, Adelanto a) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular adelanto',
      mensaje:
          'Los ${formatoSoles(a.monto)} de ${a.empleado} vuelven a '
          '${a.cuentaFinanciera ?? 'la cuenta de donde salieron'}, como si no se le hubieran dado.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(rrhhApiProvider).anularAdelanto(a.id);
      _recargar(ref);
      mensajero.mostrar('Adelanto anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaAdelanto extends StatelessWidget {
  const _TarjetaAdelanto({
    required this.adelanto,
    required this.color,
    required this.onVer,
    this.onPlan,
    this.onAnular,
  });

  final Adelanto adelanto;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback? onPlan;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    final a = adelanto;
    return AppTarjetaRegistro(
      icono: Icons.payments_outlined,
      color: color,
      titulo: a.empleado,
      insignia: AppEtiqueta(
        EstadoAdelanto.etiqueta(a.estado),
        tono: _tonoEstado(a.estado),
      ),
      campos: [
        CampoDetalle('Monto', formatoSoles(a.monto)),
        CampoDetalle(
          'Falta',
          null,
          widget: Text(
            a.saldo > 0 ? formatoSoles(a.saldo) : '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: a.saldo > 0 ? Colores.advertencia : null,
            ),
          ),
        ),
        CampoDetalle('Cómo', a.comoSeDescuenta),
        CampoDetalle('Desde', 'Semana ${_semana(a.descontarDesde)}'),
        CampoDetalle('Fecha', fechaCorta(a.fecha)),
        CampoDetalle('Salió de', a.cuentaFinanciera),
      ],
      acciones: [
        IconButton(
          onPressed: onVer,
          tooltip: 'Ver',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.visibility_outlined,
            size: 18,
            color: Acento.de(context),
          ),
        ),
        if (onPlan != null)
          IconButton(
            onPressed: onPlan,
            tooltip: 'Cómo se descuenta',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.event_repeat_outlined,
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
}

/// Desde que semana y como se descuenta: lo mismo al darlo y al cambiarlo.
class _CamposPlan extends StatelessWidget {
  const _CamposPlan({
    required this.fecha,
    required this.saldo,
    required this.desde,
    required this.onDesde,
    required this.enPartes,
    required this.onEnPartes,
    required this.cuota,
    required this.habilitado,
  });

  /// El dia en que se le dio: no se descuenta antes de esa semana.
  final DateTime fecha;

  /// Lo que hay que descontar, para decir en cuantas semanas.
  final double saldo;
  final DateTime desde;
  final ValueChanged<DateTime> onDesde;
  final bool enPartes;
  final ValueChanged<bool> onEnPartes;
  final TextEditingController cuota;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final primera = lunesDe(fecha);
    // Hasta ocho semanas por delante de hoy, y la que ya tenia si era mas lejos.
    final ultima = lunesDe(DateTime.now()).add(const Duration(days: 56));
    final semanas = <DateTime>[
      for (
        var s = primera;
        !s.isAfter(ultima);
        s = s.add(const Duration(days: 7))
      )
        s,
      if (desde.isAfter(ultima)) desde,
    ];

    String texto(DateTime s) {
      if (s == primera) return 'Esta semana (${_semana(s)})';
      if (s == primera.add(const Duration(days: 7))) {
        return 'La próxima (${_semana(s)})';
      }
      return 'Semana ${_semana(s)}';
    }

    final valor = double.tryParse(cuota.text.trim());
    final cuantas = valor != null && valor > 0 && saldo > 0
        ? (saldo / valor).ceil()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSelector<DateTime>(
          valor: desde,
          etiqueta: 'Se descuenta desde',
          icono: Icons.event_outlined,
          habilitado: habilitado,
          opciones: [for (final s in semanas) Opcion(s, texto(s))],
          onCambio: (v) {
            if (v != null) onDesde(v);
          },
        ),
        const SizedBox(height: Dimen.espacio4),
        AppSelector<bool>(
          valor: enPartes,
          etiqueta: 'Cómo',
          icono: Icons.splitscreen_outlined,
          habilitado: habilitado,
          opciones: const [
            Opcion(false, 'Todo de una vez'),
            Opcion(true, 'En partes, un monto por semana'),
          ],
          onCambio: (v) => onEnPartes(v ?? false),
        ),
        if (enPartes) ...[
          const SizedBox(height: Dimen.espacio4),
          AppCampo(
            controlador: cuota,
            etiqueta: 'Por semana',
            icono: Icons.payments_outlined,
            pista: '0.00',
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
            formateadores: [soloMonto],
            habilitado: habilitado,
          ),
          if (cuantas > 0) ...[
            const SizedBox(height: Dimen.espacio1),
            Text(
              'En $cuantas ${cuantas == 1 ? 'semana' : 'semanas'}',
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ],
        ],
        const SizedBox(height: Dimen.espacio2),
        const Text(
          'En cada planilla puedes ajustar cuánto se le descuenta esa semana; '
          'lo que no se descuente queda para la siguiente.',
          style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
        ),
      ],
    );
  }
}

/// Un adelanto nuevo: a quien, cuanto, de que cuenta sale y como se descuenta.
class _HojaNuevo extends ConsumerStatefulWidget {
  const _HojaNuevo();

  @override
  ConsumerState<_HojaNuevo> createState() => _HojaNuevoState();
}

class _HojaNuevoState extends ConsumerState<_HojaNuevo> {
  final _monto = TextEditingController();
  final _cuota = TextEditingController();
  final _observacion = TextEditingController();
  int? _empleadoId;
  int? _cuentaId;
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  late DateTime _desde = lunesDe(_fecha);
  bool _enPartes = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Para que "en N semanas" se actualice mientras se escribe.
    _monto.addListener(_refrescar);
    _cuota.addListener(_refrescar);
  }

  void _refrescar() => setState(() {});

  @override
  void dispose() {
    for (final c in [_monto, _cuota, _observacion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: hoy.subtract(const Duration(days: 60)),
      lastDate: hoy,
    );
    if (elegida == null) return;
    setState(() {
      _fecha = elegida;
      // No antes de la semana en que se le dio.
      if (_desde.isBefore(lunesDe(elegida))) _desde = lunesDe(elegida);
    });
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final monto = double.tryParse(_monto.text.trim());
    final cuota = double.tryParse(_cuota.text.trim());
    final error = _empleadoId == null
        ? 'Elige a quién se le da el adelanto.'
        : monto == null || monto <= 0
        ? 'Ingresa el monto.'
        : _cuentaId == null
        ? 'Elige de qué cuenta sale la plata.'
        : _enPartes && (cuota == null || cuota <= 0)
        ? 'Indica cuánto se le descuenta por semana.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref.read(rrhhApiProvider).crearAdelanto({
        'empleadoId': _empleadoId,
        'monto': monto,
        'fecha': diaIso(_fecha),
        'cuentaFinancieraId': _cuentaId,
        'descontarDesde': diaIso(_desde),
        'cuotaSemanal': _enPartes ? cuota : null,
        'observacion': _observacion.text.trim().isEmpty
            ? null
            : _observacion.text.trim(),
      });
      _recargar(ref);
      navegador.pop();
      mensajero.mostrar('Adelanto registrado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final empleados = ref.watch(empleadosAdelantoProvider);
    final cuentas = ref.watch(cuentasAdelantoProvider);
    final elegido = empleados.valueOrNull
        ?.where((e) => e.id == _empleadoId)
        .firstOrNull;

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloHoja(
              'Nuevo adelanto',
              apoyo:
                  'La plata sale ahora de la cuenta que elijas y se le descuenta en la planilla.',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            empleados.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion
                    ? e.texto
                    : 'No pudimos cargar los empleados.',
              ),
              data: (lista) => AppSelector<int>(
                valor: _empleadoId,
                etiqueta: 'Empleado',
                icono: Icons.person_outline,
                habilitado: !_guardando,
                lineasOpcion: 2,
                opciones: [
                  for (final e in lista)
                    Opcion(
                      e.id,
                      e.saldoAdelantos > 0
                          ? '${e.nombreCompleto} · debe ${formatoSoles(e.saldoAdelantos)}'
                          : e.nombreCompleto,
                    ),
                ],
                onCambio: (v) => setState(() => _empleadoId = v),
              ),
            ),
            if (elegido != null && elegido.sueldoSemanal == null) ...[
              const SizedBox(height: Dimen.espacio2),
              const AppAlerta(
                'No tiene sueldo semanal: no entra en la planilla y no se le podrá descontar.',
                tono: AlertaTono.aviso,
              ),
            ],
            const SizedBox(height: Dimen.espacio4),
            Row(
              children: [
                Expanded(
                  child: AppCampo(
                    controlador: _monto,
                    etiqueta: 'Monto',
                    icono: Icons.payments_outlined,
                    pista: '0.00',
                    tipoTeclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    formateadores: [soloMonto],
                    habilitado: !_guardando,
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: InkWell(
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
                      child: Text(fechaCorta(_fecha)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),
            cuentas.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar las cuentas.',
              ),
              data: (lista) => AppSelector<int>(
                valor: _cuentaId,
                etiqueta: 'Sale de',
                icono: Icons.account_balance_outlined,
                habilitado: !_guardando,
                opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
                onCambio: (v) => setState(() => _cuentaId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            _CamposPlan(
              fecha: _fecha,
              saldo: double.tryParse(_monto.text.trim()) ?? 0,
              desde: _desde,
              onDesde: (v) => setState(() => _desde = v),
              enPartes: _enPartes,
              onEnPartes: (v) => setState(() => _enPartes = v),
              cuota: _cuota,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              maxLargo: 250,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBoton(
              texto: 'Registrar',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cambiar como se descuenta lo que falta: desde que semana y de a cuanto.
class _HojaPlan extends ConsumerStatefulWidget {
  const _HojaPlan({required this.adelanto});

  final Adelanto adelanto;

  @override
  ConsumerState<_HojaPlan> createState() => _HojaPlanState();
}

class _HojaPlanState extends ConsumerState<_HojaPlan> {
  late DateTime _desde = widget.adelanto.descontarDesde;
  late bool _enPartes = widget.adelanto.cuotaSemanal != null;
  late final _cuota = TextEditingController(
    text: widget.adelanto.cuotaSemanal?.toStringAsFixed(2) ?? '',
  );
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cuota.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cuota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final cuota = double.tryParse(_cuota.text.trim());
    if (_enPartes && (cuota == null || cuota <= 0)) {
      setState(() => _error = 'Indica cuánto se le descuenta por semana.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref.read(rrhhApiProvider).cambiarPlanAdelanto(widget.adelanto.id, {
        'descontarDesde': diaIso(_desde),
        'cuotaSemanal': _enPartes ? cuota : null,
      });
      _recargar(ref);
      navegador.pop();
      mensajero.mostrar('Plan actualizado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.adelanto;
    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloHoja(
              'Cómo se le descuenta',
              apoyo:
                  '${a.empleado}: falta descontar ${formatoSoles(a.saldo)} de ${formatoSoles(a.monto)}.',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            _CamposPlan(
              fecha: a.fecha,
              saldo: a.saldo,
              desde: _desde,
              onDesde: (v) => setState(() => _desde = v),
              enPartes: _enPartes,
              onEnPartes: (v) => setState(() => _enPartes = v),
              cuota: _cuota,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBoton(
              texto: 'Guardar',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un adelanto con lo descontado semana por semana.
class _HojaDetalle extends ConsumerWidget {
  const _HojaDetalle({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: margenHoja(context),
      child: ref
          .watch(adelantoProvider(id))
          .when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Dimen.espacio5),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppAlerta(
              e is ApiExcepcion ? e.texto : 'No pudimos cargar el adelanto.',
            ),
            data: (a) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TituloHoja('Adelanto de ${a.empleado}', apoyo: a.cargo),
                  Row(
                    children: [
                      _Cifra('Monto', formatoSoles(a.monto)),
                      _Cifra('Descontado', formatoSoles(a.descontado)),
                      _Cifra('Falta', formatoSoles(a.saldo)),
                    ],
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  _Linea('Estado', EstadoAdelanto.etiqueta(a.estado)),
                  _Linea('Se le dio el', fechaCorta(a.fecha)),
                  _Linea('Cómo', a.comoSeDescuenta),
                  _Linea('Desde', 'Semana ${_semana(a.descontarDesde)}'),
                  _Linea('Salió de', a.cuentaFinanciera ?? '—'),
                  if (a.usuario != null) _Linea('Registró', a.usuario!),
                  if (a.observacion != null)
                    _Linea('Observación', a.observacion!),
                  const SizedBox(height: Dimen.espacio4),
                  const Text(
                    'Descontado en planilla',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Dimen.espacio2),
                  if (a.descuentos.isEmpty)
                    const Text(
                      'Todavía no se le descontó nada.',
                      style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
                    )
                  else
                    for (final d in a.descuentos)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Semana ${_semana(d.desde)}'
                                '${d.fechaPago != null ? '\nPagada el ${fechaHora(d.fechaPago!)}' : ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              formatoSoles(d.monto),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Acento.de(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
          ),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
