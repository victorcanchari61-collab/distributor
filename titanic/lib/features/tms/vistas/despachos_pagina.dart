import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/cliente_api.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/despacho.dart';
import '../datos/despacho_api.dart';
import '../estado/despachos_controlador.dart';
import '../estado/tms_controlador.dart';
import 'despacho_formulario.dart';
import 'reporte_carga_hoja.dart';
import '../../../compartido/widgets/app_aviso.dart';

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// Baja un PDF sin formato a elegir (el despacho solo tiene hoja A4) y lo
/// abre con el visor del teléfono.
Future<void> _descargarYAbrir(
  BuildContext context,
  Future<List<int>> Function() traer,
  String nombreArchivo,
) async {
  final mensajero = Aviso.de(context);
  try {
    final bytes = await traer();
    final carpeta = await getTemporaryDirectory();
    final archivo = File('${carpeta.path}/$nombreArchivo.pdf');
    await archivo.writeAsBytes(bytes);
    await OpenFilex.open(archivo.path);
  } on ApiExcepcion catch (e) {
    mensajero.error(e.texto);
  } catch (_) {
    mensajero.error('No pudimos generar el PDF.');
  }
}

/// Despachos: la carga de cada camión. Los pedidos se convierten en venta
/// cuando el repartidor los entrega.
class DespachosPagina extends ConsumerWidget {
  const DespachosPagina({super.key});

  static const ruta = '/tms/despachos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final resumen = ref.watch(resumenDespachosProvider).valueOrNull;
    final puestos = ref.watch(filtrosDespachosActivosProvider);

    return AppListaPagina<Despacho>(
      titulo: 'Despachos',
      ruta: ruta,
      estado: ref.watch(despachosProvider),
      visibles: ref.watch(despachosFiltradosProvider),
      busqueda: ref.watch(busquedaDespachosProvider),
      onBuscar: (t) => ref.read(busquedaDespachosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número, ruta o placa',
      onRecargar: () => ref.read(despachosProvider.notifier).recargar(),
      onNuevo: puede(ref, 'tms.despachos', Accion.crear)
          ? () => _abrirFormulario(context, null)
          : null,
      textoNuevo: 'Nuevo despacho',
      iconoVacio: Icons.local_shipping_outlined,
      singular: 'despacho',
      plural: 'despachos',
      detalleVacio: puestos > 0 ? 'Ninguno coincide con los filtros puestos.' : null,
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Despachos',
          valor: '${resumen?.total ?? 0}',
          icono: Icons.local_shipping_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Armados',
          valor: '${resumen?.armados ?? 0}',
          icono: Icons.inventory_2_outlined,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Pedidos en ruta',
          valor: '${resumen?.pedidosEnRuta ?? 0}',
          nota: 'cargados y sin entregar',
          icono: Icons.inventory_2_outlined,
          tono: DatoTono.aviso,
        ),
      ],
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref, color),
      ),
      fila: (context, despacho) => _TarjetaDespacho(
        despacho: despacho,
        color: color,
        onEditar: puede(ref, 'tms.despachos', Accion.editar) && !despacho.anulado
            ? () => _abrirFormulario(context, despacho)
            : null,
        onAnular: puede(ref, 'tms.despachos', Accion.anular) &&
                !despacho.anulado &&
                despacho.entregados == 0
            ? () => _anular(context, ref, despacho)
            : null,
        puedeExportar: puede(ref, 'tms.despachos', Accion.exportar),
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref, Color color) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosDespachosActivosProvider),
      onLimpiar: () {
        ref.read(estadoDespachoFiltroProvider.notifier).state = null;
        ref.read(rutaDespachoFiltroProvider.notifier).state = null;
        ref.read(vehiculoDespachoFiltroProvider.notifier).state = null;
        ref.read(conductorDespachoFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoDespachoFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro(EstadoDespacho.armado, 'Armados'),
              OpcionFiltro(EstadoDespacho.anulado, 'Anulados'),
            ],
            onCambio: (v) => ref.read(estadoDespachoFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final rutas = ref.watch(rutasActivasProvider);
            if (rutas.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Ruta',
              valor: ref.watch(rutaDespachoFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todas'),
                for (final r in rutas) OpcionFiltro(r.nombre, r.nombre),
              ],
              onCambio: (v) => ref.read(rutaDespachoFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final vehiculos = ref.watch(vehiculosActivosProvider);
            if (vehiculos.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Vehículo',
              valor: ref.watch(vehiculoDespachoFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final v in vehiculos) OpcionFiltro(v.placa, v.placa),
              ],
              onCambio: (v) => ref.read(vehiculoDespachoFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final conductores = ref.watch(conductoresActivosProvider);
            if (conductores.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Conductor',
              valor: ref.watch(conductorDespachoFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final c in conductores) OpcionFiltro(c.nombre, c.nombre),
              ],
              onCambio: (v) => ref.read(conductorDespachoFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Despacho? despacho) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DespachoFormulario(despacho: despacho)),
    );
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, Despacho despacho) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${despacho.numero}',
      mensaje: 'Sus pedidos vuelven a quedar libres para otro despacho.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(despachosProvider.notifier).anular(despacho.id);
      mensajero.mostrar('${despacho.numero} anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaDespacho extends StatelessWidget {
  const _TarjetaDespacho({
    required this.despacho,
    required this.color,
    this.onEditar,
    this.onAnular,
    required this.puedeExportar,
  });

  final Despacho despacho;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onAnular;
  final bool puedeExportar;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Ruta', despacho.ruta),
    CampoDetalle('Vehículo', despacho.vehiculo),
    CampoDetalle('Conductor', despacho.conductor),
    CampoDetalle('Fecha', _fecha(despacho.fecha)),
    CampoDetalle(
      'Entregas',
      '${despacho.entregados} de ${despacho.pedidos}'
          '${despacho.noEntregados > 0 ? ' · ${despacho.noEntregados} no ${despacho.noEntregados == 1 ? 'entregado' : 'entregados'}' : ''}',
    ),
    CampoDetalle('Total', 'S/ ${despacho.total.toStringAsFixed(2)}'),
    if (despacho.usuario != null) CampoDetalle('Registrado por', despacho.usuario),
    if (despacho.observacion != null) CampoDetalle('Observación', despacho.observacion),
  ];

  List<Widget> get _lineas => [
    for (final p in despacho.detalle)
      LineaProductoTarjeta(
        titulo: p.cliente,
        subtitulo:
            '${p.numero} · ${[p.mercado, p.direccion].where((s) => s != null && s.isNotEmpty).join(' — ').ifEmpty('Sin dirección')}',
        filas: [
          [
            ('Total', 'S/ ${p.total.toStringAsFixed(2)}'),
            (
              'Entrega',
              p.noEntregadoMotivo != null
                  ? 'No entregado: ${p.noEntregadoMotivo}'
                  : '${p.notaVentaNumero ?? 'Sin entregar'}'
                        '${p.lineasConNovedad > 0 ? ' · ${p.lineasConNovedad} con novedad' : ''}',
            ),
          ],
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.local_shipping_outlined,
      color: color,
      titulo: despacho.numero,
      estado: AppEtiqueta(
        despacho.anulado ? 'Anulado' : 'Armado',
        tono: despacho.anulado ? EtiquetaTono.peligro : EtiquetaTono.exito,
      ),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        if (puedeExportar) ...[
          IconButton(
            onPressed: () => _descargarYAbrir(
              context,
              () => ClienteApi().archivo('/despacho/${despacho.id}/pdf'),
              'despacho-${despacho.numero}',
            ),
            tooltip: 'PDF de pedidos',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          ),
          IconButton(
            onPressed: () => mostrarReporteCarga(
              context,
              despachoId: despacho.id,
              numero: despacho.numero,
            ),
            tooltip: 'Reporte de carga',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
          ),
          IconButton(
            onPressed: () => _descargarYAbrir(
              context,
              () => DespachoApi(ClienteApi()).pdfClientes(despacho.id),
              'clientes-${despacho.numero}',
            ),
            tooltip: 'Detalle por cliente',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
          ),
        ],
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
      icono: Icons.local_shipping_outlined,
      color: color,
      titulo: despacho.numero,
      subtitulo: '${despacho.ruta} · ${despacho.vehiculo} · ${despacho.conductor}',
      estado: AppEtiqueta(
        despacho.anulado ? 'Anulado' : 'Armado',
        tono: despacho.anulado ? EtiquetaTono.peligro : EtiquetaTono.exito,
      ),
      campos: _campos,
      contenidoExtra: _lineas,
      acciones: [
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

extension _TextoOVacio on String {
  String ifEmpty(String otro) => isEmpty ? otro : this;
}
