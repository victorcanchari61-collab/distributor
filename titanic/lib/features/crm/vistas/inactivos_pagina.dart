import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../maestros/vistas/categorizacion_hoja.dart';
import '../datos/crm.dart';
import '../estado/crm_controlador.dart';
import 'caida_pagina.dart' show distintos;
import 'crm_comun.dart';

/// Los estados que tiene sentido ver aquí: quien compró hace menos de 16 días
/// no está inactivo.
const _estadosInactivos = [
  EstadoCaida.critico,
  EstadoCaida.riesgo,
  EstadoCaida.seguimiento,
];

/// El rango de días de cada estado.
const _rangoDias = {
  EstadoCaida.critico: '61 días o más',
  EstadoCaida.riesgo: '31 - 60 días',
  EstadoCaida.seguimiento: '16 - 30 días',
};

/// Clientes inactivos: quienes compraron alguna vez pero llevan días sin
/// hacerlo, por cuántos días. No compara años: mide el silencio. Cada cliente
/// abre Gestión y seguimiento para llamar, escribir o programar la visita.
class InactivosPagina extends ConsumerWidget {
  const InactivosPagina({super.key});

  static const ruta = '/crm/inactivos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final estado = ref.watch(inactivosProvider);
    final datos = estado.valueOrNull;
    final vendedor = ref.watch(vendedorInactivosFiltroProvider);
    final mercado = ref.watch(mercadoInactivosFiltroProvider);

    return AppListaPagina<FilaInactivo>(
      titulo: 'Clientes inactivos',
      ruta: ruta,
      estado: estado.whenData((d) => d.items),
      visibles: ref.watch(inactivosFiltradosProvider),
      busqueda: ref.watch(busquedaInactivosProvider),
      onBuscar: (t) => ref.read(busquedaInactivosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar cliente, documento o vendedor',
      onRecargar: () async {
        ref.invalidate(inactivosProvider);
        try {
          await ref.read(inactivosProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.person_off_outlined,
      singular: 'cliente',
      plural: 'clientes',
      tituloVacio: 'Sin inactivos',
      detalleVacio: 'No hay clientes inactivos con estos filtros.',
      encabezado: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Dimen.espacio4),
            child: Text(
              'Días sin comprar: 0-15 normal · 16-30 seguimiento · 31-60 en '
              'riesgo · 61 o más crítico.',
              style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
          ),
          const SizedBox(height: Dimen.espacio2),
          TarjetasEstado(
            estados: datos?.estados ?? const [],
            soloEstos: _estadosInactivos,
            activo: ref.watch(estadoInactivosFiltroProvider),
            onCambio: (e) =>
                ref.read(estadoInactivosFiltroProvider.notifier).state = e,
            nota: (r) => _rangoDias[r.estado] ?? '',
          ),
          if (datos != null && datos.nuncaCompraron > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio4,
                Dimen.espacio2,
                Dimen.espacio4,
                0,
              ),
              child: AppAlerta(
                '${datos.nuncaCompraron} '
                '${datos.nuncaCompraron == 1 ? 'cliente activo nunca compró' : 'clientes activos nunca compraron'}: '
                'no salen aquí porque no hay una compra de la que contar los '
                'días.',
                tono: AlertaTono.aviso,
              ),
            ),
        ],
      ),
      filtro: BotonFiltros(
        activos: (vendedor == null ? 0 : 1) + (mercado == null ? 0 : 1),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref, datos?.items ?? const []),
      ),
      fila: (context, f) => _TarjetaInactivo(fila: f, color: color),
    );
  }

  Future<void> _abrirFiltros(
    BuildContext context,
    WidgetRef ref,
    List<FilaInactivo> items,
  ) {
    final vendedores = distintos(items.map((f) => f.vendedor));
    final mercados = distintos(items.map((f) => f.mercado));

    return mostrarFiltros(
      context,
      activos:
          (ref.read(vendedorInactivosFiltroProvider) == null ? 0 : 1) +
          (ref.read(mercadoInactivosFiltroProvider) == null ? 0 : 1),
      onLimpiar: () {
        ref.read(vendedorInactivosFiltroProvider.notifier).state = null;
        ref.read(mercadoInactivosFiltroProvider.notifier).state = null;
      },
      grupos: [
        if (vendedores.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => GrupoFiltro<String?>(
              titulo: 'Vendedor',
              valor: ref.watch(vendedorInactivosFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final v in vendedores) OpcionFiltro(v, v),
              ],
              onCambio: (v) =>
                  ref.read(vendedorInactivosFiltroProvider.notifier).state = v,
            ),
          ),
        if (mercados.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => GrupoFiltro<String?>(
              titulo: 'Mercado',
              valor: ref.watch(mercadoInactivosFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final m in mercados) OpcionFiltro(m, m),
              ],
              onCambio: (v) =>
                  ref.read(mercadoInactivosFiltroProvider.notifier).state = v,
            ),
          ),
      ],
    );
  }
}

class _TarjetaInactivo extends StatelessWidget {
  const _TarjetaInactivo({required this.fila, required this.color});

  final FilaInactivo fila;
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
        CampoDetalle(
          'Zona',
          [f.mercado, f.ruta].whereType<String>().join(' · '),
        ),
        CampoDetalle('Última compra', fechaDia(f.ultimaCompra)),
        CampoDetalle(
          'Sin comprar',
          null,
          widget: Text(
            '${f.diasSinCompra} días',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colorDeDias(f.diasSinCompra),
            ),
          ),
        ),
        CampoDetalle(
          'Compró en 12 meses',
          '${soles(f.ventas12m)} · ${f.compras12m} compras',
        ),
        CampoDetalle('Ticket promedio', soles(f.ticketPromedio)),
      ],
      acciones: [
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
