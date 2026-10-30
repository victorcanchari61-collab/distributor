import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector_rango.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/vistas/categorizacion_hoja.dart';
import '../datos/crm.dart';
import '../estado/crm_controlador.dart';
import 'crm_comun.dart';

/// Los valores distintos de un campo, ordenados: las opciones de un filtro.
List<String> distintos(Iterable<String?> valores) =>
    ({...valores.whereType<String>()}.toList()..sort());

/// Clientes con caída: lo que compró cada cliente del 1 de enero a hoy (o el
/// tramo que se elija) contra el mismo tramo del año anterior, y en qué estado
/// está por cuánto cayó.
///
/// Las tarjetas de estado son filtros: tocar una deja solo esos clientes. Desde
/// cada cliente se abre Gestión y seguimiento ya con él elegido.
class CaidaPagina extends ConsumerWidget {
  const CaidaPagina({super.key});

  static const ruta = '/crm/caida';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final estado = ref.watch(caidaProvider);
    final datos = estado.valueOrNull;
    final vendedor = ref.watch(vendedorCaidaFiltroProvider);
    final mercado = ref.watch(mercadoCaidaFiltroProvider);
    final inactividad = ref.watch(inactividadCaidaFiltroProvider);

    return AppListaPagina<FilaCaida>(
      titulo: 'Clientes con caída',
      ruta: ruta,
      estado: estado.whenData((d) => d.items),
      visibles: ref.watch(caidaFiltradaProvider),
      busqueda: ref.watch(busquedaCaidaProvider),
      onBuscar: (t) => ref.read(busquedaCaidaProvider.notifier).state = t,
      pistaBusqueda: 'Buscar cliente, documento o vendedor',
      onRecargar: () async {
        ref.invalidate(caidaProvider);
        try {
          await ref.read(caidaProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.trending_down,
      singular: 'cliente',
      plural: 'clientes',
      tituloVacio: 'Sin clientes',
      detalleVacio: 'No hay clientes con ventas en este tramo.',
      encabezado: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
            child: AppSelectorRango(
              rango: ref.watch(rangoCaidaProvider),
              textoVacio: 'Del 1 de enero a hoy',
              onCambio: (r) => ref.read(rangoCaidaProvider.notifier).state = r,
            ),
          ),
          if (datos != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio4,
                Dimen.espacio2,
                Dimen.espacio4,
                Dimen.espacio2,
              ),
              child: Text(
                'Del ${datos.periodo.etiqueta} frente al '
                '${datos.periodo.etiquetaAnterior}. '
                '${soles(datos.ventaActual)} vendidos y ${soles(datos.ventaAnterior)} el año anterior.',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
          TarjetasEstado(
            estados: datos?.estados ?? const [],
            activo: ref.watch(estadoCaidaFiltroProvider),
            onCambio: (e) =>
                ref.read(estadoCaidaFiltroProvider.notifier).state = e,
            nota: (r) => switch (r.estado) {
              EstadoCaida.sinBase => 'no compraron antes',
              EstadoCaida.normal => 'igual o casi',
              _ => '${soles(r.monto)} en riesgo',
            },
          ),
        ],
      ),
      filtro: BotonFiltros(
        activos:
            (vendedor == null ? 0 : 1) +
            (mercado == null ? 0 : 1) +
            (inactividad == null ? 0 : 1),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref, datos?.items ?? const []),
      ),
      fila: (context, f) => _TarjetaCaida(fila: f, color: color),
    );
  }

  Future<void> _abrirFiltros(
    BuildContext context,
    WidgetRef ref,
    List<FilaCaida> items,
  ) {
    final vendedores = distintos(items.map((f) => f.vendedor));
    final mercados = distintos(items.map((f) => f.mercado));

    return mostrarFiltros(
      context,
      activos:
          (ref.read(vendedorCaidaFiltroProvider) == null ? 0 : 1) +
          (ref.read(mercadoCaidaFiltroProvider) == null ? 0 : 1) +
          (ref.read(inactividadCaidaFiltroProvider) == null ? 0 : 1),
      onLimpiar: () {
        ref.read(vendedorCaidaFiltroProvider.notifier).state = null;
        ref.read(mercadoCaidaFiltroProvider.notifier).state = null;
        ref.read(inactividadCaidaFiltroProvider.notifier).state = null;
      },
      grupos: [
        // Los que dejaron de comprar: por cuántos días llevan sin hacerlo.
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<TramoInactividad?>(
            titulo: 'Sin comprar hace',
            valor: ref.watch(inactividadCaidaFiltroProvider),
            opciones: [
              const OpcionFiltro(null, 'Cualquiera'),
              for (final t in TramoInactividad.values)
                OpcionFiltro(t, t.etiqueta),
            ],
            onCambio: (v) =>
                ref.read(inactividadCaidaFiltroProvider.notifier).state = v,
          ),
        ),
        if (vendedores.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => GrupoFiltro<String?>(
              titulo: 'Vendedor',
              valor: ref.watch(vendedorCaidaFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final v in vendedores) OpcionFiltro(v, v),
              ],
              onCambio: (v) =>
                  ref.read(vendedorCaidaFiltroProvider.notifier).state = v,
            ),
          ),
        if (mercados.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => GrupoFiltro<String?>(
              titulo: 'Mercado',
              valor: ref.watch(mercadoCaidaFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final m in mercados) OpcionFiltro(m, m),
              ],
              onCambio: (v) =>
                  ref.read(mercadoCaidaFiltroProvider.notifier).state = v,
            ),
          ),
      ],
    );
  }
}

class _TarjetaCaida extends StatelessWidget {
  const _TarjetaCaida({required this.fila, required this.color});

  final FilaCaida fila;
  final Color color;

  void _gestionar(BuildContext context) =>
      context.push('/crm/seguimiento?cliente=${fila.id}&pestana=seguimiento');

  @override
  Widget build(BuildContext context) {
    final f = fila;

    return AppTarjetaRegistro(
      icono: Icons.storefront_outlined,
      color: color,
      titulo: f.cliente,
      insignia: EtiquetaEstadoCaida(f.estado),
      onTap: () => _gestionar(context),
      campos: [
        CampoDetalle(
          'Cliente',
          '${f.codigo} · ${f.documento}',
          widget: f.categoriaCodigo == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${f.codigo} · ${f.documento}  ',
                      style: const TextStyle(fontSize: 12),
                    ),
                    InsigniaCategoria(
                      codigo: f.categoriaCodigo!,
                      color: f.categoriaColor,
                    ),
                  ],
                ),
        ),
        CampoDetalle('Vendedor', f.vendedor),
        CampoDetalle('Mercado', f.mercado),
        CampoDetalle(
          'Última compra',
          f.ultimaCompra == null
              ? 'Nunca'
              : '${fechaDia(f.ultimaCompra)} · hace ${f.diasSinCompra} días',
          widget: f.ultimaCompra == null
              ? null
              : Text(
                  '${fechaDia(f.ultimaCompra)} · hace ${f.diasSinCompra} días',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorDeDias(f.diasSinCompra),
                  ),
                ),
        ),
        CampoDetalle(
          'Venta',
          '${soles(f.ventaActual)} (antes ${soles(f.ventaAnterior)})',
        ),
        CampoDetalle(
          'Variación',
          null,
          widget: Text(
            '${solesConSigno(f.variacion)}  ·  '
            '${f.caidaPct == null ? 'Sin comparación' : porcentaje(-f.caidaPct!)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorCambio(f.variacion),
            ),
          ),
        ),
        if (f.montoRiesgo > 0)
          CampoDetalle(
            'En riesgo',
            null,
            widget: Text(
              soles(f.montoRiesgo),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colores.peligro,
              ),
            ),
          ),
        CampoDetalle(
          'Gestión',
          f.gestionEtiqueta == null ? 'Sin gestiones' : f.gestionEtiqueta,
          widget: f.proximoSeguimiento == null
              ? null
              : Text(
                  '${f.gestionEtiqueta ?? 'Sin gestiones'} · '
                  '${f.seguimientoVencido ? 'vencido' : 'próximo'} '
                  '${fechaDia(f.proximoSeguimiento)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: f.seguimientoVencido
                        ? Colores.peligro
                        : Colores.tinta,
                  ),
                ),
        ),
      ],
      acciones: [
        IconButton(
          onPressed: () => mostrarQueDejoDeComprar(
            context,
            clienteId: f.id,
            cliente: f.cliente,
          ),
          tooltip: 'Qué dejó de comprar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.inventory_2_outlined,
            size: 19,
            color: Acento.de(context),
          ),
        ),
        if (f.telefono != null && f.telefono!.trim().isNotEmpty)
          IconButton(
            onPressed: () => abrirWhatsapp(context, f.telefono!),
            tooltip: 'WhatsApp',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.chat_outlined,
              size: 19,
              color: Colores.exito,
            ),
          ),
        IconButton(
          onPressed: () => _gestionar(context),
          tooltip: 'Gestionar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.person_search_outlined,
            size: 19,
            color: Acento.de(context),
          ),
        ),
      ],
    );
  }
}
