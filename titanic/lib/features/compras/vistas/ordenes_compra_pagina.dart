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
import '../datos/orden_compra.dart';
import '../estado/compras_controlador.dart';
import 'orden_compra_formulario.dart';

/// Listado de ordenes de compra: lo que se le pide a un proveedor. Al
/// confirmarse nace una Compra.
class OrdenesCompraPagina extends ConsumerWidget {
  const OrdenesCompraPagina({super.key});

  static const ruta = '/compras/ordenes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas = ref.watch(ordenesCompraProvider).valueOrNull ?? const <OrdenCompra>[];
    final pendientes = todas.where((o) => o.estado == EstadoOrdenCompra.pendiente).length;
    final confirmadas = todas.where((o) => o.estado == EstadoOrdenCompra.confirmada).length;
    final estadoFiltro = ref.watch(estadoOrdenCompraFiltroProvider);

    return AppListaPagina<OrdenCompra>(
      titulo: 'Órdenes de compra',
      ruta: ruta,
      estado: ref.watch(ordenesCompraProvider),
      visibles: ref.watch(ordenesCompraFiltradasProvider),
      busqueda: ref.watch(busquedaOrdenesCompraProvider),
      onBuscar: (t) => ref.read(busquedaOrdenesCompraProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número o proveedor',
      onRecargar: () => ref.read(ordenesCompraProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      textoNuevo: 'Nueva orden',
      iconoVacio: Icons.list_alt_outlined,
      singular: 'orden de compra',
      plural: 'órdenes de compra',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Total',
          valor: '${todas.length}',
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
          etiqueta: 'Confirmadas',
          valor: '$confirmadas',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
      ],
      filtro: BotonFiltros(
        activos: estadoFiltro == null ? 0 : 1,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, orden) => _TarjetaOrden(
        orden: orden,
        color: color,
        onEditar: orden.estado == EstadoOrdenCompra.pendiente
            ? () => _abrirFormulario(context, orden)
            : null,
        onConfirmar: orden.estado == EstadoOrdenCompra.pendiente
            ? () => _confirmar(context, ref, orden)
            : null,
        onAnular: orden.estado != EstadoOrdenCompra.anulada
            ? () => _anular(context, ref, orden)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(estadoOrdenCompraFiltroProvider) == null ? 0 : 1,
      onLimpiar: () => ref.read(estadoOrdenCompraFiltroProvider.notifier).state = null,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoOrdenCompraFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todas'),
              OpcionFiltro(EstadoOrdenCompra.pendiente, 'Pendientes'),
              OpcionFiltro(EstadoOrdenCompra.confirmada, 'Confirmadas'),
              OpcionFiltro(EstadoOrdenCompra.anulada, 'Anuladas'),
            ],
            onCambio: (v) => ref.read(estadoOrdenCompraFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, OrdenCompra? orden) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrdenCompraFormulario(orden: orden)),
    );
  }

  Future<void> _confirmar(BuildContext context, WidgetRef ref, OrdenCompra orden) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Confirmar ${orden.numero}',
      mensaje: 'El proveedor aceptó despachar: se cierra la orden y se crea la compra.',
      textoConfirmar: 'Confirmar',
      tono: ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(ordenesCompraProvider.notifier).confirmar(orden.id);
      mensajero.showSnackBar(
        SnackBar(content: Text('${orden.numero} confirmada: se creó la compra.')),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, OrdenCompra orden) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${orden.numero}',
      mensaje: 'Esta orden queda sin efecto. No se puede deshacer.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(ordenesCompraProvider.notifier).anular(orden.id);
      mensajero.showSnackBar(SnackBar(content: Text('${orden.numero} anulada')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

EtiquetaTono _tonoEstadoOrden(String estado) => switch (estado) {
  EstadoOrdenCompra.confirmada => EtiquetaTono.exito,
  EstadoOrdenCompra.anulada => EtiquetaTono.peligro,
  _ => EtiquetaTono.aviso,
};

String _etiquetaEstadoOrden(String estado) => switch (estado) {
  EstadoOrdenCompra.confirmada => 'Confirmada',
  EstadoOrdenCompra.anulada => 'Anulada',
  _ => 'Pendiente',
};

class _TarjetaOrden extends StatelessWidget {
  const _TarjetaOrden({
    required this.orden,
    required this.color,
    this.onEditar,
    this.onConfirmar,
    this.onAnular,
  });

  final OrdenCompra orden;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onConfirmar;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Fecha', _fecha(orden.fecha)),
    if (orden.fechaEsperada != null)
      CampoDetalle('Fecha esperada', _fecha(orden.fechaEsperada!)),
    CampoDetalle('Líneas', '${orden.detalle.length}'),
    CampoDetalle('Total', 'S/ ${orden.total.toStringAsFixed(2)}'),
    if (orden.usuario != null) CampoDetalle('Registrada por', orden.usuario),
    if (orden.observacion != null) CampoDetalle('Observación', orden.observacion),
  ];

  List<Widget> get _lineas => [
    for (final linea in orden.detalle)
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
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.list_alt_outlined,
      color: color,
      titulo: orden.numero,
      insignia: AppEtiqueta(
        _etiquetaEstadoOrden(orden.estado),
        tono: _tonoEstadoOrden(orden.estado),
      ),
      campos: [CampoDetalle('Proveedor', orden.proveedor), ..._campos],
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
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
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
      titulo: orden.numero,
      subtitulo: orden.proveedor,
      insignia: AppEtiqueta(
        _etiquetaEstadoOrden(orden.estado),
        tono: _tonoEstadoOrden(orden.estado),
      ),
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
