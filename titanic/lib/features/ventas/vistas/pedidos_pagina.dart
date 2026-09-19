import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pdf.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/pedido.dart';
import '../estado/ventas_controlador.dart';
import 'entrega_pedido_hoja.dart';
import 'pedido_formulario.dart';
import '../../../compartido/widgets/app_aviso.dart';

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
      onNuevo: puede(ref, 'fact.pedidos', Accion.crear)
          ? () => _abrirFormulario(context, null)
          : null,
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
        onEditar: puede(ref, 'fact.pedidos', Accion.editar) &&
                pedido.estado == EstadoPedido.pendiente
            ? () => _abrirFormulario(context, pedido)
            : null,
        onConfirmar: puede(ref, 'fact.pedidos', Accion.confirmar) &&
                pedido.estado == EstadoPedido.pendiente
            ? () => _confirmar(context, ref, pedido)
            : null,
        onNoEntregado: puede(ref, 'fact.pedidos', Accion.confirmar) &&
                pedido.estado == EstadoPedido.pendiente
            ? () => pedido.noEntregadoMotivo != null
                  ? _quitarNoEntregado(context, ref, pedido)
                  : _noEntregado(context, ref, pedido)
            : null,
        onAnular: puede(ref, 'fact.pedidos', Accion.anular) &&
                pedido.estado == EstadoPedido.pendiente
            ? () => _anular(context, ref, pedido)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosPedidosActivosProvider),
      onLimpiar: () {
        ref.read(estadoPedidoFiltroProvider.notifier).state = null;
        ref.read(clientePedidoFiltroProvider.notifier).state = null;
        ref.read(ventaPedidoFiltroProvider.notifier).state = null;
      },
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
        Consumer(
          builder: (context, ref, _) {
            final clientes = ref.watch(clientesPedidoProvider);
            if (clientes.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Cliente',
              valor: ref.watch(clientePedidoFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final c in clientes) OpcionFiltro(c, c),
              ],
              onCambio: (v) =>
                  ref.read(clientePedidoFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<bool?>(
            titulo: 'Venta',
            valor: ref.watch(ventaPedidoFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro(true, 'Convertido'),
              OpcionFiltro(false, 'Sin convertir'),
            ],
            onCambio: (v) => ref.read(ventaPedidoFiltroProvider.notifier).state = v,
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

  /// Convierte el pedido en venta con lo que de verdad se entregó: por defecto
  /// todo, y si el cliente recibió menos se corrige la línea y se pide el motivo.
  Future<void> _confirmar(BuildContext context, WidgetRef ref, Pedido pedido) async {
    final mensajero = Aviso.de(context);
    final hecho = await mostrarEntregaPedido(context, pedido);
    if (hecho == true) {
      mensajero.mostrar('${pedido.numero} confirmado: se creó la nota de venta.');
    }
  }

  /// El pedido entero no se entregó: no crea venta, deja la novedad con su motivo.
  Future<void> _noEntregado(BuildContext context, WidgetRef ref, Pedido pedido) async {
    final mensajero = Aviso.de(context);
    final hecho = await mostrarNoEntregado(context, pedido);
    if (hecho == true) {
      mensajero.mostrar('${pedido.numero} marcado como no entregado.');
    }
  }

  Future<void> _quitarNoEntregado(BuildContext context, WidgetRef ref, Pedido pedido) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Quitar la marca de ${pedido.numero}',
      mensaje: 'El pedido deja de figurar como no entregado y vuelve a quedar solo pendiente.',
      textoConfirmar: 'Quitar marca',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(pedidosProvider.notifier).quitarNoEntregado(pedido.id);
      mensajero.mostrar('${pedido.numero} ya no figura como no entregado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
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

    final mensajero = Aviso.de(context);
    try {
      await ref.read(pedidosProvider.notifier).anular(pedido.id);
      mensajero.mostrar('${pedido.numero} anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
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
    this.onNoEntregado,
    this.onAnular,
  });

  final Pedido pedido;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onConfirmar;

  /// Marca el pedido como no entregado, o quita la marca si ya la tiene.
  final VoidCallback? onNoEntregado;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Cliente', pedido.cliente),
    CampoDetalle('Fecha', _fecha(pedido.fecha)),
    CampoDetalle('Total', 'S/ ${pedido.total.toStringAsFixed(2)}'),
    if (pedido.noEntregadoMotivo != null)
      CampoDetalle(
        'No se entregó',
        pedido.noEntregadoObservacion == null
            ? pedido.noEntregadoMotivo
            : '${pedido.noEntregadoMotivo} — ${pedido.noEntregadoObservacion}',
        widget: AppEtiqueta('No entregado: ${pedido.noEntregadoMotivo}', tono: EtiquetaTono.peligro),
      ),
    if (pedido.reservaStock) CampoDetalle('Stock reservado en', pedido.almacen),
    if (pedido.usuario != null) CampoDetalle('Registrado por', pedido.usuario),
    if (pedido.observacion != null) CampoDetalle('Observación', pedido.observacion),
  ];

  /// El estado del pedido; si el repartidor lo marcó como no entregado, además
  /// va el motivo, que es lo que hay que ver de un vistazo en la lista.
  Widget get _estado {
    final etiqueta = AppEtiqueta(
      _etiquetaEstadoPedido(pedido.estado),
      tono: _tonoEstadoPedido(pedido.estado),
    );
    if (pedido.noEntregadoMotivo == null) return etiqueta;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        etiqueta,
        AppEtiqueta('No entregado: ${pedido.noEntregadoMotivo}', tono: EtiquetaTono.peligro),
      ],
    );
  }

  List<Widget> get _lineas => [
    for (final linea in pedido.detalle.where((l) => !l.anulado))
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
      estado: _estado,
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        IconButton(
          onPressed: () => mostrarOpcionesPdf(
            context,
            documento: DocumentoPdf.pedido,
            id: pedido.id,
            numero: pedido.numero,
          ),
          tooltip: 'PDF',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
        ),
        if (onConfirmar != null)
          IconButton(
            onPressed: onConfirmar,
            tooltip: 'Confirmar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.check_circle_outline, size: 18, color: Colores.exito),
          ),
        if (onNoEntregado != null)
          IconButton(
            onPressed: onNoEntregado,
            tooltip: pedido.noEntregadoMotivo != null ? 'Quitar la marca de no entregado' : 'No entregado',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              pedido.noEntregadoMotivo != null ? Icons.undo : Icons.report_gmailerrorred_outlined,
              size: 18,
              color: Colores.advertencia,
            ),
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
      estado: _estado,
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
