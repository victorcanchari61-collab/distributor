import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_pdf.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/permisos/permisos.dart';
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
      onNuevo: puede(ref, 'inv.prestamos', Accion.crear)
          ? () => _abrirFormulario(context)
          : null,
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
      filtro: BotonFiltros(
        activos: ref.watch(filtrosPrestamosActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, prestamo) => _TarjetaPrestamo(
        prestamo: prestamo,
        color: color,
        onDevolver: puede(ref, 'inv.prestamos', Accion.confirmar) &&
                prestamo.estado == EstadoPrestamo.pendiente
            ? () => mostrarHojaDevolucion(context, ref, prestamo: prestamo)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosPrestamosActivosProvider),
      onLimpiar: () {
        ref.read(filtroPrestamoProvider.notifier).state =
            FiltroPrestamo.todos;
        ref.read(filtroDevolucionProvider.notifier).state =
            FiltroDevolucion.todos;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroPrestamo>(
            titulo: 'Tipo',
            valor: ref.watch(filtroPrestamoProvider),
            opciones: const [
              OpcionFiltro(FiltroPrestamo.todos, 'Todos'),
              OpcionFiltro(FiltroPrestamo.prestados, 'Prestados'),
              OpcionFiltro(FiltroPrestamo.recibidos, 'Recibidos'),
            ],
            onCambio: (v) =>
                ref.read(filtroPrestamoProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroDevolucion>(
            titulo: 'Devolución',
            valor: ref.watch(filtroDevolucionProvider),
            opciones: const [
              OpcionFiltro(FiltroDevolucion.todos, 'Todas'),
              OpcionFiltro(FiltroDevolucion.pendientes, 'Sin devolver'),
              OpcionFiltro(FiltroDevolucion.devueltos, 'Devueltos'),
            ],
            onCambio: (v) =>
                ref.read(filtroDevolucionProvider.notifier).state = v,
          ),
        ),
      ],
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
        IconButton(
          onPressed: () => mostrarOpcionesPdf(
            context,
            documento: DocumentoPdf.prestamo,
            id: prestamo.id,
            numero: prestamo.numero,
          ),
          tooltip: 'PDF',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
        ),
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
      estado: AppEtiqueta(
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
