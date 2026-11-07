import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/solicitud_compra.dart';
import '../estado/compras_controlador.dart';
import 'solicitud_compra_formulario.dart';

/// Las solicitudes de compra: lo que el almacén pide que se compre.
///
/// Es un documento interno. El almacenero pide aquí lo que hace falta; Compras la revisa y de ella sale la orden de
/// compra, que es la que va al proveedor. Quien solo puede pedir ve únicamente las suyas.
class SolicitudesCompraPagina extends ConsumerWidget {
  const SolicitudesCompraPagina({super.key});

  static const ruta = '/compras/solicitudes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas =
        ref.watch(solicitudesCompraProvider).valueOrNull ??
        const <SolicitudCompra>[];
    final pendientes = todas.where((s) => s.estaPendiente).length;
    final urgentes = todas.where((s) => s.estaPendiente && s.esUrgente).length;
    final atendidas = todas
        .where((s) => s.estado == EstadoSolicitudCompra.atendida)
        .length;
    final estadoFiltro = ref.watch(estadoSolicitudFiltroProvider);

    return AppListaPagina<SolicitudCompra>(
      titulo: 'Solicitudes de compra',
      ruta: ruta,
      estado: ref.watch(solicitudesCompraProvider),
      visibles: ref.watch(solicitudesCompraFiltradasProvider),
      busqueda: ref.watch(busquedaSolicitudesProvider),
      onBuscar: (t) => ref.read(busquedaSolicitudesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número o almacén',
      onRecargar: () => ref.read(solicitudesCompraProvider.notifier).recargar(),
      onNuevo: puede(ref, 'compras.solicitudes', Accion.crear)
          ? () => _abrirFormulario(context, ref, null)
          : null,
      textoNuevo: 'Nueva solicitud',
      iconoVacio: Icons.edit_note_outlined,
      singular: 'solicitud de compra',
      plural: 'solicitudes de compra',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Pendientes',
          valor: '$pendientes',
          icono: Icons.hourglass_empty,
          tono: pendientes > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Urgentes',
          valor: '$urgentes',
          icono: Icons.priority_high,
          tono: urgentes > 0 ? DatoTono.peligro : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Atendidas',
          valor: '$atendidas',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
      ],
      filtro: BotonFiltros(
        activos: estadoFiltro == null ? 0 : 1,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, solicitud) => _TarjetaSolicitud(
        solicitud: solicitud,
        color: color,
        onVer: () => _abrirDetalle(context, ref, solicitud, color),
        onEditar:
            puede(ref, 'compras.solicitudes', Accion.editar) &&
                solicitud.estaPendiente
            ? () => _abrirFormulario(context, ref, solicitud)
            : null,
        onAnular:
            puede(ref, 'compras.solicitudes', Accion.anular) &&
                solicitud.estaPendiente
            ? () => _anular(context, ref, solicitud)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(estadoSolicitudFiltroProvider) == null ? 0 : 1,
      onLimpiar: () =>
          ref.read(estadoSolicitudFiltroProvider.notifier).state = null,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoSolicitudFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todas'),
              OpcionFiltro(EstadoSolicitudCompra.pendiente, 'Pendientes'),
              OpcionFiltro(EstadoSolicitudCompra.atendida, 'Atendidas'),
              OpcionFiltro(EstadoSolicitudCompra.rechazada, 'Rechazadas'),
              OpcionFiltro(EstadoSolicitudCompra.anulada, 'Anuladas'),
            ],
            onCambio: (v) =>
                ref.read(estadoSolicitudFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  /// Las líneas no vienen en el listado: se piden completas antes de abrir el formulario o el detalle.
  Future<SolicitudCompra?> _completa(
    BuildContext context,
    WidgetRef ref,
    SolicitudCompra solicitud,
  ) async {
    final mensajero = Aviso.de(context);
    try {
      return await ref
          .read(comprasApiProvider)
          .solicitudCompra(solicitud.id);
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
      return null;
    }
  }

  Future<void> _abrirFormulario(
    BuildContext context,
    WidgetRef ref,
    SolicitudCompra? solicitud,
  ) async {
    var completa = solicitud;
    if (solicitud != null) {
      completa = await _completa(context, ref, solicitud);
      if (completa == null || !context.mounted) return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SolicitudCompraFormulario(solicitud: completa),
      ),
    );
  }

  Future<void> _abrirDetalle(
    BuildContext context,
    WidgetRef ref,
    SolicitudCompra solicitud,
    Color color,
  ) async {
    final completa = await _completa(context, ref, solicitud);
    if (completa == null || !context.mounted) return;

    await mostrarDetalle(
      context,
      icono: Icons.edit_note_outlined,
      color: color,
      titulo: completa.numero,
      subtitulo: completa.almacen,
      estado: AppEtiqueta(
        _etiquetaEstado(completa.estado),
        tono: _tonoEstado(completa.estado),
      ),
      campos: _campos(completa),
      contenidoExtra: [
        for (final linea in completa.detalle)
          LineaProductoTarjeta(
            titulo: linea.producto,
            subtitulo:
                '${linea.codigo} · ${linea.presentacion ?? linea.unidadBase}',
            filas: [
              [
                ('Cantidad', formatoNumero(linea.cantidadPresentacion)),
                (
                  'En ${linea.unidadBase}',
                  formatoNumero(linea.cantidad),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    SolicitudCompra solicitud,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${solicitud.numero}',
      mensaje: 'Se retira la solicitud: Compras ya no la verá para atender.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(solicitudesCompraProvider.notifier).anular(solicitud.id);
      mensajero.mostrar('${solicitud.numero} anulada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

EtiquetaTono _tonoEstado(String estado) => switch (estado) {
  EstadoSolicitudCompra.atendida => EtiquetaTono.exito,
  EstadoSolicitudCompra.rechazada => EtiquetaTono.peligro,
  EstadoSolicitudCompra.anulada => EtiquetaTono.neutral,
  _ => EtiquetaTono.aviso,
};

String _etiquetaEstado(String estado) => switch (estado) {
  EstadoSolicitudCompra.atendida => 'Atendida',
  EstadoSolicitudCompra.rechazada => 'Rechazada',
  EstadoSolicitudCompra.anulada => 'Anulada',
  _ => 'Pendiente',
};

List<CampoDetalle> _campos(SolicitudCompra s) => [
  CampoDetalle('Fecha', _fecha(s.fecha)),
  CampoDetalle('Almacén', s.almacen),
  CampoDetalle('Urgencia', s.esUrgente ? 'Urgente' : 'Normal'),
  CampoDetalle('Productos', '${s.lineas}'),
  if (s.solicitante != null) CampoDetalle('Pidió', s.solicitante),
  if (s.observacion != null) CampoDetalle('Motivo', s.observacion),
  if (s.motivoRechazo != null)
    CampoDetalle('Compras la rechazó', s.motivoRechazo),
  if (s.ordenes.isNotEmpty)
    CampoDetalle('Orden de compra', s.ordenes.map((o) => o.numero).join(', ')),
];

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud({
    required this.solicitud,
    required this.color,
    required this.onVer,
    this.onEditar,
    this.onAnular,
  });

  final SolicitudCompra solicitud;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback? onEditar;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.edit_note_outlined,
      color: color,
      titulo: solicitud.numero,
      estado: AppEtiqueta(
        _etiquetaEstado(solicitud.estado),
        tono: _tonoEstado(solicitud.estado),
      ),
      campos: [
        // Lo urgente se ve primero: es lo que Compras tiene que mirar.
        if (solicitud.esUrgente && solicitud.estaPendiente)
          const CampoDetalle('Urgencia', 'Urgente'),
        ..._campos(solicitud).where((c) => c.etiqueta != 'Urgencia'),
      ],
      onTap: onVer,
      acciones: [
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: Acento.de(context),
            ),
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
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
