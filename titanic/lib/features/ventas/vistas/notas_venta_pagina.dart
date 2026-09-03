import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../datos/nota_venta.dart';
import '../estado/ventas_controlador.dart';
import 'nota_venta_formulario.dart';

/// Listado de notas de venta: la venta lista tal cual, nacida de confirmar un
/// pedido o registrada directa. El stock ya salió al momento de crearla.
class NotasVentaPagina extends ConsumerWidget {
  const NotasVentaPagina({super.key});

  static const ruta = '/fact/notaventa';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas = ref.watch(notasVentaProvider).valueOrNull ?? const <NotaVenta>[];
    final confirmadas = todas.where((n) => n.estado == EstadoNotaVenta.confirmada).length;
    final totalVendido = todas
        .where((n) => n.estado == EstadoNotaVenta.confirmada)
        .fold<double>(0, (n, x) => n + x.total);

    return AppListaPagina<NotaVenta>(
      titulo: 'Notas de venta',
      ruta: ruta,
      estado: ref.watch(notasVentaProvider),
      visibles: ref.watch(notasVentaFiltradasProvider),
      busqueda: ref.watch(busquedaNotasVentaProvider),
      onBuscar: (t) => ref.read(busquedaNotasVentaProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número o cliente',
      onRecargar: () => ref.read(notasVentaProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context),
      textoNuevo: 'Nueva venta',
      iconoVacio: Icons.shopping_bag_outlined,
      singular: 'nota de venta',
      plural: 'notas de venta',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Notas de venta',
          valor: '${todas.length}',
          icono: Icons.shopping_bag_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Confirmadas',
          valor: '$confirmadas',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Total vendido',
          valor: 'S/ ${totalVendido.toStringAsFixed(2)}',
          icono: Icons.payments_outlined,
          tono: DatoTono.exito,
        ),
      ],
      fila: (context, nota) => _TarjetaNotaVenta(
        nota: nota,
        color: color,
        onAnular: nota.estado == EstadoNotaVenta.confirmada
            ? () => _anular(context, ref, nota)
            : null,
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotaVentaFormulario()),
    );
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, NotaVenta nota) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${nota.numero}',
      mensaje: 'Se anula la venta y el stock que salió vuelve al almacén. No se puede deshacer.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(notasVentaProvider.notifier).anular(nota.id);
      mensajero.showSnackBar(SnackBar(content: Text('${nota.numero} anulada')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaNotaVenta extends StatelessWidget {
  const _TarjetaNotaVenta({required this.nota, required this.color, this.onAnular});

  final NotaVenta nota;
  final Color color;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Cliente', nota.cliente),
    CampoDetalle('Almacén', nota.almacen),
    CampoDetalle('Fecha', _fecha(nota.fecha)),
    CampoDetalle(
      'Forma de pago',
      nota.formaPago == FormaPagoVenta.contado ? 'Contado' : 'Crédito',
    ),
    if (nota.formaPago == FormaPagoVenta.contado)
      CampoDetalle(
        'Pagado',
        'S/ ${nota.totalPagado.toStringAsFixed(2)} de S/ ${nota.total.toStringAsFixed(2)}',
      ),
    CampoDetalle('Total', 'S/ ${nota.total.toStringAsFixed(2)}'),
    if (nota.pedidoNumero != null) CampoDetalle('Pedido', nota.pedidoNumero),
    if (nota.usuario != null) CampoDetalle('Registrada por', nota.usuario),
    if (nota.observacion != null) CampoDetalle('Observación', nota.observacion),
    for (final pago in nota.pagos)
      CampoDetalle(pago.metodoPago, 'S/ ${pago.monto.toStringAsFixed(2)}', enTarjeta: false),
  ];

  List<Widget> get _lineas => [
    for (final linea in nota.detalle)
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
      icono: Icons.shopping_bag_outlined,
      color: color,
      titulo: nota.numero,
      insignia: AppEtiqueta(
        nota.estado == EstadoNotaVenta.anulada ? 'Anulada' : 'Confirmada',
        tono: nota.estado == EstadoNotaVenta.anulada ? EtiquetaTono.peligro : EtiquetaTono.exito,
      ),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
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
      titulo: nota.numero,
      subtitulo: nota.cliente,
      insignia: AppEtiqueta(
        nota.estado == EstadoNotaVenta.anulada ? 'Anulada' : 'Confirmada',
        tono: nota.estado == EstadoNotaVenta.anulada ? EtiquetaTono.peligro : EtiquetaTono.exito,
      ),
      campos: _campos,
      contenidoExtra: _lineas,
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
