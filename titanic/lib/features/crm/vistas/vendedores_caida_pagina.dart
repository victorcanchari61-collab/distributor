import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector_rango.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/crm.dart';
import '../estado/crm_controlador.dart';
import 'crm_comun.dart';

/// Vendedores con caída: lo que vendió cada vendedor frente al mismo tramo del
/// año anterior, con la misma escala de estados que los clientes. Además dice
/// cuántos de sus clientes están bajando, que es de donde sale la caída.
class VendedoresCaidaPagina extends ConsumerWidget {
  const VendedoresCaidaPagina({super.key});

  static const ruta = '/crm/vendedores';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final estado = ref.watch(vendedoresCaidaProvider);
    final datos = estado.valueOrNull;

    return AppListaPagina<FilaVendedor>(
      titulo: 'Vendedores con caída',
      ruta: ruta,
      estado: estado.whenData((d) => d.items),
      visibles: ref.watch(vendedoresFiltradosProvider),
      busqueda: ref.watch(busquedaVendedoresProvider),
      onBuscar: (t) => ref.read(busquedaVendedoresProvider.notifier).state = t,
      pistaBusqueda: 'Buscar vendedor',
      onRecargar: () async {
        ref.invalidate(vendedoresCaidaProvider);
        try {
          await ref.read(vendedoresCaidaProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      iconoVacio: Icons.groups_outlined,
      singular: 'vendedor',
      plural: 'vendedores',
      tituloVacio: 'Sin vendedores',
      detalleVacio: 'Ningún vendedor vendió en este tramo.',
      encabezado: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
            child: AppSelectorRango(
              rango: ref.watch(rangoVendedoresProvider),
              textoVacio: 'Del 1 de enero a hoy',
              onCambio: (r) =>
                  ref.read(rangoVendedoresProvider.notifier).state = r,
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
                '${datos.periodo.etiquetaAnterior}.',
                style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ),
          TarjetasEstado(
            estados: datos?.estados ?? const [],
            activo: ref.watch(estadoVendedoresFiltroProvider),
            onCambio: (e) =>
                ref.read(estadoVendedoresFiltroProvider.notifier).state = e,
            nota: (r) => switch (r.estado) {
              EstadoCaida.sinBase => 'sin ventas antes',
              EstadoCaida.normal => 'venden igual o casi',
              _ => '${soles(r.monto)} en riesgo',
            },
          ),
        ],
      ),
      fila: (context, f) => _TarjetaVendedor(fila: f, color: color),
    );
  }
}

class _TarjetaVendedor extends StatelessWidget {
  const _TarjetaVendedor({required this.fila, required this.color});

  final FilaVendedor fila;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = fila;

    return AppTarjetaRegistro(
      icono: Icons.person_outline,
      color: color,
      titulo: f.vendedor,
      insignia: EtiquetaEstadoCaida(f.estado),
      campos: [
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
        CampoDetalle('Clientes', '${f.clientes}'),
        CampoDetalle(
          'Con caída',
          null,
          widget: Text(
            '${f.clientesEnCaida}'
            '${f.clientesCriticos > 0 ? ' · ${f.clientesCriticos} críticos' : ''}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: f.clientesCriticos > 0 ? Colores.peligro : Colores.tinta,
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
      ],
    );
  }
}
