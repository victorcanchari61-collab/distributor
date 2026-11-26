import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton_fila.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/permisos/sin_permiso.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../datos/cotizacion.dart';
import '../estado/ventas_controlador.dart';
import 'pedido_formulario.dart';

/// La bandeja de cotizaciones que los clientes mandan desde el portal web.
///
/// Atender una es crear el pedido con ella ("Crear pedido": el formulario abre
/// ya con el cliente, los productos, los precios y la nota). Si no se va a
/// atender, se descarta con un motivo que ve el cliente. El catalogo y el
/// carrito del cliente viven solo en la web: aqui no hay nada de eso.
class CotizacionesPagina extends ConsumerWidget {
  const CotizacionesPagina({super.key});

  static const ruta = '/fact/cotizaciones';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas =
        ref.watch(cotizacionesProvider).valueOrNull ?? const <Cotizacion>[];
    final enEspera = todas.where((c) => c.enEspera).length;
    final atendidas = todas
        .where((c) => c.estado == EstadoCotizacion.atendida)
        .length;
    final estadoFiltro = ref.watch(estadoCotizacionFiltroProvider);
    final puedeCrearPedido = puede(ref, 'fact.pedidos', Accion.crear);
    final puedeDescartar = puede(ref, 'fact.cotizaciones', Accion.anular);

    void filtrar(String? estado) =>
        ref.read(estadoCotizacionFiltroProvider.notifier).state = estado;

    return AppListaPagina<Cotizacion>(
      titulo: 'Cotizaciones',
      ruta: ruta,
      estado: ref.watch(cotizacionesProvider),
      visibles: ref.watch(cotizacionesFiltradasProvider),
      busqueda: ref.watch(busquedaCotizacionesProvider),
      onBuscar: (t) =>
          ref.read(busquedaCotizacionesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número o cliente',
      onRecargar: () => ref.read(cotizacionesProvider.notifier).recargar(),
      iconoVacio: Icons.request_quote_outlined,
      singular: 'cotización',
      plural: 'cotizaciones',
      tituloVacio: estadoFiltro == EstadoCotizacion.enEspera
          ? 'No hay cotizaciones esperando'
          : null,
      detalleVacio: estadoFiltro == EstadoCotizacion.enEspera
          ? 'Las que manden tus clientes desde el portal aparecen aquí solas.'
          : null,
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'En espera',
          valor: '$enEspera',
          icono: Icons.schedule,
          tono: enEspera > 0 ? DatoTono.aviso : DatoTono.neutral,
          accion: AccionDato(
            etiqueta: 'Ver',
            onTap: () => filtrar(EstadoCotizacion.enEspera),
          ),
        ),
        AppTarjetaDato(
          etiqueta: 'Atendidas',
          valor: '$atendidas',
          icono: Icons.task_alt,
          tono: DatoTono.exito,
          accion: AccionDato(etiqueta: 'Ver todas', onTap: () => filtrar(null)),
        ),
      ],
      filtro: BotonFiltros(
        activos: estadoFiltro == null ? 0 : 1,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, c) => _TarjetaCotizacion(
        cotizacion: c,
        color: color,
        onCrearPedido: c.enEspera
            ? permitir(puedeCrearPedido, () => _crearPedido(context, c))
            : null,
        onDescartar: c.enEspera
            ? permitir(puedeDescartar, () => _descartar(context, ref, c))
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(estadoCotizacionFiltroProvider) == null ? 0 : 1,
      onLimpiar: () =>
          ref.read(estadoCotizacionFiltroProvider.notifier).state = null,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoCotizacionFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todas'),
              OpcionFiltro(EstadoCotizacion.enEspera, 'En espera'),
              OpcionFiltro(EstadoCotizacion.atendida, 'Atendidas'),
              OpcionFiltro(EstadoCotizacion.descartada, 'Descartadas'),
              OpcionFiltro(EstadoCotizacion.cancelada, 'Canceladas'),
            ],
            onCambio: (v) =>
                ref.read(estadoCotizacionFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  /// El formulario de pedido ya lleno con la cotizacion: al guardarlo queda
  /// atendida.
  void _crearPedido(BuildContext context, Cotizacion c) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PedidoFormulario(cotizacion: c)));
  }

  Future<void> _descartar(
    BuildContext context,
    WidgetRef ref,
    Cotizacion c,
  ) async {
    final motivo = await pedirMotivoDescarte(context, c);
    if (motivo == null || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(cotizacionesProvider.notifier).descartar(c.id, motivo);
      mensajero.mostrar('${c.numero} descartada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

/// Pide el motivo del descarte (lo ve el cliente en su portal). Null si se
/// cancela.
Future<String?> pedirMotivoDescarte(BuildContext context, Cotizacion c) {
  final controlador = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Descartar ${c.numero}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.cliente} verá el motivo en su portal.',
              style: const TextStyle(fontSize: 13, color: Colores.tintaSuave),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controlador,
              autofocus: true,
              maxLength: 250,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Sin stock esta semana',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: controlador.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(controlador.text.trim()),
            child: const Text('Descartar'),
          ),
        ],
      ),
    ),
  ).whenComplete(controlador.dispose);
}

class _TarjetaCotizacion extends StatelessWidget {
  const _TarjetaCotizacion({
    required this.cotizacion,
    required this.color,
    this.onCrearPedido,
    this.onDescartar,
  });

  final Cotizacion cotizacion;
  final Color color;
  final VoidCallback? onCrearPedido;
  final VoidCallback? onDescartar;

  AppEtiqueta get _estado => AppEtiqueta(
    EstadoCotizacion.etiqueta(cotizacion.estado),
    tono: EstadoCotizacion.tono(cotizacion.estado),
  );

  List<CampoDetalle> get _campos => [
    CampoDetalle('Cliente', cotizacion.cliente),
    CampoDetalle('Fecha', _fecha(cotizacion.fecha)),
    CampoDetalle('Productos', '${cotizacion.detalle.length}'),
    CampoDetalle('Total', 'S/ ${cotizacion.total.toStringAsFixed(2)}'),
    if (cotizacion.nota != null) CampoDetalle('Nota', cotizacion.nota),
    if (cotizacion.pedidoNumero != null)
      CampoDetalle('Pedido', cotizacion.pedidoNumero),
    if (cotizacion.motivoDescarte != null)
      CampoDetalle('Motivo', cotizacion.motivoDescarte, enTarjeta: false),
    if (cotizacion.ruta != null)
      CampoDetalle('Ruta', cotizacion.ruta, enTarjeta: false),
    if (cotizacion.vendedor != null)
      CampoDetalle('Para', cotizacion.vendedor, enTarjeta: false),
    if (cotizacion.cerradaPor != null)
      CampoDetalle('Cerró', cotizacion.cerradaPor, enTarjeta: false),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.request_quote_outlined,
      color: color,
      titulo: cotizacion.numero,
      estado: _estado,
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        AppBotonFila(
          icono: Icons.visibility,
          etiqueta: 'Ver ${cotizacion.numero}',
          tono: TonoAccion.ver,
          onPressed: () => _abrirDetalle(context),
        ),
        AppBotonFila(
          icono: Icons.add_shopping_cart,
          etiqueta: 'Crear pedido con ${cotizacion.numero}',
          tono: TonoAccion.exito,
          onPressed: onCrearPedido,
          motivo: cotizacion.enEspera
              ? 'No tienes permiso para crear pedidos'
              : 'Ya no está en espera',
        ),
        AppBotonFila(
          icono: Icons.block,
          etiqueta: 'Descartar ${cotizacion.numero}',
          tono: TonoAccion.peligro,
          onPressed: onDescartar,
          motivo: cotizacion.enEspera
              ? 'No tienes permiso para descartarla'
              : 'Ya no está en espera',
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.request_quote_outlined,
      color: color,
      titulo: cotizacion.numero,
      subtitulo: cotizacion.cliente,
      estado: _estado,
      campos: _campos,
      contenidoExtra: [
        for (final l in cotizacion.detalle)
          LineaProductoTarjeta(
            titulo: l.producto,
            subtitulo: '${l.codigo} · ${l.presentacion}',
            filas: [
              [
                ('Cant.', formatoNumero(l.cantidad)),
                ('Precio', 'S/ ${l.precioPresentacion.toStringAsFixed(2)}'),
                ('Subtotal', 'S/ ${l.subtotal.toStringAsFixed(2)}'),
              ],
            ],
          ),
      ],
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
