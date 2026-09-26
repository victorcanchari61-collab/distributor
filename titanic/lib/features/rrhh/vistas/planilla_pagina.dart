import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
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
import '../datos/planilla.dart';
import '../estado/asistencia_controlador.dart';
import '../estado/planilla_controlador.dart';

String _dia(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

String _diaHora(DateTime f) =>
    '${_dia(f)} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

String _mas(double n) => n > 0 ? '+${formatoSoles(n)}' : '—';
String _menos(double n) => n > 0 ? '-${formatoSoles(n)}' : '—';

EtiquetaTono _tonoPlanilla(String estado) => switch (estado) {
  EstadoPlanilla.borrador => EtiquetaTono.aviso,
  EstadoPlanilla.pagada => EtiquetaTono.exito,
  _ => EtiquetaTono.neutral,
};

/// La planilla semanal: lo que se le paga a cada empleado de lunes a domingo.
///
/// Sueldo semanal menos faltas y permisos (un dia = sueldo / 6), mas feriados
/// trabajados, bonos y otros descuentos puestos a mano, menos los faltantes de
/// caja. Se arma en borrador, se ajusta, y al pagarla sale la plata de la
/// cuenta elegida. Es la misma pantalla del panel web.
class PlanillaPagina extends ConsumerStatefulWidget {
  const PlanillaPagina({super.key});

  static const ruta = '/rrhh/planilla';

  @override
  ConsumerState<PlanillaPagina> createState() => _PlanillaPaginaState();
}

class _PlanillaPaginaState extends ConsumerState<PlanillaPagina> {
  bool _trabajando = false;

  Future<void> _generar(Planilla? actual) async {
    final mensajero = Aviso.de(context);
    setState(() => _trabajando = true);
    try {
      await ref
          .read(rrhhApiProvider)
          .generarPlanilla(ref.read(semanaPlanillaProvider));
      ref.invalidate(planillaSemanaProvider);
      ref.invalidate(historialPlanillasProvider);
      mensajero.mostrar(
        actual == null ? 'Planilla armada' : 'Planilla recalculada',
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _anular(Planilla p) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular la planilla',
      mensaje: p.estado == EstadoPlanilla.pagada
          ? 'Se revierte el pago y los faltantes descontados vuelven a quedar pendientes. No se puede deshacer.'
          : 'Se descarta este borrador.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(rrhhApiProvider).anularPlanilla(p.id);
      ref.invalidate(planillaSemanaProvider);
      ref.invalidate(historialPlanillasProvider);
      mensajero.mostrar('Planilla anulada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _hoja(WidgetBuilder contenido) {
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

  @override
  Widget build(BuildContext context) {
    final color =
        resolverRuta(PlanillaPagina.ruta).grupo?.color ?? Colores.marca;
    final planilla = ref.watch(planillaSemanaProvider).valueOrNull;
    final borrador = planilla?.esBorrador ?? false;
    final puedeCrear = puede(ref, 'rrhh.planilla', Accion.crear);

    return AppListaPagina<PlanillaDetalle>(
      titulo: 'Planilla semanal',
      ruta: PlanillaPagina.ruta,
      estado: ref.watch(detallePlanillaProvider),
      visibles: ref.watch(detallePlanillaFiltradoProvider),
      busqueda: ref.watch(busquedaPlanillaProvider),
      onBuscar: (t) => ref.read(busquedaPlanillaProvider.notifier).state = t,
      pistaBusqueda: 'Buscar empleado',
      onRecargar: () async {
        ref.invalidate(planillaSemanaProvider);
        try {
          await ref.read(planillaSemanaProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.payments_outlined,
      singular: 'empleado',
      plural: 'empleados',
      tituloVacio: planilla == null ? 'Sin planilla' : 'Sin empleados',
      detalleVacio: planilla == null
          ? 'Esta semana todavía no tiene planilla: usa "Armar planilla".'
          : 'Ningún empleado activo tiene sueldo semanal.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Costo de planilla',
          valor: formatoSoles(planilla?.totalCostoLaboral ?? 0),
          icono: Icons.calculate_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Faltantes descontados',
          valor: formatoSoles(planilla?.totalFaltantes ?? 0),
          icono: Icons.money_off_outlined,
          tono: DatoTono.peligro,
        ),
        AppTarjetaDato(
          etiqueta: 'Neto a pagar',
          valor: formatoSoles(planilla?.totalNeto ?? 0),
          icono: Icons.account_balance_wallet_outlined,
          tono: DatoTono.exito,
        ),
      ],
      encabezado: _Encabezado(
        semana: ref.watch(semanaPlanillaProvider),
        planilla: planilla,
        trabajando: _trabajando,
        onSemana: (s) => ref.read(semanaPlanillaProvider.notifier).state = s,
        onGenerar: (planilla == null || borrador) && puedeCrear
            ? () => _generar(planilla)
            : null,
        onPagar: borrador && puedeCrear
            ? () => _hoja((_) => _HojaPagar(planilla: planilla!))
            : null,
        onAnular: planilla != null && puede(ref, 'rrhh.planilla', Accion.anular)
            ? () => _anular(planilla)
            : null,
        onHistorial: () => _hoja((_) => const _HojaHistorial()),
      ),
      fila: (context, d) => _TarjetaDetalle(
        detalle: d,
        color: color,
        onAjustar: borrador && puede(ref, 'rrhh.planilla', Accion.editar)
            ? () => _hoja((_) => _HojaAjuste(detalle: d))
            : null,
      ),
    );
  }
}

/// La semana que se mira, su estado y lo que se puede hacer con ella.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.semana,
    required this.planilla,
    required this.trabajando,
    required this.onSemana,
    required this.onGenerar,
    required this.onPagar,
    required this.onAnular,
    required this.onHistorial,
  });

  final DateTime semana;
  final Planilla? planilla;
  final bool trabajando;
  final ValueChanged<DateTime> onSemana;
  final VoidCallback? onGenerar;
  final VoidCallback? onPagar;
  final VoidCallback? onAnular;
  final VoidCallback onHistorial;

  @override
  Widget build(BuildContext context) {
    final domingo = semana.add(const Duration(days: 6));
    final esActual = !semana.isBefore(lunesDe(DateTime.now()));
    final p = planilla;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                onPressed: () =>
                    onSemana(semana.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  'Semana del ${_dia(semana)} al ${_dia(domingo)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Semana siguiente',
                // No se arma la planilla de una semana que no empezo.
                onPressed: esActual
                    ? null
                    : () => onSemana(semana.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (p != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Dimen.espacio2),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Dimen.espacio2,
                children: [
                  AppEtiqueta(
                    EstadoPlanilla.etiqueta(p.estado),
                    tono: _tonoPlanilla(p.estado),
                  ),
                  if (p.estado == EstadoPlanilla.pagada &&
                      p.cuentaFinanciera != null)
                    Text(
                      'desde ${p.cuentaFinanciera}'
                      '${p.fechaPago != null ? ' el ${_diaHora(p.fechaPago!)}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colores.tintaSuave,
                      ),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              if (onGenerar != null)
                Expanded(
                  child: AppBoton(
                    texto: p == null ? 'Armar' : 'Recalcular',
                    icono: Icons.refresh,
                    variante: BotonVariante.secundario,
                    tam: BotonTam.md,
                    cargando: trabajando,
                    onPressed: onGenerar,
                  ),
                ),
              if (onPagar != null) ...[
                const SizedBox(width: Dimen.espacio2),
                Expanded(
                  child: AppBoton(
                    texto: 'Pagar',
                    icono: Icons.payments_outlined,
                    tam: BotonTam.md,
                    onPressed: trabajando ? null : onPagar,
                  ),
                ),
              ],
              if (onAnular != null) ...[
                const SizedBox(width: Dimen.espacio2),
                Expanded(
                  child: AppBoton(
                    texto: 'Anular',
                    icono: Icons.block,
                    variante: BotonVariante.secundario,
                    tam: BotonTam.md,
                    onPressed: trabajando ? null : onAnular,
                  ),
                ),
              ],
              const SizedBox(width: Dimen.espacio1),
              IconButton(
                tooltip: 'Historial',
                onPressed: onHistorial,
                icon: const Icon(Icons.history),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaDetalle extends StatelessWidget {
  const _TarjetaDetalle({
    required this.detalle,
    required this.color,
    this.onAjustar,
  });

  final PlanillaDetalle detalle;
  final Color color;
  final VoidCallback? onAjustar;

  @override
  Widget build(BuildContext context) {
    final d = detalle;
    return AppTarjetaRegistro(
      icono: Icons.person_outline,
      color: color,
      titulo: d.empleado,
      insignia: Text(
        formatoSoles(d.neto),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Acento.de(context),
        ),
      ),
      campos: [
        CampoDetalle('Cargo', d.cargo),
        CampoDetalle('Sueldo', formatoSoles(d.sueldoSemanal)),
        CampoDetalle(
          'Faltas y permisos',
          d.diasNoPagados > 0
              ? '${_menos(d.descuentoInasistencias)} (${d.diasNoPagados} d)'
              : '—',
        ),
        CampoDetalle('Feriados', _mas(d.extraFeriados)),
        CampoDetalle('Bonos', _mas(d.bonos)),
        CampoDetalle(
          'Otros desc.',
          d.otrosDescuentos > 0
              ? '${_menos(d.otrosDescuentos)}${d.notaAjuste != null ? ' · ${d.notaAjuste}' : ''}'
              : '—',
        ),
        CampoDetalle(
          'Faltantes de caja',
          null,
          widget: Text(
            _menos(d.descuentoFaltantes),
            style: TextStyle(
              fontSize: 13,
              color: d.descuentoFaltantes > 0 ? Colores.peligro : null,
            ),
          ),
        ),
        CampoDetalle('A pagar', formatoSoles(d.neto)),
      ],
      acciones: [
        if (onAjustar != null)
          IconButton(
            onPressed: onAjustar,
            tooltip: 'Ajustar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
      ],
    );
  }
}

/// Dinero: como mucho dos decimales.
final _soloMonto = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

EdgeInsets _margenHoja(BuildContext context) => EdgeInsets.fromLTRB(
  Dimen.espacio4,
  0,
  Dimen.espacio4,
  MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
);

/// Bonos y otros descuentos de un empleado, con su nota. Solo en borrador.
class _HojaAjuste extends ConsumerStatefulWidget {
  const _HojaAjuste({required this.detalle});

  final PlanillaDetalle detalle;

  @override
  ConsumerState<_HojaAjuste> createState() => _HojaAjusteState();
}

class _HojaAjusteState extends ConsumerState<_HojaAjuste> {
  late final _bonos = TextEditingController(
    text: widget.detalle.bonos > 0
        ? widget.detalle.bonos.toStringAsFixed(2)
        : '',
  );
  late final _descuentos = TextEditingController(
    text: widget.detalle.otrosDescuentos > 0
        ? widget.detalle.otrosDescuentos.toStringAsFixed(2)
        : '',
  );
  late final _nota = TextEditingController(
    text: widget.detalle.notaAjuste ?? '',
  );
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _bonos.dispose();
    _descuentos.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final bonos = double.tryParse(_bonos.text.trim()) ?? 0;
    final descuentos = double.tryParse(_descuentos.text.trim()) ?? 0;

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref
          .read(rrhhApiProvider)
          .ajustarPlanilla(
            widget.detalle.id,
            bonos: bonos,
            otrosDescuentos: descuentos,
            nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
          );
      ref.invalidate(planillaSemanaProvider);
      ref.invalidate(historialPlanillasProvider);
      navegador.pop();
      mensajero.mostrar('Ajuste guardado');
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
      padding: _margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ajustar a ${widget.detalle.empleado}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Dimen.espacio1),
            const Text(
              'Se conservan aunque se recalcule la planilla.',
              style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppCampo(
              controlador: _bonos,
              etiqueta: 'Bonos',
              icono: Icons.add_circle_outline,
              pista: '0.00',
              opcional: true,
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              formateadores: [_soloMonto],
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _descuentos,
              etiqueta: 'Otros descuentos',
              icono: Icons.remove_circle_outline,
              pista: '0.00',
              opcional: true,
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              formateadores: [_soloMonto],
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _nota,
              etiqueta: 'Nota',
              icono: Icons.notes_outlined,
              pista: 'Por qué el bono o el descuento',
              opcional: true,
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

/// Pagar la planilla: de que cuenta sale la plata.
class _HojaPagar extends ConsumerStatefulWidget {
  const _HojaPagar({required this.planilla});

  final Planilla planilla;

  @override
  ConsumerState<_HojaPagar> createState() => _HojaPagarState();
}

class _HojaPagarState extends ConsumerState<_HojaPagar> {
  int? _cuentaId;
  bool _pagando = false;
  String? _error;

  Future<void> _pagar() async {
    if (_cuentaId == null) {
      setState(() => _error = 'Elige de qué cuenta sale el pago.');
      return;
    }
    setState(() {
      _pagando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref
          .read(rrhhApiProvider)
          .pagarPlanilla(widget.planilla.id, _cuentaId!);
      ref.invalidate(planillaSemanaProvider);
      ref.invalidate(historialPlanillasProvider);
      navegador.pop();
      mensajero.mostrar('Planilla pagada');
    } on ApiExcepcion catch (e) {
      setState(() {
        _pagando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasPlanillaProvider);
    final p = widget.planilla;

    return Padding(
      padding: _margenHoja(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pagar la planilla',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dimen.espacio1),
          Text(
            'Semana del ${_dia(p.desde)} al ${_dia(p.hasta)} · ${p.detalle.length} empleados',
            style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio4),
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          Row(
            children: [
              const Text(
                'Sale de la cuenta',
                style: TextStyle(fontSize: 14, color: Colores.tintaSuave),
              ),
              const Spacer(),
              Text(
                formatoSoles(p.totalNeto),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Acento.de(context),
                ),
              ),
            ],
          ),
          if (p.totalFaltantes > 0)
            Text(
              'Ya descontados ${formatoSoles(p.totalFaltantes)} de faltantes de caja.',
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          const SizedBox(height: Dimen.espacio4),
          cuentas.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => AppAlerta(
              e is ApiExcepcion ? e.texto : 'No pudimos cargar las cuentas.',
            ),
            data: (lista) => AppSelector<int>(
              valor: _cuentaId,
              etiqueta: 'Cuenta de la que sale',
              icono: Icons.account_balance_outlined,
              habilitado: !_pagando,
              opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
              onCambio: (v) => setState(() => _cuentaId = v),
            ),
          ),
          const SizedBox(height: Dimen.espacio5),
          AppBoton(
            texto: 'Pagar ${formatoSoles(p.totalNeto)}',
            cargando: _pagando,
            onPressed: _pagar,
          ),
        ],
      ),
    );
  }
}

/// Las semanas ya armadas. Tocar una la abre.
class _HojaHistorial extends ConsumerWidget {
  const _HojaHistorial();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(historialPlanillasProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimen.espacio4,
          0,
          Dimen.espacio4,
          Dimen.espacio4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Historial de planillas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Dimen.espacio3),
            Flexible(
              child: historial.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Dimen.espacio5),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => AppAlerta(
                  e is ApiExcepcion
                      ? e.texto
                      : 'No pudimos cargar el historial.',
                ),
                data: (lista) => lista.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(Dimen.espacio5),
                        child: Text(
                          'Todavía no se armó ninguna planilla.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colores.tintaSuave),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final h = lista[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${_dia(h.desde)} al ${_dia(h.hasta)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${h.empleados} empleados · ${formatoSoles(h.totalNeto)}'
                              '${h.fechaPago != null ? ' · pagada el ${_dia(h.fechaPago!)}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: AppEtiqueta(
                              EstadoPlanilla.etiqueta(h.estado),
                              tono: _tonoPlanilla(h.estado),
                            ),
                            // Una anulada no se abre: la semana muestra la
                            // vigente, no la descartada.
                            onTap: h.estado == EstadoPlanilla.anulada
                                ? null
                                : () {
                                    ref
                                        .read(semanaPlanillaProvider.notifier)
                                        .state = lunesDe(
                                      h.desde,
                                    );
                                    Navigator.of(context).pop();
                                  },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
