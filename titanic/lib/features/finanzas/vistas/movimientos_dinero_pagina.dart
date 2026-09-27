import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../compartido/widgets/app_selector_rango.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/tesoreria.dart';
import '../estado/mi_caja_controlador.dart';
import '../estado/tesoreria_controlador.dart';
import 'hoja_mover_plata.dart';
import 'hojas_finanzas.dart';

/// El kardex del dinero: todo lo que entra y sale de cajas y bancos, con de
/// donde viene y si es operativo. Aqui tambien se registra un ingreso o egreso
/// a mano y se anula uno registrado por error. Igual que el panel web.
class MovimientosDineroPagina extends ConsumerWidget {
  const MovimientosDineroPagina({super.key});

  static const ruta = '/finanzas/movimientos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final vigentes =
        (ref.watch(movimientosDineroProvider).valueOrNull ??
                const <MovimientoDinero>[])
            .where((m) => m.vigente);
    final ingresos = vigentes
        .where((m) => m.esIngreso)
        .fold<double>(0, (s, m) => s + m.monto);
    final egresos = vigentes
        .where((m) => !m.esIngreso)
        .fold<double>(0, (s, m) => s + m.monto);

    return AppListaPagina<MovimientoDinero>(
      titulo: 'Movimientos',
      ruta: ruta,
      estado: ref.watch(movimientosDineroProvider),
      visibles: ref.watch(movimientosDineroFiltradosProvider),
      busqueda: ref.watch(busquedaMovimientosProvider),
      onBuscar: (t) => ref.read(busquedaMovimientosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar concepto, cuenta o detalle',
      onRecargar: () async {
        ref.invalidate(movimientosDineroProvider);
        try {
          await ref.read(movimientosDineroProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      onNuevo: puede(ref, 'finanzas.movimientos', Accion.crear)
          ? () => abrirHojaFinanzas(context, (_) => const _HojaNuevo())
          : null,
      textoNuevo: 'Nuevo movimiento',
      iconoVacio: Icons.swap_horiz,
      singular: 'movimiento',
      plural: 'movimientos',
      detalleVacio: 'No hay movimientos en estas fechas.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Ingresos',
          valor: formatoSoles(ingresos),
          icono: Icons.trending_up,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Egresos',
          valor: formatoSoles(egresos),
          icono: Icons.trending_down,
          tono: DatoTono.peligro,
        ),
        AppTarjetaDato(
          etiqueta: 'Neto',
          valor: formatoSoles(ingresos - egresos),
          icono: Icons.balance,
          tono: ingresos - egresos < 0 ? DatoTono.peligro : DatoTono.modulo,
          color: color,
        ),
      ],
      encabezado: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSelectorRango(
              rango: ref.watch(rangoMovimientosProvider),
              textoVacio: 'Últimos 30 días',
              onCambio: (r) =>
                  ref.read(rangoMovimientosProvider.notifier).state = r,
            ),
            if (puede(ref, 'finanzas.movimientos', Accion.crear)) ...[
              const SizedBox(height: Dimen.espacio2),
              AppBoton(
                texto: 'Mover plata',
                icono: Icons.swap_horiz,
                variante: BotonVariante.secundario,
                tam: BotonTam.md,
                onPressed: () => _mover(context, ref),
              ),
            ],
          ],
        ),
      ),
      filtro: BotonFiltros(
        activos: ref.watch(filtrosMovimientosActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, m) => _TarjetaMovimiento(
        movimiento: m,
        color: color,
        onAnular:
            m.anulable &&
                (m.esTransferencia || m.movimientoOperativoId != null) &&
                puede(ref, 'finanzas.movimientos', Accion.anular)
            ? () => _anular(context, ref, m)
            : null,
      ),
    );
  }

  /// Mover plata entre cuentas propias: la Boveda, las cajas y los bancos.
  Future<void> _mover(BuildContext context, WidgetRef ref) async {
    final mensajero = Aviso.de(context);
    try {
      final cuentas = await ref.read(cuentasMovimientoProvider.future);
      if (!context.mounted) return;
      await abrirHojaFinanzas(
        context,
        (_) => HojaMoverPlata(
          cuentas: [
            for (final c in cuentas)
              CuentaParaMover(id: c.id, etiqueta: c.etiqueta),
          ],
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosMovimientosActivosProvider),
      onLimpiar: () {
        ref.read(cuentaMovimientosFiltroProvider.notifier).state = null;
        ref.read(tipoMovimientosFiltroProvider.notifier).state = null;
        ref.read(origenMovimientosFiltroProvider.notifier).state = null;
        ref.read(verAnuladosMovimientosProvider.notifier).state = false;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Tipo',
            valor: ref.watch(tipoMovimientosFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro('INGRESO', 'Ingreso'),
              OpcionFiltro('EGRESO', 'Egreso'),
            ],
            onCambio: (v) =>
                ref.read(tipoMovimientosFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Origen',
            valor: ref.watch(origenMovimientosFiltroProvider),
            opciones: [
              const OpcionFiltro<String?>(null, 'Todos'),
              for (final o in OrigenDinero.todos)
                OpcionFiltro<String?>(o, OrigenDinero.etiqueta(o)),
            ],
            onCambio: (v) =>
                ref.read(origenMovimientosFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final cuentas = ref.watch(cuentasEnMovimientosProvider);
            if (cuentas.isEmpty) return const SizedBox.shrink();
            return GrupoFiltro<String?>(
              titulo: 'Cuenta',
              valor: ref.watch(cuentaMovimientosFiltroProvider),
              opciones: [
                const OpcionFiltro<String?>(null, 'Todas'),
                for (final c in cuentas) OpcionFiltro<String?>(c, c),
              ],
              onCambio: (v) =>
                  ref.read(cuentaMovimientosFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<bool>(
            titulo: 'Registro',
            valor: ref.watch(verAnuladosMovimientosProvider),
            opciones: const [
              OpcionFiltro(false, 'Vigentes'),
              OpcionFiltro(true, 'Con anulados y reversas'),
            ],
            onCambio: (v) =>
                ref.read(verAnuladosMovimientosProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    MovimientoDinero m,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular movimiento',
      mensaje:
          '${m.concepto}: ${formatoSoles(m.monto)} en ${m.cuenta}. '
          'Se revierte en la cuenta y queda en el historial.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      final api = ref.read(tesoreriaApiProvider);
      // Una transferencia se anula entera, con sus dos mitades.
      if (m.esTransferencia) {
        await api.anularTransferencia(m.id);
      } else {
        await api.anularMovimiento(m.movimientoOperativoId!);
      }
      ref.invalidate(cuentasFinancierasProvider);
      ref.invalidate(movimientosDineroProvider);
      mensajero.mostrar('Movimiento anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaMovimiento extends StatelessWidget {
  const _TarjetaMovimiento({
    required this.movimiento,
    required this.color,
    this.onAnular,
  });

  final MovimientoDinero movimiento;
  final Color color;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    return AppTarjetaRegistro(
      icono: m.esIngreso ? Icons.arrow_upward : Icons.arrow_downward,
      color: color,
      titulo: m.concepto,
      insignia: m.anulado
          ? const AppEtiqueta('Anulado', tono: EtiquetaTono.neutral)
          : m.esReversa
          ? const AppEtiqueta('Reversa', tono: EtiquetaTono.neutral)
          : AppEtiqueta(
              OrigenDinero.etiqueta(m.origen),
              tono: m.origen == OrigenDinero.operativo
                  ? EtiquetaTono.modulo
                  : EtiquetaTono.neutral,
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
        CampoDetalle('Cuenta', m.cuenta),
        CampoDetalle('Saldo', formatoSoles(m.saldoResultante)),
        CampoDetalle('Categoría', m.categoria),
        CampoDetalle('Fecha', fechaHora(m.fecha)),
        CampoDetalle('Registró', m.usuario),
        CampoDetalle('Detalle', m.observacion),
      ],
      acciones: [
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

/// Un ingreso o egreso registrado a mano, en la cuenta que se elija.
class _HojaNuevo extends ConsumerStatefulWidget {
  const _HojaNuevo();

  @override
  ConsumerState<_HojaNuevo> createState() => _HojaNuevoState();
}

class _HojaNuevoState extends ConsumerState<_HojaNuevo> {
  String _tipo = 'EGRESO';
  int? _cuentaId;
  int? _categoriaId;
  final _monto = TextEditingController();
  final _detalle = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final monto = double.tryParse(_monto.text.trim());
    final error = _cuentaId == null
        ? 'Elige la cuenta.'
        : _categoriaId == null
        ? 'Elige la categoría.'
        : monto == null || monto <= 0
        ? 'Ingresa un monto mayor a cero.'
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
      await ref.read(tesoreriaApiProvider).crearMovimiento({
        'cuentaFinancieraId': _cuentaId,
        'tipo': _tipo,
        'motivoGastoId': _categoriaId,
        'monto': monto,
        'descripcion': _detalle.text.trim().isEmpty
            ? null
            : _detalle.text.trim(),
      });
      ref.invalidate(movimientosDineroProvider);
      navegador.pop();
      mensajero.mostrar(
        _tipo == 'INGRESO' ? 'Ingreso registrado' : 'Egreso registrado',
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
    final cuentas = ref.watch(cuentasMovimientoProvider);
    final categorias = ref.watch(categoriasMiCajaProvider(_tipo));

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloHoja(
              'Nuevo movimiento',
              apoyo:
                  'Un ingreso o egreso que no viene de una venta ni de una compra.',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppSelector<String>(
              valor: _tipo,
              etiqueta: 'Tipo',
              icono: Icons.swap_vert,
              habilitado: !_guardando,
              opciones: const [
                Opcion('INGRESO', 'Ingreso'),
                Opcion('EGRESO', 'Egreso'),
              ],
              // Las categorias son de un tipo: al cambiarlo se elige de nuevo.
              onCambio: (v) => setState(() {
                _tipo = v ?? _tipo;
                _categoriaId = null;
              }),
            ),
            const SizedBox(height: Dimen.espacio4),
            cuentas.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar las cuentas.',
              ),
              data: (lista) => AppSelector<int>(
                valor: _cuentaId,
                etiqueta: 'Cuenta',
                icono: Icons.account_balance_outlined,
                habilitado: !_guardando,
                opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
                onCambio: (v) => setState(() => _cuentaId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
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
              formateadores: [soloMonto],
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
