import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../datos/prestamo.dart';
import '../estado/inventario_controlador.dart';
import 'prestamo_devolucion_hoja.dart';
import 'prestamo_formulario.dart';

/// Listado de prestamos: mercaderia que sale o entra desde fuera de la
/// empresa, y se espera de vuelta.
class PrestamosPagina extends ConsumerWidget {
  const PrestamosPagina({super.key});

  static const ruta = '/inv/prestamos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(prestamosProvider).valueOrNull ?? const <Prestamo>[];
    final pendientes = todos.where((p) => p.estado == EstadoPrestamo.pendiente).length;

    return AppListaPagina<Prestamo>(
      titulo: 'Préstamos',
      ruta: ruta,
      estado: ref.watch(prestamosProvider),
      visibles: ref.watch(prestamosFiltradosProvider),
      busqueda: ref.watch(busquedaPrestamosProvider),
      onBuscar: (t) => ref.read(busquedaPrestamosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número, contraparte o almacén',
      onRecargar: () => ref.read(prestamosProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context),
      textoNuevo: 'Nuevo préstamo',
      iconoVacio: Icons.handshake_outlined,
      singular: 'préstamo',
      plural: 'préstamos',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Préstamos',
          valor: '${todos.length}',
          icono: Icons.handshake_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Pendientes',
          valor: '$pendientes',
          icono: Icons.hourglass_empty,
          tono: pendientes > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
      ],
      fila: (context, prestamo) => _TarjetaPrestamo(
        prestamo: prestamo,
        color: color,
        onDevolver: prestamo.estado == EstadoPrestamo.pendiente
            ? () => mostrarHojaDevolucion(context, ref, prestamo: prestamo)
            : null,
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrestamoFormulario()),
    );
  }
}

class _TarjetaPrestamo extends StatelessWidget {
  const _TarjetaPrestamo({required this.prestamo, required this.color, this.onDevolver});

  final Prestamo prestamo;
  final Color color;
  final VoidCallback? onDevolver;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Almacén', prestamo.almacen),
    CampoDetalle('Total', 'S/ ${prestamo.total.toStringAsFixed(2)}'),
    if (prestamo.usuario != null) CampoDetalle('Registrado por', prestamo.usuario),
    if (prestamo.observacion != null) CampoDetalle('Observación', prestamo.observacion),
  ];

  List<Widget> get _lineas => [
    for (final linea in prestamo.detalle)
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
            ('Devuelto', '${formatoNumero(linea.cantidadDevuelta)} ${linea.unidadBase}'),
            ('Pendiente', '${formatoNumero(linea.cantidadPendiente)} ${linea.unidadBase}'),
          ],
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.handshake_outlined,
      color: color,
      titulo: prestamo.numero,
      insignia: AppEtiqueta(prestamo.esDado ? 'Dado' : 'Recibido', tono: EtiquetaTono.modulo, color: color),
      campos: [CampoDetalle('Contraparte', prestamo.contraparte), ..._campos],
      onTap: () => _abrirDetalle(context),
      acciones: [
        if (onDevolver != null)
          IconButton(
            onPressed: onDevolver,
            tooltip: 'Registrar devolución',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.undo, size: 18, color: Colores.exito),
          ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.handshake_outlined,
      color: color,
      titulo: prestamo.numero,
      subtitulo: prestamo.contraparte,
      insignia: AppEtiqueta(
        prestamo.estado == EstadoPrestamo.pendiente ? 'Pendiente' : 'Devuelto',
        tono: prestamo.estado == EstadoPrestamo.pendiente ? EtiquetaTono.aviso : EtiquetaTono.exito,
      ),
      campos: _campos,
      contenidoExtra: _lineas,
      acciones: [
        if (onDevolver != null)
          AppBoton(
            texto: 'Registrar devolución',
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onDevolver!();
            },
          ),
      ],
    );
  }
}
