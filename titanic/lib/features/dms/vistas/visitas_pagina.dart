import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../tms/estado/tms_controlador.dart' as tms;
import '../datos/dms_modelos.dart';
import '../estado/dms_controlador.dart';

/// Visitas: a qué clientes toca ir y a cuáles ya se les tomó pedido.
///
/// No es un documento ni guarda nada: es la lista de trabajo del día, armada
/// con el día de visita de cada cliente y los pedidos de esa fecha. Sirve para
/// que el vendedor no dependa de acordarse, y para ver al cierre cuántos
/// puestos quedaron sin pasar.
///
/// En el teléfono es donde de verdad se usa: el vendedor la abre en la calle,
/// ve a quién le falta pasar y lo llama desde la misma tarjeta.
class VisitasPagina extends ConsumerWidget {
  const VisitasPagina({super.key});

  static const ruta = '/dms/visitas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final resumen = ref.watch(resumenVisitasProvider).valueOrNull;
    final dia = ref.watch(diaVisitasProvider);

    return AppListaPagina<Visita>(
      titulo: 'Visitas',
      ruta: ruta,
      estado: ref.watch(visitasProvider),
      visibles: ref.watch(visitasFiltradasProvider),
      busqueda: ref.watch(busquedaVisitasProvider),
      onBuscar: (t) => ref.read(busquedaVisitasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar cliente, mercado o dirección',
      onRecargar: () async {
        ref.invalidate(visitasProvider);
        ref.invalidate(resumenVisitasProvider);
        await ref.read(visitasProvider.future);
      },
      iconoVacio: Icons.storefront_outlined,
      singular: 'visita',
      plural: 'visitas',
      tituloVacio: 'Sin visitas',
      detalleVacio: 'Ningún cliente tiene visita programada ese día.',
      encabezado: _SelectorDia(dia: dia, color: color),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Programadas',
          valor: '${resumen?.programadas ?? 0}',
          icono: Icons.storefront_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Con pedido',
          valor: '${resumen?.atendidas ?? 0}',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
          nota: '${resumen?.cobertura ?? 0}% de cobertura',
        ),
        AppTarjetaDato(
          etiqueta: 'Pendientes',
          valor: '${resumen?.pendientes ?? 0}',
          icono: Icons.place_outlined,
          tono: (resumen?.pendientes ?? 0) > 0
              ? DatoTono.aviso
              : DatoTono.neutral,
          nota: 'todavía sin pasar',
        ),
        AppTarjetaDato(
          etiqueta: 'Pedido del día',
          valor: formatoSoles(resumen?.total ?? 0),
          icono: Icons.payments_outlined,
          tono: DatoTono.neutral,
        ),
      ],
      filtro: BotonFiltros(
        activos: ref.watch(filtrosVisitasActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, visita) => _TarjetaVisita(
        visita: visita,
        color: color,
        // Tomar el pedido lleva a Pedidos: la visita no crea nada por su
        // cuenta, y un segundo formulario de pedido aquí sería uno más que
        // mantener igual al de verdad.
        onTomarPedido: !visita.atendido && puede(ref, 'fact.pedidos', Accion.crear)
            ? () => context.go('/fact/pedidos')
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosVisitasActivosProvider),
      onLimpiar: () {
        ref.read(rutaVisitasProvider.notifier).state = null;
        ref.read(filtroVisitaProvider.notifier).state = FiltroVisita.todas;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroVisita>(
            titulo: 'Estado',
            valor: ref.watch(filtroVisitaProvider),
            opciones: const [
              OpcionFiltro(FiltroVisita.todas, 'Todas'),
              OpcionFiltro(FiltroVisita.pendientes, 'Pendientes'),
              OpcionFiltro(FiltroVisita.atendidas, 'Con pedido'),
            ],
            onCambio: (v) => ref.read(filtroVisitaProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<int?>(
            titulo: 'Ruta',
            valor: ref.watch(rutaVisitasProvider),
            opciones: [
              const OpcionFiltro<int?>(null, 'Todas'),
              for (final r in ref.watch(tms.rutasActivasProvider))
                OpcionFiltro<int?>(r.id, r.nombre),
            ],
            onCambio: (v) => ref.read(rutaVisitasProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }
}

/// El día que se mira, con flechas para ir al anterior y al siguiente.
///
/// Flechas y no solo un calendario: lo que se hace casi siempre es ver hoy y,
/// como mucho, mañana para preparar la ruta. Un toque, no tres.
class _SelectorDia extends ConsumerWidget {
  const _SelectorDia({required this.dia, required this.color});

  final DateTime dia;
  final Color color;

  static const _dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final diferencia = dia.difference(hoy).inDays;

    final etiqueta = switch (diferencia) {
      0 => 'Hoy',
      1 => 'Mañana',
      -1 => 'Ayer',
      _ => _dias[dia.weekday - 1],
    };

    void mover(int dias) => ref.read(diaVisitasProvider.notifier).state = dia
        .add(Duration(days: dias));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimen.espacio4,
        0,
        Dimen.espacio4,
        Dimen.espacio3,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colores.superficie,
          border: Border.all(color: Colores.linea),
          borderRadius: BorderRadius.circular(Dimen.radioCampo),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => mover(-1),
              tooltip: 'Día anterior',
              icon: Icon(Icons.chevron_left_rounded, color: color),
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final elegido = await showDatePicker(
                    context: context,
                    initialDate: dia,
                    firstDate: hoy.subtract(const Duration(days: 365)),
                    lastDate: hoy.add(const Duration(days: 60)),
                  );
                  if (elegido != null) {
                    ref.read(diaVisitasProvider.notifier).state = elegido;
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
                  child: Column(
                    children: [
                      Text(
                        etiqueta,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colores.tinta,
                        ),
                      ),
                      Text(
                        '${dia.day.toString().padLeft(2, '0')}/'
                        '${dia.month.toString().padLeft(2, '0')}/${dia.year}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colores.tintaSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => mover(1),
              tooltip: 'Día siguiente',
              icon: Icon(Icons.chevron_right_rounded, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaVisita extends StatelessWidget {
  const _TarjetaVisita({
    required this.visita,
    required this.color,
    this.onTomarPedido,
  });

  final Visita visita;
  final Color color;

  /// Null si ya tiene pedido o si quien mira no puede crear pedidos.
  final VoidCallback? onTomarPedido;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Documento', visita.documento, enTarjeta: false),
    CampoDetalle('Mercado', visita.mercado),
    CampoDetalle('Dirección', visita.direccion),
    CampoDetalle('Teléfono', visita.telefono),
    CampoDetalle('Ruta', visita.ruta, enTarjeta: false),
    CampoDetalle('Vendedor', visita.vendedor, enTarjeta: false),
    if (visita.atendido) ...[
      CampoDetalle('Pedido', visita.pedidoNumero),
      CampoDetalle('Importe', formatoSoles(visita.total)),
    ],
  ];

  Widget get _estado => visita.atendido
      ? AppEtiqueta(visita.pedidoNumero ?? 'Con pedido', tono: EtiquetaTono.exito)
      : const AppEtiqueta('Pendiente', tono: EtiquetaTono.aviso);

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.storefront_outlined,
      color: color,
      titulo: visita.cliente,
      insignia: _estado,
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.storefront_outlined,
        color: color,
        titulo: visita.cliente,
        subtitulo: visita.documento,
        estado: _estado,
        campos: _campos,
      ),
      acciones: [
        // Llamar antes de ir es lo que evita ir en balde: el puesto cerrado,
        // el dueño que no está, el pedido que ya hizo por otro lado.
        if (visita.telefono != null && visita.telefono!.trim().isNotEmpty)
          IconButton(
            onPressed: () => _copiarTelefono(context),
            tooltip: 'Teléfono',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.phone_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
        if (onTomarPedido != null)
          IconButton(
            onPressed: onTomarPedido,
            tooltip: 'Tomar pedido',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.add_shopping_cart_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
      ],
    );
  }

  void _copiarTelefono(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colores.superficie,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            0,
            Dimen.espacio4,
            Dimen.espacio4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                visita.cliente,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colores.tinta,
                ),
              ),
              const SizedBox(height: Dimen.espacio2),
              SelectableText(
                visita.telefono!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colores.tinta,
                ),
              ),
              const SizedBox(height: Dimen.espacio2),
              const Text(
                'Mantén presionado para copiarlo.',
                style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
