import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
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
import '../datos/documento_inventario.dart';
import '../estado/inventario_controlador.dart';
import 'transferencia_formulario.dart';

/// Listado de transferencias entre almacenes propios.
class TransferenciasPagina extends ConsumerWidget {
  const TransferenciasPagina({super.key});

  static const ruta = '/inv/transferencias';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas =
        ref.watch(transferenciasProvider).valueOrNull ?? const <DocumentoInventario>[];
    final confirmadas = todas.where((d) => !d.anulado).length;
    final almacenesActivos = ref.watch(almacenesActivosProvider).length;

    return AppListaPagina<DocumentoInventario>(
      titulo: 'Transferencias',
      ruta: ruta,
      estado: ref.watch(transferenciasProvider),
      visibles: ref.watch(transferenciasFiltradasProvider),
      busqueda: ref.watch(busquedaTransferenciasProvider),
      onBuscar: (t) => ref.read(busquedaTransferenciasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número o almacén',
      onRecargar: () => ref.read(transferenciasProvider.notifier).recargar(),
      onNuevo: almacenesActivos >= 2 ? () => _abrirFormulario(context) : null,
      textoNuevo: 'Nueva transferencia',
      iconoVacio: Icons.local_shipping_outlined,
      singular: 'transferencia',
      plural: 'transferencias',
      detalleVacio: almacenesActivos >= 2
          ? null
          : 'Necesitas al menos dos almacenes activos para transferir.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Transferencias',
          valor: '${todas.length}',
          icono: Icons.local_shipping_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Confirmadas',
          valor: '$confirmadas',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
      ],
      fila: (context, doc) => _TarjetaTransferencia(
        doc: doc,
        color: color,
        onAnular: doc.anulado ? null : () => _anular(context, ref, doc),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransferenciaFormulario()),
    );
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, DocumentoInventario doc) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${doc.numero}',
      mensaje: 'Se revierte el movimiento con un documento espejo. No se puede deshacer.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(transferenciasProvider.notifier).anular(doc.id);
      mensajero.showSnackBar(SnackBar(content: Text('${doc.numero} anulada')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaTransferencia extends StatelessWidget {
  const _TarjetaTransferencia({required this.doc, required this.color, this.onAnular});

  final DocumentoInventario doc;
  final Color color;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Origen', doc.almacen),
    CampoDetalle('Destino', doc.almacenDestino),
    CampoDetalle('Líneas', '${doc.lineas}'),
    CampoDetalle('Total', 'S/ ${doc.total.toStringAsFixed(2)}'),
    if (doc.usuario != null) CampoDetalle('Registrada por', doc.usuario),
    if (doc.observacion != null) CampoDetalle('Observación', doc.observacion),
  ];

  List<Widget> get _lineas => [
    for (final linea in doc.detalle.where((l) => l.esEntrada))
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
      icono: Icons.local_shipping_outlined,
      color: color,
      titulo: doc.numero,
      insignia: AppEtiqueta(
        doc.anulado ? 'Anulada' : 'Confirmada',
        tono: doc.anulado ? EtiquetaTono.peligro : EtiquetaTono.exito,
      ),
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.local_shipping_outlined,
        color: color,
        titulo: doc.numero,
        subtitulo: '${doc.almacen} → ${doc.almacenDestino ?? ''}',
        campos: _campos,
        contenidoExtra: _lineas,
      ),
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
}
