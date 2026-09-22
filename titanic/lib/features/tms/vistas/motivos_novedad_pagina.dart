import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/novedad.dart';
import '../estado/novedades_controlador.dart';
import 'motivo_novedad_formulario.dart';

/// Por qué no se entregó algo. El dueño arma su propia lista: cada negocio
/// pierde entregas por razones distintas.
///
/// Cada motivo dice además si la mercadería vuelve: lo que el cliente rechazó
/// viaja de regreso en el camión y hay que contarlo; lo que no se cargó nunca
/// salió del almacén y no hay nada que esperar.
class MotivosNovedadPagina extends ConsumerWidget {
  const MotivosNovedadPagina({super.key});

  static const ruta = '/tms/motivos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos =
        ref.watch(motivosNovedadProvider).valueOrNull ??
        const <MotivoNovedad>[];

    return AppListaPagina<MotivoNovedad>(
      titulo: 'Motivos de novedad',
      ruta: ruta,
      estado: ref.watch(motivosNovedadProvider),
      visibles: ref.watch(motivosNovedadFiltradosProvider),
      busqueda: ref.watch(busquedaMotivosProvider),
      onBuscar: (t) => ref.read(busquedaMotivosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar motivo',
      onRecargar: () => ref.read(motivosNovedadProvider.notifier).recargar(),
      onNuevo: puede(ref, 'tms.motivos', Accion.crear)
          ? () => _abrirFormulario(context, null)
          : null,
      textoNuevo: 'Nuevo motivo',
      iconoVacio: Icons.label_outline,
      singular: 'motivo',
      plural: 'motivos',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Motivos',
          valor: '${todos.length}',
          icono: Icons.label_outline,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Activos',
          valor: '${todos.where((m) => m.activo).length}',
          icono: Icons.check_circle_outline,
        ),
      ],
      filtro: BotonFiltros(
        activos: ref.watch(filtrosMotivosActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, motivo) => _TarjetaMotivo(
        motivo: motivo,
        color: color,
        onVer: () => _verDetalle(context, motivo, color),
        onEditar: puede(ref, 'tms.motivos', Accion.editar)
            ? () => _abrirFormulario(context, motivo)
            : null,
        onEstado: puede(ref, 'tms.motivos', Accion.editar)
            ? () => _cambiarEstado(context, ref, motivo)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosMotivosActivosProvider),
      onLimpiar: () =>
          ref.read(estadoFiltroProvider.notifier).state = FiltroEstado.activos,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroEstado>(
            titulo: 'Estado',
            valor: ref.watch(estadoFiltroProvider),
            opciones: const [
              OpcionFiltro(FiltroEstado.activos, 'Activos'),
              OpcionFiltro(FiltroEstado.inactivos, 'Desactivados'),
              OpcionFiltro(FiltroEstado.todos, 'Todos'),
            ],
            onCambio: (v) => ref.read(estadoFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, MotivoNovedad? motivo) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MotivoNovedadFormulario(motivo: motivo),
      ),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    MotivoNovedad motivo,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${motivo.activo ? 'Desactivar' : 'Activar'} ${motivo.nombre}',
      mensaje: motivo.activo
          ? 'Deja de ofrecerse al entregar pedidos. Las novedades que ya lo usan lo conservan.'
          : 'Vuelve a estar disponible para elegirse.',
      textoConfirmar: motivo.activo ? 'Desactivar' : 'Activar',
      tono: motivo.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(motivosNovedadProvider.notifier).cambiarEstado(motivo);
      mensajero.mostrar(
        motivo.activo
            ? '${motivo.nombre} desactivado'
            : '${motivo.nombre} activado',
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  /// Ficha de solo lectura, para consultar sin entrar al formulario.
  Future<void> _verDetalle(
    BuildContext context,
    MotivoNovedad motivo,
    Color color,
  ) {
    return mostrarDetalle(
      context,
      icono: Icons.label_outline,
      color: color,
      titulo: motivo.nombre,
      subtitulo: motivo.descripcion,
      estado: _insigniaEstado(motivo.activo),
      campos: [
        CampoDetalle('Nombre', motivo.nombre),
        CampoDetalle('Descripción', motivo.descripcion),
        CampoDetalle('La mercadería', _textoRegresa(motivo)),
        CampoDetalle('Usos', '${motivo.usos}'),
        CampoDetalle(
          'Estado',
          motivo.activo ? 'Activo' : 'Inactivo',
          widget: _insigniaEstado(motivo.activo),
        ),
      ],
    );
  }
}

String _textoRegresa(MotivoNovedad m) =>
    m.regresaAlAlmacen ? 'Vuelve al almacén' : 'Nunca salió';

AppEtiqueta _insigniaEstado(bool activo) => AppEtiqueta(
  activo ? 'Activo' : 'Inactivo',
  tono: activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
);

class _TarjetaMotivo extends StatelessWidget {
  const _TarjetaMotivo({
    required this.motivo,
    required this.color,
    required this.onVer,
    this.onEditar,
    this.onEstado,
  });

  final MotivoNovedad motivo;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback? onEditar;
  final VoidCallback? onEstado;

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.label_outline,
      color: color,
      titulo: motivo.nombre,
      campos: [
        CampoDetalle('Descripción', motivo.descripcion),
        CampoDetalle('La mercadería', _textoRegresa(motivo)),
        CampoDetalle('Usos', '${motivo.usos}'),
        CampoDetalle(
          'Estado',
          motivo.activo ? 'Activo' : 'Inactivo',
          widget: _insigniaEstado(motivo.activo),
        ),
      ],
      onTap: onVer,
      acciones: [
        IconButton(
          onPressed: onVer,
          tooltip: 'Ver detalle',
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.visibility_outlined,
            size: 18,
            color: Colores.tintaSuave,
          ),
        ),
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
        if (onEstado != null)
          IconButton(
            onPressed: onEstado,
            tooltip: motivo.activo ? 'Desactivar' : 'Activar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              motivo.activo ? Icons.block : Icons.check_circle_outline,
              size: 18,
              color: motivo.activo ? Colores.advertencia : Colores.exito,
            ),
          ),
      ],
    );
  }
}
