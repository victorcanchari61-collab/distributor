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
import '../../../compartido/widgets/app_selector_rango.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../ventas/datos/nota_venta.dart' show EstadoVerificacionPago;
import '../datos/tesoreria.dart';
import '../estado/tesoreria_controlador.dart';
import 'hojas_finanzas.dart';

const _descuentos = <String, String>{
  'PENDIENTE': 'Pendiente',
  'DESCONTADO': 'Descontado',
  'ANULADO': 'Anulado',
  'NINGUNO': 'Sin descuento',
};

/// Los cierres de caja de todos: cuanto debia haber, cuanto se conto y a
/// quien se entrego. Un faltante se descuenta en la planilla del trabajador;
/// un cierre mal contado se anula desde aqui. Igual que el panel web.
///
/// Lo cobrado por Yape, Plin o transferencia no pasa por la caja: se cuadra en
/// la pestaña Cobros digitales, buscandolo en el banco por su numero de
/// operacion.
class CierresCajaPagina extends ConsumerWidget {
  const CierresCajaPagina({super.key});

  static const ruta = '/finanzas/cierres';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final encabezado = _Encabezado(
      digitales: ref.watch(verCobrosDigitalesProvider),
      onPestana: (v) => ref.read(verCobrosDigitalesProvider.notifier).state = v,
    );
    if (ref.watch(verCobrosDigitalesProvider)) {
      return _paginaDigitales(context, ref, color, encabezado);
    }

    final vigentes =
        (ref.watch(cierresCajaProvider).valueOrNull ??
                const <CierreRegistrado>[])
            .where((c) => !c.anulado);
    final pendientes = vigentes
        .where((c) => c.estadoDescuento == 'PENDIENTE')
        .fold<double>(0, (s, c) => s + (c.saldoDescuento ?? -c.diferencia));
    final faltantes = vigentes
        .where((c) => c.resultado == ResultadoCierre.faltante)
        .length;

    return AppListaPagina<CierreRegistrado>(
      titulo: 'Cierres de caja',
      ruta: ruta,
      estado: ref.watch(cierresCajaProvider),
      visibles: ref.watch(cierresFiltradosProvider),
      busqueda: ref.watch(busquedaCierresProvider),
      onBuscar: (t) => ref.read(busquedaCierresProvider.notifier).state = t,
      pistaBusqueda: 'Buscar trabajador o caja',
      onRecargar: () async {
        ref.invalidate(cierresCajaProvider);
        try {
          await ref.read(cierresCajaProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.lock_clock_outlined,
      singular: 'cierre',
      plural: 'cierres',
      detalleVacio: 'No hay cierres de caja en estas fechas.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Faltantes por descontar',
          valor: formatoSoles(pendientes),
          icono: Icons.money_off_outlined,
          tono: pendientes > 0 ? DatoTono.peligro : DatoTono.neutral,
          nota: 'Entran en la próxima planilla',
        ),
        AppTarjetaDato(
          etiqueta: 'Cierres',
          valor: '${vigentes.length}',
          icono: Icons.lock_outline,
          color: color,
          nota: '$faltantes con faltante',
        ),
      ],
      encabezado: encabezado,
      filtro: BotonFiltros(
        activos: ref.watch(filtrosCierresActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, c) => _TarjetaCierre(
        cierre: c,
        color: color,
        onAnular: !c.anulado && puede(ref, 'finanzas.cierres', Accion.anular)
            ? () => _anular(context, ref, c)
            : null,
      ),
    );
  }

  Widget _paginaDigitales(
    BuildContext context,
    WidgetRef ref,
    Color color,
    Widget encabezado,
  ) {
    final estado = ref.watch(cobrosDigitalesProvider);
    final todos = estado.valueOrNull ?? const <CobroDigital>[];
    Iterable<CobroDigital> de(String e) => todos.where((c) => c.estado == e);
    double suma(Iterable<CobroDigital> l) =>
        l.fold<double>(0, (s, c) => s + c.monto);
    final pendientes = de(EstadoVerificacionPago.pendiente);
    final confirma = puede(ref, 'finanzas.cierres', Accion.confirmar);

    return AppListaPagina<CobroDigital>(
      titulo: 'Cierres de caja',
      ruta: ruta,
      estado: estado,
      visibles: ref.watch(cobrosDigitalesFiltradosProvider),
      busqueda: ref.watch(busquedaCobrosDigitalesProvider),
      onBuscar: (t) =>
          ref.read(busquedaCobrosDigitalesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar operación, venta o trabajador',
      onRecargar: () async {
        ref.invalidate(cobrosDigitalesProvider);
        try {
          await ref.read(cobrosDigitalesProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.smartphone_outlined,
      singular: 'cobro',
      plural: 'cobros',
      tituloVacio: 'Sin cobros digitales',
      detalleVacio: 'No hay cobros por Yape o transferencia en estas fechas.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Por verificar',
          valor: formatoSoles(suma(pendientes)),
          icono: Icons.schedule,
          tono: pendientes.isEmpty ? DatoTono.neutral : DatoTono.aviso,
          nota: '${pendientes.length}, de cualquier fecha',
        ),
        AppTarjetaDato(
          etiqueta: 'Verificado',
          valor: formatoSoles(suma(de(EstadoVerificacionPago.verificado))),
          icono: Icons.verified_outlined,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Rechazado',
          valor: formatoSoles(suma(de(EstadoVerificacionPago.rechazado))),
          icono: Icons.cancel_outlined,
          tono: DatoTono.peligro,
          nota: 'Se descuenta a quien cobró',
        ),
      ],
      encabezado: encabezado,
      filtro: BotonFiltros(
        activos: ref.watch(estadoCobrosDigitalesFiltroProvider) == null ? 0 : 1,
        color: color,
        onAbrir: () => _abrirFiltrosDigitales(context, ref),
      ),
      fila: (context, c) => _TarjetaCobro(
        cobro: c,
        color: color,
        onVerificar: confirma && c.estado == EstadoVerificacionPago.pendiente
            ? () => _verificar(context, ref, c)
            : null,
        onRechazar: confirma && c.estado == EstadoVerificacionPago.pendiente
            ? () => abrirHojaFinanzas(context, (_) => _HojaRechazo(cobro: c))
            : null,
        onQuitar: confirma && c.estado == EstadoVerificacionPago.verificado
            ? () => _quitarVerificacion(context, ref, c)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltrosDigitales(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(estadoCobrosDigitalesFiltroProvider) == null ? 0 : 1,
      onLimpiar: () =>
          ref.read(estadoCobrosDigitalesFiltroProvider.notifier).state = null,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoCobrosDigitalesFiltroProvider),
            opciones: [
              const OpcionFiltro<String?>(null, 'Todos'),
              for (final e in const [
                EstadoVerificacionPago.pendiente,
                EstadoVerificacionPago.verificado,
                EstadoVerificacionPago.rechazado,
              ])
                OpcionFiltro<String?>(e, EstadoVerificacionPago.etiqueta(e)),
            ],
            onCambio: (v) =>
                ref.read(estadoCobrosDigitalesFiltroProvider.notifier).state =
                    v,
          ),
        ),
      ],
    );
  }

  Future<void> _verificar(
    BuildContext context,
    WidgetRef ref,
    CobroDigital c,
  ) async {
    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).verificarCobro(c.id);
      ref.invalidate(cobrosDigitalesProvider);
      mensajero.mostrar('Operación ${c.numeroOperacion ?? ''} verificada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _quitarVerificacion(
    BuildContext context,
    WidgetRef ref,
    CobroDigital c,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Quitar la verificación',
      mensaje:
          'El cobro de ${formatoSoles(c.monto)} de la ${c.documento} vuelve a '
          'quedar por verificar.',
      textoConfirmar: 'Quitar',
      tono: ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).quitarVerificacion(c.id);
      ref.invalidate(cobrosDigitalesProvider);
      mensajero.mostrar('Vuelve a quedar por verificar');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosCierresActivosProvider),
      onLimpiar: () {
        ref.read(trabajadorCierresFiltroProvider.notifier).state = null;
        ref.read(resultadoCierresFiltroProvider.notifier).state = null;
        ref.read(descuentoCierresFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Resultado',
            valor: ref.watch(resultadoCierresFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro(ResultadoCierre.faltante, 'Faltante'),
              OpcionFiltro(ResultadoCierre.sobrante, 'Sobrante'),
              OpcionFiltro(ResultadoCierre.cuadro, 'Cuadró'),
            ],
            onCambio: (v) =>
                ref.read(resultadoCierresFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Descuento',
            valor: ref.watch(descuentoCierresFiltroProvider),
            opciones: [
              const OpcionFiltro<String?>(null, 'Todos'),
              for (final d in _descuentos.entries)
                OpcionFiltro<String?>(d.key, d.value),
            ],
            onCambio: (v) =>
                ref.read(descuentoCierresFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final trabajadores = ref.watch(trabajadoresCierresProvider);
            if (trabajadores.isEmpty) return const SizedBox.shrink();
            return GrupoFiltro<String?>(
              titulo: 'Trabajador',
              valor: ref.watch(trabajadorCierresFiltroProvider),
              opciones: [
                const OpcionFiltro<String?>(null, 'Todos'),
                for (final t in trabajadores) OpcionFiltro<String?>(t, t),
              ],
              onCambio: (v) =>
                  ref.read(trabajadorCierresFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    CierreRegistrado c,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular cierre',
      mensaje:
          'El cierre de ${c.usuario} del ${fechaHora(c.fecha)}. Se revierten la '
          'entrega y el ajuste, y su descuento se anula. Solo si fue un error de '
          'conteo: no se puede si el faltante ya se descontó en una planilla pagada.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).anularCierre(c.id);
      ref.invalidate(cierresCajaProvider);
      mensajero.mostrar('Cierre anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

/// Las pestañas y el rango de fechas, que comparten las dos listas.
class _Encabezado extends ConsumerWidget {
  const _Encabezado({required this.digitales, required this.onPestana});

  final bool digitales;
  final ValueChanged<bool> onPestana;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Cierres'),
                icon: Icon(Icons.lock_outline, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text('Cobros digitales'),
                icon: Icon(Icons.smartphone_outlined, size: 18),
              ),
            ],
            selected: {digitales},
            onSelectionChanged: (s) => onPestana(s.first),
          ),
          const SizedBox(height: Dimen.espacio2),
          AppSelectorRango(
            rango: ref.watch(rangoCierresProvider),
            textoVacio: 'Últimos 30 días',
            onCambio: (r) => ref.read(rangoCierresProvider.notifier).state = r,
          ),
        ],
      ),
    );
  }
}

/// Un cobro por Yape o transferencia, con lo que hace falta para buscarlo en
/// el banco: el numero de operacion, el monto y la cuenta.
class _TarjetaCobro extends StatelessWidget {
  const _TarjetaCobro({
    required this.cobro,
    required this.color,
    this.onVerificar,
    this.onRechazar,
    this.onQuitar,
  });

  final CobroDigital cobro;
  final Color color;
  final VoidCallback? onVerificar;
  final VoidCallback? onRechazar;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final c = cobro;
    final rechazado = c.estado == EstadoVerificacionPago.rechazado;

    return AppTarjetaRegistro(
      icono: c.metodoTipo == 'TRANSFERENCIA'
          ? Icons.swap_horiz
          : Icons.smartphone_outlined,
      color: color,
      titulo: c.usuario ?? '—',
      insignia: AppEtiqueta(
        EstadoVerificacionPago.etiqueta(c.estado),
        tono: rechazado
            ? EtiquetaTono.peligro
            : c.estado == EstadoVerificacionPago.pendiente
            ? EtiquetaTono.aviso
            : EtiquetaTono.exito,
      ),
      campos: [
        CampoDetalle(
          'N° operación',
          null,
          widget: Text(
            c.numeroOperacion ?? 'Sin número',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.numeroOperacion == null
                  ? Colores.tintaSuave
                  : Colores.tinta,
            ),
          ),
        ),
        CampoDetalle('Monto', formatoSoles(c.monto)),
        CampoDetalle('Cuenta', c.cuenta),
        CampoDetalle('Método', c.metodoPago),
        CampoDetalle(
          'Venta',
          c.cliente == null ? c.documento : '${c.documento} · ${c.cliente}',
        ),
        CampoDetalle('Fecha', fechaHora(c.fecha)),
        if (c.verificadoPor != null)
          CampoDetalle(
            rechazado ? 'Rechazado por' : 'Verificado por',
            c.verificadoEn == null
                ? c.verificadoPor
                : '${c.verificadoPor} · ${fechaHora(c.verificadoEn!)}',
          ),
        if (c.observacion != null) CampoDetalle('Motivo', c.observacion),
        if (c.estadoDescuento != null)
          CampoDetalle(
            'Descuento',
            c.sinEmpleado
                ? '${_descuentos[c.estadoDescuento] ?? c.estadoDescuento} · sin empleado vinculado'
                : c.estadoDescuento == 'PENDIENTE' && c.saldoDescuento != null
                ? 'Pendiente · ${formatoSoles(c.saldoDescuento!)}'
                : _descuentos[c.estadoDescuento] ?? c.estadoDescuento,
          ),
      ],
      acciones: [
        if (onVerificar != null)
          IconButton(
            onPressed: onVerificar,
            tooltip: 'Verificar: apareció en el banco',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: Colores.exito,
            ),
          ),
        if (onRechazar != null)
          IconButton(
            onPressed: onRechazar,
            tooltip: 'Rechazar: no apareció',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.cancel_outlined,
              size: 18,
              color: Colores.peligro,
            ),
          ),
        if (onQuitar != null)
          IconButton(
            onPressed: onQuitar,
            tooltip: 'Quitar la verificación',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.undo, size: 18, color: Colores.tintaSuave),
          ),
      ],
    );
  }
}

/// Rechazar un cobro que no aparecio en el banco: por que.
class _HojaRechazo extends ConsumerStatefulWidget {
  const _HojaRechazo({required this.cobro});

  final CobroDigital cobro;

  @override
  ConsumerState<_HojaRechazo> createState() => _HojaRechazoState();
}

class _HojaRechazoState extends ConsumerState<_HojaRechazo> {
  final _motivo = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _rechazar() async {
    FocusScope.of(context).unfocus();
    final motivo = _motivo.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'Di por qué se rechaza.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref
          .read(tesoreriaApiProvider)
          .rechazarCobro(widget.cobro.id, motivo);
      ref.invalidate(cobrosDigitalesProvider);
      navegador.pop();
      mensajero.mostrar('Cobro rechazado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cobro;
    final operacion = c.numeroOperacion == null
        ? ''
        : ', operación ${c.numeroOperacion}';

    return Padding(
      padding: margenHoja(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloHoja(
            'Rechazar el cobro de ${formatoSoles(c.monto)}',
            apoyo:
                '${c.usuario ?? 'Alguien'} lo registró por ${c.metodoPago} en '
                'la ${c.documento}$operacion.',
          ),
          AppAlerta(
            'Sale de ${c.cuenta ?? 'la cuenta'} y '
            '${c.usuarioId == null ? 'no se sabe quién lo cobró: no se le descuenta a nadie' : 'se le descuenta a ${c.usuario} en su planilla'}. '
            'La venta sigue cobrada. No se puede deshacer.',
            tono: AlertaTono.aviso,
          ),
          const SizedBox(height: Dimen.espacio3),
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          AppCampo(
            controlador: _motivo,
            etiqueta: 'Motivo',
            icono: Icons.edit_note,
            pista: 'No aparece en el banco, llegó otro monto...',
            maxLargo: 250,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio5),
          AppBoton(
            texto: 'Rechazar',
            icono: Icons.cancel_outlined,
            cargando: _guardando,
            onPressed: _rechazar,
          ),
        ],
      ),
    );
  }
}

class _TarjetaCierre extends StatelessWidget {
  const _TarjetaCierre({
    required this.cierre,
    required this.color,
    this.onAnular,
  });

  final CierreRegistrado cierre;
  final Color color;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    final c = cierre;
    final d = c.diferencia;

    return AppTarjetaRegistro(
      icono: Icons.lock_outline,
      color: color,
      titulo: c.usuario,
      insignia: c.anulado
          ? const AppEtiqueta('Anulado', tono: EtiquetaTono.neutral)
          : AppEtiqueta(
              ResultadoCierre.etiqueta(c.resultado),
              tono: switch (c.resultado) {
                ResultadoCierre.faltante => EtiquetaTono.peligro,
                ResultadoCierre.sobrante => EtiquetaTono.aviso,
                _ => EtiquetaTono.exito,
              },
            ),
      campos: [
        CampoDetalle('Fecha', fechaHora(c.fecha)),
        CampoDetalle('Caja', c.caja),
        CampoDetalle('Debía tener', formatoSoles(c.saldoSistema)),
        CampoDetalle('Contado', formatoSoles(c.contado)),
        CampoDetalle(
          'Diferencia',
          null,
          widget: Text(
            d == 0 ? '—' : '${d > 0 ? '+' : '-'}${formatoSoles(d.abs())}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: d < 0
                  ? Colores.peligro
                  : d > 0
                  ? Colores.advertencia
                  : Colores.exito,
            ),
          ),
        ),
        CampoDetalle('Entregado a', c.cuentaDestino),
        CampoDetalle(
          'Descuento',
          c.estadoDescuento == null
              ? null
              : c.sinEmpleado
              ? '${_descuentos[c.estadoDescuento] ?? c.estadoDescuento} · sin empleado vinculado'
              : _descuentos[c.estadoDescuento] ?? c.estadoDescuento,
        ),
        CampoDetalle('Observación', c.observacion),
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
