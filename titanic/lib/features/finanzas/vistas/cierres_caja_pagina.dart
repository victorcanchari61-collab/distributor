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
import '../datos/mi_caja.dart' show DocumentoMovimiento;
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
/// Cada cierre se revisa entero en su detalle: el efectivo que paso por la
/// caja, lo cobrado por Yape o transferencia —que se verifica ahi contra el
/// banco— y los billetes y monedas que se contaron.
class CierresCajaPagina extends ConsumerWidget {
  const CierresCajaPagina({super.key});

  static const ruta = '/finanzas/cierres';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
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
    final porVerificar = vigentes.fold<int>(
      0,
      (n, c) => n + c.digitalPorVerificar,
    );

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
        AppTarjetaDato(
          etiqueta: 'Digital por verificar',
          valor: '$porVerificar',
          icono: Icons.smartphone_outlined,
          tono: porVerificar > 0 ? DatoTono.aviso : DatoTono.neutral,
          nota: 'Cobros a buscar en el banco',
        ),
      ],
      encabezado: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
        child: AppSelectorRango(
          rango: ref.watch(rangoCierresProvider),
          textoVacio: 'Últimos 30 días',
          onCambio: (r) => ref.read(rangoCierresProvider.notifier).state = r,
        ),
      ),
      filtro: BotonFiltros(
        activos: ref.watch(filtrosCierresActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, c) => _TarjetaCierre(
        cierre: c,
        color: color,
        onVer: () => abrirHojaFinanzas(
          context,
          (_) => _HojaDetalleCierre(cierreId: c.id),
        ),
        onAnular: !c.anulado && puede(ref, 'finanzas.cierres', Accion.anular)
            ? () => _anular(context, ref, c)
            : null,
      ),
    );
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
      ref.invalidate(detalleCierreProvider);
      ref.invalidate(cierresCajaProvider);
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
    required this.onVer,
    this.onAnular,
  });

  final CierreRegistrado cierre;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    final c = cierre;
    final d = c.diferencia;

    return AppTarjetaRegistro(
      icono: Icons.lock_outline,
      color: color,
      titulo: c.usuario,
      onTap: onVer,
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
          'Digital',
          c.digital == 0 && c.digitalRechazados == 0
              ? null
              : formatoSoles(c.digital),
        ),
        if (c.digitalPorVerificar > 0 || c.digitalRechazados > 0)
          CampoDetalle(
            'Verificación',
            null,
            widget: Wrap(
              spacing: Dimen.espacio1,
              runSpacing: Dimen.espacio1,
              children: [
                if (c.digitalPorVerificar > 0)
                  AppEtiqueta(
                    '${c.digitalPorVerificar} por verificar',
                    tono: EtiquetaTono.aviso,
                  ),
                if (c.digitalRechazados > 0)
                  AppEtiqueta(
                    '${c.digitalRechazados} ${c.digitalRechazados == 1 ? 'rechazado' : 'rechazados'}',
                    tono: EtiquetaTono.peligro,
                  ),
              ],
            ),
          ),
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
        IconButton(
          onPressed: onVer,
          tooltip: 'Ver el detalle del cierre',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.visibility_outlined, size: 18, color: color),
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

/// Un cierre entero, para revisar si cuadra: el efectivo que paso por la caja
/// desde el cierre anterior, lo cobrado por Yape o transferencia —que se busca
/// en el banco y se verifica o se rechaza aqui mismo— y los billetes y monedas
/// que se contaron. Igual que el detalle del panel web.
class _HojaDetalleCierre extends ConsumerStatefulWidget {
  const _HojaDetalleCierre({required this.cierreId});

  final int cierreId;

  @override
  ConsumerState<_HojaDetalleCierre> createState() => _HojaDetalleCierreState();
}

enum _Parte { efectivo, digital, billetes }

class _HojaDetalleCierreState extends ConsumerState<_HojaDetalleCierre> {
  _Parte _parte = _Parte.efectivo;

  void _refrescar() {
    ref.invalidate(detalleCierreProvider(widget.cierreId));
    ref.invalidate(cierresCajaProvider);
  }

  Future<void> _verificar(CobroDigital c) async {
    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).verificarCobro(c.id);
      _refrescar();
      mensajero.mostrar('Operación ${c.numeroOperacion ?? ''} verificada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _quitarVerificacion(CobroDigital c) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Quitar la verificación',
      mensaje:
          'El cobro de ${formatoSoles(c.monto)} de la ${c.documento} vuelve a '
          'quedar por verificar.',
      textoConfirmar: 'Quitar',
      tono: ConfirmTono.pregunta,
    );
    if (!ok || !mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).quitarVerificacion(c.id);
      _refrescar();
      mensajero.mostrar('Vuelve a quedar por verificar');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(detalleCierreProvider(widget.cierreId));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Padding(
        padding: margenHoja(context),
        child: detalle.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Dimen.espacio5),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppAlerta(
            e is ApiExcepcion ? e.texto : 'No pudimos cargar el cierre.',
          ),
          data: _contenido,
        ),
      ),
    );
  }

  Widget _contenido(CierreDetalle d) {
    final c = d.cierre;
    final vigentes = d.efectivo.where((m) => m.vigente);
    final entro = vigentes
        .where((m) => m.esIngreso)
        .fold<double>(0, (s, m) => s + m.monto);
    final salio = vigentes
        .where((m) => !m.esIngreso)
        .fold<double>(0, (s, m) => s + m.monto);
    final dif = c.diferencia;
    final confirma = puede(ref, 'finanzas.cierres', Accion.confirmar);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloHoja(
          'Cierre de ${c.usuario}',
          apoyo:
              '${c.caja} · ${d.desde == null ? 'desde el inicio' : 'del ${fechaHora(d.desde!)}'} '
              'al ${fechaHora(c.fecha)}',
        ),
        if (c.anulado) ...[
          const AppAlerta(
            'Este cierre está anulado: la plata volvió a la caja y entra en el siguiente.',
            tono: AlertaTono.aviso,
          ),
          const SizedBox(height: Dimen.espacio3),
        ],
        // Lo que se revisa de un vistazo: si cuadró y cuánto fue digital.
        Wrap(
          spacing: Dimen.espacio2,
          runSpacing: Dimen.espacio2,
          children: [
            _Cifra(
              'Debía tener',
              formatoSoles(c.saldoSistema),
              d.saldoAnterior != 0
                  ? 'Venía ${formatoSoles(d.saldoAnterior)} de antes'
                  : 'Entró ${formatoSoles(entro)} · salió ${formatoSoles(salio)}',
            ),
            _Cifra('Contado', formatoSoles(c.contado), 'A ${c.cuentaDestino}'),
            _Cifra(
              ResultadoCierre.etiqueta(c.resultado),
              dif == 0
                  ? formatoSoles(0)
                  : '${dif > 0 ? '+' : '-'}${formatoSoles(dif.abs())}',
              c.estadoDescuento == null ? null : _descuentos[c.estadoDescuento],
              color: dif < 0
                  ? Colores.peligro
                  : dif > 0
                  ? Colores.advertencia
                  : Colores.exito,
            ),
            _Cifra(
              'Cobrado digital',
              formatoSoles(c.digital),
              c.digitalPorVerificar > 0
                  ? '${c.digitalPorVerificar} por verificar'
                  : d.digitales.isEmpty
                  ? 'Sin cobros digitales'
                  : 'Todo revisado',
              color: c.digitalPorVerificar > 0 ? Colores.advertencia : null,
            ),
          ],
        ),
        const SizedBox(height: Dimen.espacio3),
        SegmentedButton<_Parte>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _Parte.efectivo,
              label: Text('Efectivo (${d.efectivo.length})'),
            ),
            ButtonSegment(
              value: _Parte.digital,
              label: Text('Digital (${d.digitales.length})'),
            ),
            const ButtonSegment(
              value: _Parte.billetes,
              label: Text('Billetes'),
            ),
          ],
          selected: {_parte},
          onSelectionChanged: (s) => setState(() => _parte = s.first),
        ),
        const SizedBox(height: Dimen.espacio3),
        Flexible(
          child: SingleChildScrollView(
            child: switch (_parte) {
              _Parte.efectivo => _Efectivo(movimientos: d.efectivo),
              _Parte.digital => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (d.digitales.isEmpty)
                    const _Vacio(
                      'No cobró nada por Yape o transferencia en este periodo.',
                    ),
                  for (final cobro in d.digitales) ...[
                    _TarjetaCobro(
                      cobro: cobro,
                      color: Colores.marca,
                      onVerificar:
                          confirma &&
                              cobro.estado == EstadoVerificacionPago.pendiente
                          ? () => _verificar(cobro)
                          : null,
                      onRechazar:
                          confirma &&
                              cobro.estado == EstadoVerificacionPago.pendiente
                          ? () => abrirHojaFinanzas(
                              context,
                              (_) => _HojaRechazo(cobro: cobro),
                            )
                          : null,
                      onQuitar:
                          confirma &&
                              cobro.estado == EstadoVerificacionPago.verificado
                          ? () => _quitarVerificacion(cobro)
                          : null,
                    ),
                    const SizedBox(height: Dimen.espacio2),
                  ],
                ],
              ),
              _Parte.billetes => _Billetes(detalle: d),
            },
          ),
        ),
      ],
    );
  }
}

/// Un numero del resumen del cierre: que es, cuanto y una linea de apoyo.
class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor, this.nota, {this.color});

  final String etiqueta;
  final String valor;
  final String? nota;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Dos por fila en el telefono.
    final ancho =
        (MediaQuery.sizeOf(context).width - Dimen.espacio4 * 2 - 8) / 2;
    return Container(
      width: ancho,
      padding: const EdgeInsets.all(Dimen.espacio2),
      decoration: BoxDecoration(
        color: Colores.fondo,
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color ?? Colores.tinta,
            ),
          ),
          if (nota != null) ...[
            const SizedBox(height: 2),
            Text(
              nota!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colores.tintaSuave),
            ),
          ],
        ],
      ),
    );
  }
}

/// El efectivo del periodo: cada cobro, pago o gasto que paso por la caja.
class _Efectivo extends StatelessWidget {
  const _Efectivo({required this.movimientos});

  final List<MovimientoCierre> movimientos;

  @override
  Widget build(BuildContext context) {
    if (movimientos.isEmpty) {
      return const _Vacio('No hubo movimientos de efectivo en este periodo.');
    }
    return Column(
      children: [
        for (var i = 0; i < movimientos.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _FilaEfectivo(m: movimientos[i]),
        ],
      ],
    );
  }
}

class _FilaEfectivo extends StatelessWidget {
  const _FilaEfectivo({required this.m});

  final MovimientoCierre m;

  @override
  Widget build(BuildContext context) {
    final tachado = !m.vigente;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DocumentoMovimiento.etiqueta(m.documentoOrigen),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [
                    fechaHora(m.fecha),
                    if (m.detalle != null) m.detalle!,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colores.tintaSuave,
                  ),
                ),
                if (tachado) ...[
                  const SizedBox(height: 2),
                  AppEtiqueta(
                    m.esReversa ? 'Reversa' : 'Anulado',
                    tono: EtiquetaTono.neutral,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Dimen.espacio2),
          Text(
            '${m.esIngreso ? '+' : '-'}${formatoSoles(m.monto)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              decoration: tachado ? TextDecoration.lineThrough : null,
              color: tachado
                  ? Colores.tintaSuave
                  : m.esIngreso
                  ? Colores.exito
                  : Colores.peligro,
            ),
          ),
        ],
      ),
    );
  }
}

/// Los billetes y monedas que se contaron, con el mismo formato que al cerrar.
class _Billetes extends StatelessWidget {
  const _Billetes({required this.detalle});

  final CierreDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final c = detalle.cierre;
    const suave = TextStyle(fontSize: 12, color: Colores.tintaSuave);
    const texto = TextStyle(fontSize: 12.5, color: Colores.tinta);

    Widget linea(String etiqueta, double monto, {bool fuerte = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta,
                  textAlign: TextAlign.right,
                  style: fuerte
                      ? texto.copyWith(fontWeight: FontWeight.w700)
                      : suave,
                ),
              ),
              const SizedBox(width: Dimen.espacio4),
              SizedBox(
                width: 96,
                child: Text(
                  formatoSoles(monto),
                  textAlign: TextAlign.right,
                  style: fuerte
                      ? texto.copyWith(fontWeight: FontWeight.w800)
                      : suave,
                ),
              ),
            ],
          ),
        );

    if (detalle.denominaciones.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Vacio(
            c.contado == 0
                ? 'No contó efectivo en este cierre.'
                : 'Este cierre se hizo antes de guardar el desglose: solo se sabe el total.',
          ),
          linea('Billetes', c.billetes),
          linea('Monedas', c.monedas),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < detalle.denominaciones.length; i++)
            Container(
              color: i.isOdd ? Colores.fondo : null,
              padding: const EdgeInsets.symmetric(
                horizontal: Dimen.espacio3,
                vertical: 6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${detalle.denominaciones[i].esBillete ? 'Billete' : 'Moneda'} '
                      '${formatoSoles(detalle.denominaciones[i].valor)}',
                      style: texto,
                    ),
                  ),
                  Text('× ${detalle.denominaciones[i].cantidad}', style: suave),
                  const SizedBox(width: Dimen.espacio4),
                  SizedBox(
                    width: 80,
                    child: Text(
                      detalle.denominaciones[i].total.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: texto.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Dimen.espacio3),
            child: Column(
              children: [
                linea('Billetes', c.billetes),
                linea('Monedas', c.monedas),
                linea('Total contado', c.contado, fuerte: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Dimen.espacio4),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
      ),
    );
  }
}
