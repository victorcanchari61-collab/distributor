import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_aviso.dart';
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
