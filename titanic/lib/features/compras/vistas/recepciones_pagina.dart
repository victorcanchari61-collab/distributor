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
import '../../inventario/datos/documento_inventario.dart';
import '../../inventario/estado/inventario_controlador.dart';
import '../estado/compras_controlador.dart';
import 'recepcion_formulario.dart';

/// Listado de recepciones: mercaderia que ya llego contra una compra.
class RecepcionesPagina extends ConsumerWidget {
  const RecepcionesPagina({super.key});

  static const ruta = '/compras/recepciones';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas =
        ref.watch(recepcionesProvider).valueOrNull ?? const <DocumentoInventario>[];
    final confirmadas = todas.where((d) => !d.anulado).length;
    final hayPendientes = ref.watch(comprasConPendienteProvider).isNotEmpty;

    return AppListaPagina<DocumentoInventario>(
      titulo: 'Recepciones',
      ruta: ruta,
      estado: ref.watch(recepcionesProvider),
      visibles: ref.watch(recepcionesFiltradasProvider),
      busqueda: ref.watch(busquedaRecepcionesProvider),
      onBuscar: (t) => ref.read(busquedaRecepcionesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número, almacén o compra',
      onRecargar: () => ref.read(recepcionesProvider.notifier).recargar(),
      onNuevo: hayPendientes ? () => _abrirFormulario(context) : null,
      textoNuevo: 'Nueva recepción',
      iconoVacio: Icons.move_to_inbox_outlined,
      singular: 'recepción',
      plural: 'recepciones',
      detalleVacio: hayPendientes
          ? null
          : 'No hay compras con mercadería pendiente por recibir.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Recepciones',
          valor: '${todas.length}',
          icono: Icons.move_to_inbox_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Confirmadas',
          valor: '$confirmadas',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
      ],
      fila: (context, doc) => _TarjetaRecepcion(
        doc: doc,
        color: color,
        onAnular: doc.anulado ? null : () => _anular(context, ref, doc),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecepcionFormulario()),
    );
  }

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    DocumentoInventario doc,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${doc.numero}',
      mensaje: 'Revierte lo recibido: la compra vuelve a quedar pendiente por esa cantidad.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(recepcionesProvider.notifier).anular(doc.id);
      mensajero.showSnackBar(SnackBar(content: Text('${doc.numero} anulada')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaRecepcion extends StatelessWidget {
  const _TarjetaRecepcion({required this.doc, required this.color, this.onAnular});

  final DocumentoInventario doc;
  final Color color;
  final VoidCallback? onAnular;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Almacén', doc.almacen),
    if (doc.compra != null) CampoDetalle('Compra', doc.compra),
    CampoDetalle('Fecha', _fecha(doc.fecha)),
    CampoDetalle('Líneas', '${doc.lineas}'),
    CampoDetalle('Total', 'S/ ${doc.total.toStringAsFixed(2)}'),
    if (doc.usuario != null) CampoDetalle('Registrada por', doc.usuario),
    if (doc.anuladoPor != null) CampoDetalle('Anulada por', doc.anuladoPor),
    if (doc.observacion != null) CampoDetalle('Observación', doc.observacion),
  ];

  List<Widget> get _lineas => [
    for (final linea in doc.detalle)
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
      icono: Icons.move_to_inbox_outlined,
      color: color,
      titulo: doc.numero,
      insignia: AppEtiqueta(
        doc.anulado ? 'Anulada' : 'Confirmada',
        tono: doc.anulado ? EtiquetaTono.peligro : EtiquetaTono.exito,
      ),
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.move_to_inbox_outlined,
        color: color,
        titulo: doc.numero,
        subtitulo: doc.almacen,
        insignia: AppEtiqueta(
          doc.anulado ? 'Anulada' : 'Confirmada',
          tono: doc.anulado ? EtiquetaTono.peligro : EtiquetaTono.exito,
        ),
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

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
