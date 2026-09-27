import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_selector_rango.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../ventas/datos/nota_venta.dart' show EstadoVerificacionPago;
import '../datos/mi_caja.dart';
import '../estado/mi_caja_controlador.dart';

/// La caja de quien esta logueado: su propio dinero en la ruta, y lo que
/// cobro o pago por Yape o transferencia.
///
/// Todo va en una sola lista, pero los indicadores separan lo que tiene en la
/// mano —el efectivo, lo unico que se cuenta al cerrar caja— de lo que entro
/// directo al banco. Un solo total haria creer que el Yape tambien se entrega,
/// y el cierre saldria con faltante sin faltar nada. Es la misma pantalla del
/// panel web.
class MiCajaPagina extends ConsumerWidget {
  const MiCajaPagina({super.key});

  static const ruta = '/finanzas/caja';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final estadoCaja = ref.watch(miCajaProvider);
    final caja = estadoCaja.valueOrNull;
    final filas = ref.watch(filasMiCajaProvider).valueOrNull ?? const [];

    double suma(Iterable<FilaMiCaja> l) =>
        l.fold<double>(0, (s, f) => s + f.monto);
    final efectivo = filas.where((f) => f.esEfectivo && f.cuenta);
    final cobrosDigitales = filas.where(
      (f) => !f.esEfectivo && f.esIngreso && f.cuenta,
    );
    final porVerificar = cobrosDigitales
        .where(
          (f) =>
              f.digital!.estadoVerificacion == EstadoVerificacionPago.pendiente,
        )
        .length;
    final rechazados = filas.where((f) => f.digital?.rechazado ?? false);

    return AppListaPagina<FilaMiCaja>(
      titulo: 'Mi Caja',
      ruta: ruta,
      // Sin caja asignada el servidor lo dice al pedirla: ese error es el que
      // se muestra, no una lista vacia que no explica nada.
      estado: estadoCaja.hasError
          ? AsyncValue<List<FilaMiCaja>>.error(
              estadoCaja.error!,
              estadoCaja.stackTrace ?? StackTrace.current,
            )
          : ref.watch(filasMiCajaProvider),
      visibles: ref.watch(filasMiCajaFiltradasProvider),
      busqueda: ref.watch(busquedaMiCajaProvider),
      onBuscar: (t) => ref.read(busquedaMiCajaProvider.notifier).state = t,
      pistaBusqueda: 'Buscar detalle, documento u operación',
      onRecargar: () async {
        ref.invalidate(miCajaProvider);
        ref.invalidate(movimientosMiCajaProvider);
        ref.invalidate(movimientosDigitalesProvider);
        try {
          await Future.wait([
            ref.read(movimientosMiCajaProvider.future),
            ref.read(movimientosDigitalesProvider.future),
          ]);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.point_of_sale_outlined,
      singular: 'movimiento',
      plural: 'movimientos',
      tituloVacio: 'Sin movimientos',
      detalleVacio: 'No hay movimientos en estas fechas.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Efectivo en tu mano',
          valor: caja == null ? '—' : formatoSoles(caja.saldoActual),
          icono: Icons.account_balance_wallet_outlined,
          tono: caja != null && caja.saldoActual < 0
              ? DatoTono.peligro
              : DatoTono.modulo,
          nota: 'Lo que se cuenta al cerrar caja',
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Ingresos en efectivo',
          valor: formatoSoles(suma(efectivo.where((f) => f.esIngreso))),
          icono: Icons.trending_up,
          tono: DatoTono.exito,
          nota: 'En estas fechas',
        ),
        AppTarjetaDato(
          etiqueta: 'Egresos en efectivo',
          valor: formatoSoles(suma(efectivo.where((f) => !f.esIngreso))),
          icono: Icons.trending_down,
          tono: DatoTono.peligro,
          nota: 'En estas fechas',
        ),
        AppTarjetaDato(
          etiqueta: 'Cobrado digital',
          valor: formatoSoles(suma(cobrosDigitales)),
          icono: Icons.smartphone_outlined,
          tono: DatoTono.aviso,
          nota: porVerificar > 0
              ? 'Va al banco · $porVerificar por verificar'
              : 'Va directo al banco',
        ),
      ],
      encabezado: _Encabezado(
        rango: ref.watch(rangoMiCajaProvider),
        onRango: (r) => ref.read(rangoMiCajaProvider.notifier).state = r,
        aviso: rechazados.isEmpty
            ? null
            : '${rechazados.length == 1 ? 'Un cobro no apareció' : '${rechazados.length} cobros no aparecieron'} '
                  'en el banco: ${formatoSoles(suma(rechazados))} se te '
                  'descuentan en tu planilla.',
        // Sin caja no hay nada que registrar ni cerrar.
        habilitado: caja != null,
        onIngreso: () => _abrirMovimiento(context, 'INGRESO'),
        onEgreso: () => _abrirMovimiento(context, 'EGRESO'),
        onCerrar: () => _abrirCierre(context),
      ),
      filtro: BotonFiltros(
        activos: ref.watch(filtrosMiCajaActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, f) => f.esEfectivo
          ? _TarjetaMovimiento(movimiento: f.efectivo!, color: color)
          : _TarjetaDigital(movimiento: f.digital!, color: color),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosMiCajaActivosProvider),
      onLimpiar: () {
        ref.read(tipoMiCajaFiltroProvider.notifier).state = null;
        ref.read(conceptoMiCajaFiltroProvider.notifier).state = null;
        ref.read(medioMiCajaFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Medio',
            valor: ref.watch(medioMiCajaFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro('EFECTIVO', 'Efectivo'),
              OpcionFiltro('DIGITAL', 'Yape o transferencia'),
            ],
            onCambio: (v) =>
                ref.read(medioMiCajaFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Tipo',
            valor: ref.watch(tipoMiCajaFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro('INGRESO', 'Ingreso'),
              OpcionFiltro('EGRESO', 'Egreso'),
            ],
            onCambio: (v) =>
                ref.read(tipoMiCajaFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Concepto',
            valor: ref.watch(conceptoMiCajaFiltroProvider),
            opciones: [
              const OpcionFiltro<String?>(null, 'Todos'),
              for (final e in DocumentoMovimiento.etiquetas.entries)
                OpcionFiltro<String?>(e.key, e.value),
            ],
            onCambio: (v) =>
                ref.read(conceptoMiCajaFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirMovimiento(BuildContext context, String tipo) =>
      _abrirHoja(context, (_) => _HojaMovimiento(tipo: tipo));

  Future<void> _abrirCierre(BuildContext context) =>
      _abrirHoja(context, (_) => const _HojaCierre());

  Future<void> _abrirHoja(BuildContext context, WidgetBuilder hoja) {
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
      // La hoja cuelga del Navigator y no hereda el acento del modulo: se
      // vuelve a declarar, igual que en los formularios.
      builder: (context) => Acento.modulo('finanzas', hoja),
    );
  }
}

/// Las fechas que se miran y lo que se puede hacer con la caja.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.rango,
    required this.onRango,
    required this.aviso,
    required this.habilitado,
    required this.onIngreso,
    required this.onEgreso,
    required this.onCerrar,
  });

  final DateTimeRange? rango;
  final ValueChanged<DateTimeRange?> onRango;

  /// Cobros que no aparecieron en el banco: se le descuentan.
  final String? aviso;
  final bool habilitado;
  final VoidCallback onIngreso;
  final VoidCallback onEgreso;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (aviso != null) ...[
            AppAlerta(aviso!, tono: AlertaTono.aviso),
            const SizedBox(height: Dimen.espacio2),
          ],
          AppSelectorRango(
            rango: rango,
            textoVacio: 'Últimos 30 días',
            onCambio: onRango,
          ),
          const SizedBox(height: Dimen.espacio2),
          Row(
            children: [
              Expanded(
                child: AppBoton(
                  texto: 'Ingreso',
                  icono: Icons.arrow_upward,
                  variante: BotonVariante.secundario,
                  tam: BotonTam.md,
                  onPressed: habilitado ? onIngreso : null,
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: AppBoton(
                  texto: 'Egreso',
                  icono: Icons.arrow_downward,
                  variante: BotonVariante.secundario,
                  tam: BotonTam.md,
                  onPressed: habilitado ? onEgreso : null,
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: AppBoton(
                  texto: 'Cerrar',
                  icono: Icons.lock_outline,
                  tam: BotonTam.md,
                  onPressed: habilitado ? onCerrar : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaMovimiento extends StatelessWidget {
  const _TarjetaMovimiento({required this.movimiento, required this.color});

  final MovimientoCaja movimiento;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    return AppTarjetaRegistro(
      icono: m.esIngreso ? Icons.arrow_upward : Icons.arrow_downward,
      color: color,
      titulo: m.concepto,
      insignia: m.esReversa
          ? const AppEtiqueta('Reversa', tono: EtiquetaTono.neutral)
          : m.anulado
          ? const AppEtiqueta('Anulado', tono: EtiquetaTono.neutral)
          : AppEtiqueta(
              m.esIngreso ? 'Ingreso' : 'Egreso',
              tono: m.esIngreso ? EtiquetaTono.exito : EtiquetaTono.peligro,
            ),
      campos: [
        CampoDetalle(
          'Monto',
          null,
          widget: Text(
            '${m.esIngreso ? '+' : '-'}${formatoSoles(m.monto)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: m.esIngreso ? Colores.exito : Colores.peligro,
            ),
          ),
        ),
        CampoDetalle('Medio', 'Efectivo'),
        CampoDetalle('Saldo en caja', formatoSoles(m.saldoResultante)),
        CampoDetalle('Fecha', _fechaHora(m.fecha)),
        CampoDetalle('Detalle', m.observacion),
      ],
    );
  }
}

/// Un cobro o pago por Yape o transferencia: no esta en la caja ni cuenta
/// para el cierre, pero es suyo.
class _TarjetaDigital extends StatelessWidget {
  const _TarjetaDigital({required this.movimiento, required this.color});

  final MovimientoDigital movimiento;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    return AppTarjetaRegistro(
      icono: m.metodoTipo == 'TRANSFERENCIA'
          ? Icons.swap_horiz
          : Icons.smartphone_outlined,
      color: color,
      titulo: '${m.esCobro ? 'Cobro' : 'Pago'} ${m.documento}',
      insignia: m.anulado
          ? const AppEtiqueta('Anulado', tono: EtiquetaTono.neutral)
          : m.estadoVerificacion == null
          ? AppEtiqueta(m.metodoPago)
          : AppEtiqueta(
              EstadoVerificacionPago.etiqueta(m.estadoVerificacion!),
              tono: m.rechazado
                  ? EtiquetaTono.peligro
                  : m.estadoVerificacion == EstadoVerificacionPago.pendiente
                  ? EtiquetaTono.aviso
                  : EtiquetaTono.exito,
            ),
      campos: [
        CampoDetalle(
          'Monto',
          null,
          widget: Text(
            '${m.esCobro ? '+' : '-'}${formatoSoles(m.monto)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              decoration: m.anulado || m.rechazado
                  ? TextDecoration.lineThrough
                  : null,
              color: m.anulado || m.rechazado
                  ? Colores.tintaSuave
                  : m.esCobro
                  ? Colores.exito
                  : Colores.peligro,
            ),
          ),
        ),
        CampoDetalle('Método', m.metodoPago),
        CampoDetalle(m.esCobro ? 'Cliente' : 'Proveedor', m.contraparte),
        if (m.numeroOperacion != null)
          CampoDetalle('N° operación', m.numeroOperacion),
        CampoDetalle(m.esCobro ? 'Entró a' : 'Salió de', m.cuenta),
        CampoDetalle('Fecha', _fechaHora(m.fecha)),
      ],
    );
  }
}

String _fechaHora(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

/// Dinero: como mucho dos decimales.
final _soloMonto = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

/// El margen de una hoja, con lugar para el teclado cuando se abre.
EdgeInsets _margenHoja(BuildContext context) => EdgeInsets.fromLTRB(
  Dimen.espacio4,
  0,
  Dimen.espacio4,
  MediaQuery.viewInsetsOf(context).bottom + Dimen.espacio5,
);

/// Un ingreso o egreso libre: no hace falta que sea una venta ni un gasto de ruta.
class _HojaMovimiento extends ConsumerStatefulWidget {
  const _HojaMovimiento({required this.tipo});

  /// INGRESO o EGRESO.
  final String tipo;

  @override
  ConsumerState<_HojaMovimiento> createState() => _HojaMovimientoState();
}

class _HojaMovimientoState extends ConsumerState<_HojaMovimiento> {
  final _monto = TextEditingController();
  final _detalle = TextEditingController();
  int? _categoriaId;
  bool _guardando = false;
  String? _error;

  bool get _esIngreso => widget.tipo == 'INGRESO';

  @override
  void dispose() {
    _monto.dispose();
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final monto = double.tryParse(_monto.text.trim());
    if (_categoriaId == null) {
      setState(() => _error = 'Elige la categoría.');
      return;
    }
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresa un monto mayor a cero.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref.read(miCajaApiProvider).registrarMovimiento({
        // La cuenta la pone el servidor: siempre la caja de quien registra.
        'cuentaFinancieraId': 0,
        'tipo': widget.tipo,
        'motivoGastoId': _categoriaId,
        'monto': monto,
        'descripcion': _detalle.text.trim().isEmpty
            ? null
            : _detalle.text.trim(),
      });
      ref.invalidate(miCajaProvider);
      ref.invalidate(movimientosMiCajaProvider);
      navegador.pop();
      mensajero.mostrar(
        _esIngreso ? 'Ingreso registrado' : 'Egreso registrado',
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
    final categorias = ref.watch(categoriasMiCajaProvider(widget.tipo));

    return Padding(
      padding: _margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _esIngreso ? 'Registrar ingreso' : 'Registrar egreso',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Dimen.espacio4),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            categorias.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion
                    ? e.texto
                    : 'No pudimos cargar las categorías.',
              ),
              data: (lista) => AppSelector<int>(
                valor: _categoriaId,
                etiqueta: 'Categoría',
                icono: Icons.category_outlined,
                habilitado: !_guardando,
                opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
                onCambio: (v) => setState(() => _categoriaId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _monto,
              etiqueta: 'Monto',
              icono: Icons.payments_outlined,
              pista: '0.00',
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              formateadores: [_soloMonto],
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _detalle,
              etiqueta: 'Detalle',
              icono: Icons.notes_outlined,
              opcional: true,
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

/// Cierra la caja: se cuenta billete por billete y moneda por moneda, y se
/// elige a quién se le entrega lo contado.
///
/// No muestra cuánto "debería" haber: se cuenta lo que hay en la mano, y la
/// diferencia la calcula el servidor al cerrar.
class _HojaCierre extends ConsumerStatefulWidget {
  const _HojaCierre();

  @override
  ConsumerState<_HojaCierre> createState() => _HojaCierreState();
}

class _HojaCierreState extends ConsumerState<_HojaCierre> {
  static const _billetes = [200.0, 100.0, 50.0, 20.0, 10.0];
  static const _monedas = [5.0, 2.0, 1.0, 0.5, 0.2, 0.1];

  late final Map<double, TextEditingController> _cantidades = {
    for (final v in [..._billetes, ..._monedas]) v: TextEditingController(),
  };
  final _observacion = TextEditingController();
  int? _destinoId;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _cantidades.values) {
      c.dispose();
    }
    _observacion.dispose();
    super.dispose();
  }

  int _cantidad(double valor) => int.tryParse(_cantidades[valor]!.text) ?? 0;

  /// Suma en centimos: 0.1 x 3 en decimales da 0.30000000000000004.
  double _suma(List<double> valores) =>
      valores.fold<int>(0, (s, v) => s + (v * 100).round() * _cantidad(v)) /
      100;

  Future<void> _cerrar() async {
    FocusScope.of(context).unfocus();
    if (_destinoId == null) {
      setState(() => _error = 'Elige a quién le entregas lo contado.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      final cierre = await ref.read(miCajaApiProvider).cerrar({
        'billetes': _suma(_billetes),
        'monedas': _suma(_monedas),
        'cuentaDestinoId': _destinoId,
        'observacion': _observacion.text.trim().isEmpty
            ? null
            : _observacion.text.trim(),
      });
      ref.invalidate(miCajaProvider);
      ref.invalidate(movimientosMiCajaProvider);
      navegador.pop();

      final d = cierre.diferencia;
      if (d < 0) {
        mensajero.error(
          'Caja cerrada con un faltante de ${formatoSoles(-d)}: se descuenta en tu planilla.',
        );
      } else if (d > 0) {
        mensajero.mostrar(
          'Caja cerrada con un sobrante de ${formatoSoles(d)}.',
        );
      } else {
        mensajero.mostrar('Caja cerrada: cuadró exacto.');
      }
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinos = ref.watch(destinosMiCajaProvider);
    final total = _suma(_billetes) + _suma(_monedas);

    return Padding(
      padding: _margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cerrar caja',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Dimen.espacio1),
            const Text(
              'Cuenta billete por billete y moneda por moneda, y elige a quién se lo entregas.',
              style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            _Desglose(
              billetes: _billetes,
              monedas: _monedas,
              cantidades: _cantidades,
              habilitado: !_guardando,
              subtotalBilletes: _suma(_billetes),
              subtotalMonedas: _suma(_monedas),
              onCambio: () => setState(() {}),
            ),
            const SizedBox(height: Dimen.espacio3),
            Row(
              children: [
                const Text(
                  'Total contado',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  formatoSoles(total),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Acento.de(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),
            destinos.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar las cuentas.',
              ),
              data: (lista) => AppSelector<int>(
                valor: _destinoId,
                etiqueta: 'Entregar a',
                icono: Icons.account_balance_outlined,
                habilitado: !_guardando,
                opciones: [for (final d in lista) Opcion(d.id, d.etiqueta)],
                onCambio: (v) => setState(() => _destinoId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              pista: 'Alguna razón de la diferencia...',
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBoton(
              texto: 'Cerrar y entregar',
              cargando: _guardando,
              onPressed: _cerrar,
            ),
          ],
        ),
      ),
    );
  }
}

/// El conteo del cierre en una sola lista, igual que en la web: billetes y
/// luego monedas, numerados, con la cantidad al medio y lo que suma a la
/// derecha. Con dos bloques separados, lo contado en uno quedaba fuera de
/// la vista al revisar el otro.
class _Desglose extends StatelessWidget {
  const _Desglose({
    required this.billetes,
    required this.monedas,
    required this.cantidades,
    required this.habilitado,
    required this.subtotalBilletes,
    required this.subtotalMonedas,
    required this.onCambio,
  });

  final List<double> billetes;
  final List<double> monedas;
  final Map<double, TextEditingController> cantidades;
  final bool habilitado;
  final double subtotalBilletes;
  final double subtotalMonedas;
  final VoidCallback onCambio;

  // Simetricas: lo mismo a cada lado de la cantidad, que queda al medio.
  static const _flexNumero = 8;
  static const _flexNombre = 32;
  static const _flexCantidad = 20;
  static const _flexTotal = 40;

  static const _texto = TextStyle(fontSize: 12.5, color: Colores.tinta);

  @override
  Widget build(BuildContext context) {
    final filas = [
      for (final v in billetes) (tipo: 'Billete', valor: v),
      for (final v in monedas) (tipo: 'Moneda', valor: v),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < filas.length; i++)
            Container(
              color: i.isOdd ? Colores.fondo : null,
              padding: const EdgeInsets.symmetric(
                horizontal: Dimen.espacio3,
                vertical: 5,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: _flexNumero,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colores.tintaSuave,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _flexNombre,
                    child: Text(
                      '${filas[i].tipo} ${formatoSoles(filas[i].valor)}',
                      style: _texto,
                    ),
                  ),
                  Expanded(
                    flex: _flexCantidad,
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: cantidades[filas[i].valor],
                        enabled: habilitado,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        style: _texto,
                        decoration: const InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (_) => onCambio(),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _flexTotal,
                    child: Text(
                      (((filas[i].valor * 100).round() *
                                  (int.tryParse(
                                        cantidades[filas[i].valor]!.text,
                                      ) ??
                                      0)) /
                              100)
                          .toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: _texto.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimen.espacio3,
              Dimen.espacio2,
              Dimen.espacio3,
              Dimen.espacio2,
            ),
            child: Column(
              children: [
                _Subtotal('Billetes', subtotalBilletes),
                const SizedBox(height: 2),
                _Subtotal('Monedas', subtotalMonedas),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Subtotal extends StatelessWidget {
  const _Subtotal(this.etiqueta, this.monto);

  final String etiqueta;
  final double monto;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 12, color: Colores.tintaSuave);
    return Row(
      children: [
        const Spacer(),
        Text(etiqueta, style: estilo),
        const SizedBox(width: Dimen.espacio4),
        SizedBox(
          width: 90,
          child: Text(
            formatoSoles(monto),
            textAlign: TextAlign.right,
            style: estilo,
          ),
        ),
      ],
    );
  }
}
