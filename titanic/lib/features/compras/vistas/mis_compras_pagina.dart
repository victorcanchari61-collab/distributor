import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../datos/compra.dart';
import '../estado/compras_controlador.dart';
import 'compra_formulario.dart';
import 'recepcion_formulario.dart';

/// Listado de compras: directas o nacidas de confirmar una orden.
class MisComprasPagina extends ConsumerWidget {
  const MisComprasPagina({super.key});

  static const ruta = '/compras/compras';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas = ref.watch(comprasProvider).valueOrNull ?? const <Compra>[];
    final porRecibir = todas
        .where((c) => c.estado == EstadoCompra.pendiente || c.estado == EstadoCompra.recibidaParcial)
        .length;
    final recibidas = todas.where((c) => c.estado == EstadoCompra.recibidaTotal).length;
    final estadoFiltro = ref.watch(estadoCompraFiltroProvider);

    return AppListaPagina<Compra>(
      titulo: 'Mis compras',
      ruta: ruta,
      estado: ref.watch(comprasProvider),
      visibles: ref.watch(comprasFiltradasProvider),
      busqueda: ref.watch(busquedaComprasProvider),
      onBuscar: (t) => ref.read(busquedaComprasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número, proveedor o comprobante',
      onRecargar: () => ref.read(comprasProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context),
      textoNuevo: 'Nueva compra',
      iconoVacio: Icons.shopping_bag_outlined,
      singular: 'compra',
      plural: 'compras',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Compras',
          valor: '${todas.length}',
          icono: Icons.shopping_bag_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Por recibir',
          valor: '$porRecibir',
          icono: Icons.local_shipping_outlined,
          tono: porRecibir > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Recibidas',
          valor: '$recibidas',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
      ],
      filtro: BotonFiltros(
        activos: estadoFiltro == null ? 0 : 1,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, compra) => _TarjetaCompra(
        compra: compra,
        color: color,
        onEditar: compra.estado == EstadoCompra.pendiente
            ? () => _abrirFormulario(context, compra)
            : null,
        onRecibir: compra.detalle.any((d) => d.cantidadPendiente > 0)
            ? () => _recibir(context, compra)
            : null,
        onAnular: compra.estado == EstadoCompra.pendiente
            ? () => _anular(context, ref, compra)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(estadoCompraFiltroProvider) == null ? 0 : 1,
      onLimpiar: () => ref.read(estadoCompraFiltroProvider.notifier).state = null,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoCompraFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todas'),
              OpcionFiltro(EstadoCompra.pendiente, 'Pendientes'),
              OpcionFiltro(EstadoCompra.recibidaParcial, 'Recibidas parcial'),
              OpcionFiltro(EstadoCompra.recibidaTotal, 'Recibidas total'),
              OpcionFiltro(EstadoCompra.anulada, 'Anuladas'),
            ],
            onCambio: (v) => ref.read(estadoCompraFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, [Compra? compra]) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CompraFormulario(compra: compra)),
    );
  }

  Future<void> _recibir(BuildContext context, Compra compra) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecepcionFormulario(compraFija: compra)),
    );
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, Compra compra) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${compra.numero}',
      mensaje: 'Esta compra queda sin efecto. No se puede deshacer.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(comprasProvider.notifier).anular(compra.id);
      mensajero.showSnackBar(SnackBar(content: Text('${compra.numero} anulada')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

EtiquetaTono _tonoEstadoCompra(String estado) => switch (estado) {
  EstadoCompra.recibidaTotal => EtiquetaTono.exito,
  EstadoCompra.recibidaParcial => EtiquetaTono.modulo,
  EstadoCompra.anulada => EtiquetaTono.peligro,
  _ => EtiquetaTono.aviso,
};

String _etiquetaEstadoCompra(String estado) => switch (estado) {
  EstadoCompra.recibidaTotal => 'Recibida total',
  EstadoCompra.recibidaParcial => 'Recibida parcial',
  EstadoCompra.anulada => 'Anulada',
  _ => 'Pendiente',
};

class _TarjetaCompra extends StatelessWidget {
  const _TarjetaCompra({
    required this.compra,
    required this.color,
    this.onEditar,
    this.onRecibir,
    this.onAnular,
  });

  final Compra compra;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onRecibir;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Proveedor', compra.proveedor),
    CampoDetalle('Fecha', _fecha(compra.fecha)),
    CampoDetalle(
      'Comprobante',
      '${TipoComprobanteCompra.etiqueta(compra.tipoComprobante)}'
          '${compra.numeroComprobante == null ? '' : ' ${compra.serieComprobante ?? ''}-${compra.numeroComprobante}'}',
    ),
    CampoDetalle(
      'Forma de pago',
      compra.formaPago == FormaPagoCompra.contado ? 'Contado' : 'Crédito',
    ),
    if (compra.formaPago == FormaPagoCompra.contado)
      CampoDetalle(
        'Pagado',
        'S/ ${compra.totalPagado.toStringAsFixed(2)} de S/ ${compra.total.toStringAsFixed(2)}',
      ),
    CampoDetalle('Total', 'S/ ${compra.total.toStringAsFixed(2)}'),
    if (compra.ordenCompraNumero != null) CampoDetalle('Orden de compra', compra.ordenCompraNumero),
    if (compra.usuario != null) CampoDetalle('Registrada por', compra.usuario),
    if (compra.observacion != null) CampoDetalle('Observación', compra.observacion),
  ];

  List<Widget> get _lineas => [
    for (final linea in compra.detalle)
      LineaProductoTarjeta(
        titulo: linea.producto,
        subtitulo: '${linea.codigo} · ${linea.presentacion ?? linea.unidadBase}',
        filas: [
          [
            ('Cant.', formatoNumero(linea.cantidadPresentacion)),
            (
              'Costo',
              'S/ ${(linea.cantidadPresentacion == 0 ? 0 : linea.costoTotal / linea.cantidadPresentacion).toStringAsFixed(2)}',
            ),
            ('Subtotal', 'S/ ${linea.costoTotal.toStringAsFixed(2)}'),
          ],
          [
            ('Recibido', '${formatoNumero(linea.cantidadRecibida)} ${linea.unidadBase}'),
            ('Pendiente', '${formatoNumero(linea.cantidadPendiente)} ${linea.unidadBase}'),
          ],
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.shopping_bag_outlined,
      color: color,
      titulo: compra.numero,
      insignia: AppEtiqueta(_etiquetaEstadoCompra(compra.estado), tono: _tonoEstadoCompra(compra.estado)),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
          ),
        if (onRecibir != null)
          IconButton(
            onPressed: onRecibir,
            tooltip: 'Recibir',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.move_to_inbox_outlined, size: 18, color: Colores.exito),
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
      icono: Icons.shopping_bag_outlined,
      color: color,
      titulo: compra.numero,
      subtitulo: compra.proveedor,
      insignia: AppEtiqueta(_etiquetaEstadoCompra(compra.estado), tono: _tonoEstadoCompra(compra.estado)),
      campos: [
        ..._campos,
        for (final pago in compra.pagos)
          CampoDetalle(pago.metodoPago, 'S/ ${pago.monto.toStringAsFixed(2)}'),
      ],
      contenidoExtra: _lineas,
      acciones: [
        if (onEditar != null)
          AppBoton(
            texto: 'Editar',
            variante: BotonVariante.secundario,
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onEditar!();
            },
          ),
        if (onRecibir != null)
          AppBoton(
            texto: 'Recibir',
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onRecibir!();
            },
          ),
      ],
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
