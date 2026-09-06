import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../datos/pedido.dart';
import '../estado/ventas_controlador.dart';
import 'pedido_formulario.dart';

/// Listado de pedidos: lo que pidio un cliente, antes de que exista una
/// venta firme.
class PedidosPagina extends ConsumerWidget {
  const PedidosPagina({super.key});

  static const ruta = '/fact/pedidos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(pedidosProvider).valueOrNull ?? const <Pedido>[];
    final pendientes = todos.where((p) => p.estado == EstadoPedido.pendiente).length;
    final confirmados = todos.where((p) => p.estado == EstadoPedido.confirmado).length;
    final estadoFiltro = ref.watch(estadoPedidoFiltroProvider);

    return AppListaPagina<Pedido>(
      titulo: 'Pedidos',
      ruta: ruta,
      estado: ref.watch(pedidosProvider),
      visibles: ref.watch(pedidosFiltradosProvider),
      busqueda: ref.watch(busquedaPedidosProvider),
      onBuscar: (t) => ref.read(busquedaPedidosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número o cliente',
      onRecargar: () => ref.read(pedidosProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      textoNuevo: 'Nuevo pedido',
      iconoVacio: Icons.list_alt_outlined,
      singular: 'pedido',
      plural: 'pedidos',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Pedidos',
          valor: '${todos.length}',
          icono: Icons.list_alt_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Pendientes',
          valor: '$pendientes',
          icono: Icons.hourglass_empty,
          tono: pendientes > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Confirmados',
          valor: '$confirmados',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
      ],
      filtro: BotonFiltros(
        activos: estadoFiltro == null ? 0 : 1,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, pedido) => _TarjetaPedido(
        pedido: pedido,
        color: color,
        onEditar: pedido.estado == EstadoPedido.pendiente
            ? () => _abrirFormulario(context, pedido)
            : null,
        onConfirmar: pedido.estado == EstadoPedido.pendiente
            ? () => _confirmar(context, ref, pedido)
            : null,
        onAnular: pedido.estado == EstadoPedido.pendiente
            ? () => _anular(context, ref, pedido)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(estadoPedidoFiltroProvider) == null ? 0 : 1,
      onLimpiar: () => ref.read(estadoPedidoFiltroProvider.notifier).state = null,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoPedidoFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro(EstadoPedido.pendiente, 'Pendientes'),
              OpcionFiltro(EstadoPedido.confirmado, 'Confirmados'),
              OpcionFiltro(EstadoPedido.anulado, 'Anulados'),
            ],
            onCambio: (v) => ref.read(estadoPedidoFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Pedido? pedido) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PedidoFormulario(pedido: pedido)),
    );
  }

  Future<void> _confirmar(BuildContext context, WidgetRef ref, Pedido pedido) async {
    final almacenes = ref.read(almacenesActivosProvider);
    int? almacenId = almacenes.length == 1 ? almacenes.first.id : null;
    String? error;

    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colores.superficie,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: Dimen.espacio4,
                right: Dimen.espacio4,
                top: Dimen.espacio2,
                bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Confirmar ${pedido.numero}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
                  ),
                  const SizedBox(height: Dimen.espacio2),
                  const Text(
                    'Elige de dónde sale la mercadería. El stock se descuenta al confirmar. '
                    'Un pedido no lleva pagos: la venta queda a crédito, pendiente de cobro.',
                    style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(fontSize: 12, color: Colores.peligro)),
                    const SizedBox(height: Dimen.espacio2),
                  ],
                  AppSelector<int>(
                    valor: almacenId,
                    etiqueta: 'Almacén',
                    icono: Icons.warehouse_outlined,
                    opciones: [for (final a in almacenes) Opcion<int>(a.id, a.nombre)],
                    onCambio: (v) => setSheetState(() => almacenId = v),
                  ),
                  const SizedBox(height: Dimen.espacio4),
                  AppBoton(
                    texto: 'Confirmar y despachar',
                    onPressed: () {
                      if (almacenId == null) {
                        setSheetState(() => error = 'Elige el almacén.');
                        return;
                      }
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmado != true || almacenId == null || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(pedidosProvider.notifier).confirmar(pedido.id, {'almacenId': almacenId});
      mensajero.showSnackBar(
        SnackBar(content: Text('${pedido.numero} confirmado: se creó la nota de venta.')),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, Pedido pedido) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${pedido.numero}',
      mensaje: 'Este pedido queda sin efecto. No se puede deshacer.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(pedidosProvider.notifier).anular(pedido.id);
      mensajero.showSnackBar(SnackBar(content: Text('${pedido.numero} anulado')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

EtiquetaTono _tonoEstadoPedido(String estado) => switch (estado) {
  EstadoPedido.confirmado => EtiquetaTono.exito,
  EstadoPedido.anulado => EtiquetaTono.peligro,
  _ => EtiquetaTono.aviso,
};

String _etiquetaEstadoPedido(String estado) => switch (estado) {
  EstadoPedido.confirmado => 'Confirmado',
  EstadoPedido.anulado => 'Anulado',
  _ => 'Pendiente',
};

class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({
    required this.pedido,
    required this.color,
    this.onEditar,
    this.onConfirmar,
    this.onAnular,
  });

  final Pedido pedido;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onConfirmar;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Cliente', pedido.cliente),
    CampoDetalle('Fecha', _fecha(pedido.fecha)),
    CampoDetalle('Total', 'S/ ${pedido.total.toStringAsFixed(2)}'),
    if (pedido.reservaStock) CampoDetalle('Stock reservado en', pedido.almacen),
    if (pedido.usuario != null) CampoDetalle('Registrado por', pedido.usuario),
    if (pedido.observacion != null) CampoDetalle('Observación', pedido.observacion),
  ];

  List<Widget> get _lineas => [
    for (final linea in pedido.detalle)
      LineaProductoTarjeta(
        titulo: linea.producto,
        subtitulo: '${linea.codigo} · ${linea.presentacion ?? linea.unidadBase}',
        filas: [
          [
            ('Cant.', '${linea.cantidadPresentacion}'),
            ('Precio', 'S/ ${linea.precioUnitario.toStringAsFixed(2)}'),
            ('Subtotal', 'S/ ${linea.subtotal.toStringAsFixed(2)}'),
          ],
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.list_alt_outlined,
      color: color,
      titulo: pedido.numero,
      insignia: AppEtiqueta(_etiquetaEstadoPedido(pedido.estado), tono: _tonoEstadoPedido(pedido.estado)),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        if (onConfirmar != null)
          IconButton(
            onPressed: onConfirmar,
            tooltip: 'Confirmar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.check_circle_outline, size: 18, color: Colores.exito),
          ),
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
          ),
        if (onAnular != null)
          IconButton(
            onPressed: onAnular,
            tooltip: 'Anular',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.block, size: 18, color: Colores.peligro),
          ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.list_alt_outlined,
      color: color,
      titulo: pedido.numero,
      subtitulo: pedido.cliente,
      insignia: AppEtiqueta(_etiquetaEstadoPedido(pedido.estado), tono: _tonoEstadoPedido(pedido.estado)),
      campos: _campos,
      contenidoExtra: _lineas,
      acciones: [
        if (onConfirmar != null)
          AppBoton(
            texto: 'Confirmar',
            variante: BotonVariante.secundario,
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onConfirmar!();
            },
          ),
        if (onEditar != null)
          AppBoton(
            texto: 'Editar',
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onEditar!();
            },
          ),
      ],
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
