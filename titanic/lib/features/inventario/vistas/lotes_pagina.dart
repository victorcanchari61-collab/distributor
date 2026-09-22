import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../datos/lote.dart';
import '../estado/inventario_controlador.dart';

/// Lotes y vencimientos: todo lo que tiene fecha de vencimiento y todavía
/// tiene stock, lo más próximo primero.
///
/// Es solo informativo — avisa, no bloquea. La decisión de vender o dar de
/// baja un lote vencido la toma la persona, normalmente con un ajuste de
/// motivo "Vencimiento".
class LotesPagina extends ConsumerWidget {
  const LotesPagina({super.key});

  static const ruta = '/inv/lotes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(lotesProvider).valueOrNull ?? const <Lote>[];
    final vencidos = todos.where((l) => l.vencido).length;
    final porVencer = todos.where((l) => l.porVencer).length;

    return AppListaPagina<Lote>(
      titulo: 'Lotes y vencimientos',
      ruta: ruta,
      estado: ref.watch(lotesProvider),
      visibles: ref.watch(lotesFiltradosProvider),
      busqueda: ref.watch(busquedaLotesProvider),
      onBuscar: (t) => ref.read(busquedaLotesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por producto, lote o almacén',
      onRecargar: () async {
        ref.invalidate(lotesProvider);
        await ref.read(lotesProvider.future);
      },
      iconoVacio: Icons.event_outlined,
      singular: 'lote',
      plural: 'lotes',
      detalleVacio: 'No hay lotes con fecha de vencimiento registrados.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Con vencimiento',
          valor: '${todos.length}',
          icono: Icons.event_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Por vencer',
          valor: '$porVencer',
          icono: Icons.warning_amber_outlined,
          tono: porVencer > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Vencidos',
          valor: '$vencidos',
          icono: Icons.error_outline,
          tono: vencidos > 0 ? DatoTono.peligro : DatoTono.neutral,
        ),
      ],
      filtro: BotonFiltros(
        activos: ref.watch(filtrosLotesActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, lote) => _TarjetaLote(lote: lote, color: color),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosLotesActivosProvider),
      onLimpiar: () {
        ref.read(filtroLoteProvider.notifier).state = FiltroLote.todos;
        ref.read(productoLoteFiltroProvider.notifier).state = null;
        ref.read(almacenLoteFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroLote>(
            titulo: 'Vencimiento',
            valor: ref.watch(filtroLoteProvider),
            opciones: const [
              OpcionFiltro(FiltroLote.todos, 'Todos'),
              OpcionFiltro(FiltroLote.vencidos, 'Vencidos'),
              OpcionFiltro(FiltroLote.porVencer, 'Por vencer'),
              OpcionFiltro(FiltroLote.vigentes, 'Vigentes'),
            ],
            onCambio: (v) => ref.read(filtroLoteProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final productos = ref.watch(productosDeLotesProvider);
            if (productos.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Producto',
              valor: ref.watch(productoLoteFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final p in productos) OpcionFiltro(p, p),
              ],
              onCambio: (v) =>
                  ref.read(productoLoteFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final almacenes = ref.watch(almacenesDeLotesProvider);
            if (almacenes.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Almacén',
              valor: ref.watch(almacenLoteFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final a in almacenes) OpcionFiltro(a, a),
              ],
              onCambio: (v) =>
                  ref.read(almacenLoteFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }
}

class _TarjetaLote extends StatelessWidget {
  const _TarjetaLote({required this.lote, required this.color});

  final Lote lote;
  final Color color;

  ({String texto, EtiquetaTono tono}) get _estado {
    final dias = lote.diasParaVencer;
    if (dias == null) return (texto: 'Sin fecha', tono: EtiquetaTono.neutral);
    if (dias < 0)
      return (texto: 'Vencido hace ${-dias} días', tono: EtiquetaTono.peligro);
    if (dias <= diasAlertaVencimiento) {
      return (texto: 'Vence en $dias días', tono: EtiquetaTono.aviso);
    }
    return (texto: 'Vigente', tono: EtiquetaTono.exito);
  }

  List<CampoDetalle> get _campos {
    final estado = _estado;
    return [
      CampoDetalle('Almacén', lote.almacen),
      CampoDetalle('Lote', lote.lote),
      CampoDetalle(
        'Vence',
        lote.fechaVencimiento == null ? null : _fecha(lote.fechaVencimiento!),
      ),
      CampoDetalle(
        'Estado',
        estado.texto,
        widget: AppEtiqueta(estado.texto, tono: estado.tono),
      ),
      CampoDetalle('Stock', '${lote.cantidadDisponible} ${lote.unidadBase}'),
      CampoDetalle(
        'Valorizado',
        'S/ ${lote.valor.toStringAsFixed(2)}',
        enTarjeta: false,
      ),
      CampoDetalle(
        'Costo unitario',
        'S/ ${lote.costoUnitario.toStringAsFixed(2)}',
        enTarjeta: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.event_outlined,
      color: color,
      titulo: lote.producto,
      insignia: AppEtiqueta(lote.codigo),
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.event_outlined,
        color: color,
        titulo: lote.producto,
        subtitulo: lote.codigo,
        campos: _campos,
      ),
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
