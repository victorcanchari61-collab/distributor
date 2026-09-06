import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../datos/ruta.dart';
import '../estado/tms_controlador.dart';
import 'ruta_formulario.dart';

/// Listado de rutas de reparto. Lo elige cada cliente en Maestros → Clientes.
class RutasPagina extends ConsumerWidget {
  const RutasPagina({super.key});

  static const ruta = '/tms/rutas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas = ref.watch(rutasProvider).valueOrNull ?? const <Ruta>[];
    final activas = todas.where((r) => r.activo).length;

    return AppListaPagina<Ruta>(
      titulo: 'Rutas',
      ruta: ruta,
      estado: ref.watch(rutasProvider),
      visibles: ref.watch(rutasFiltradasProvider),
      busqueda: ref.watch(busquedaRutasProvider),
      onBuscar: (t) => ref.read(busquedaRutasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre',
      onRecargar: () => ref.read(rutasProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      textoNuevo: 'Nueva ruta',
      iconoVacio: Icons.route_outlined,
      singular: 'ruta',
      plural: 'rutas',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Rutas',
          valor: '${todas.length}',
          icono: Icons.route_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Activas',
          valor: '$activas',
          icono: Icons.check_circle_outline,
        ),
      ],
      fila: (context, ruta) => _TarjetaRuta(
        ruta: ruta,
        color: color,
        onEditar: () => _abrirFormulario(context, ruta),
        onEstado: () => _cambiarEstado(context, ref, ruta),
        onEliminar: () => _eliminar(context, ref, ruta),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Ruta? ruta) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RutaFormulario(ruta: ruta)),
    );
  }

  Future<void> _cambiarEstado(BuildContext context, WidgetRef ref, Ruta ruta) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${ruta.activo ? 'Desactivar' : 'Activar'} ${ruta.nombre}',
      mensaje: ruta.activo
          ? 'Deja de ofrecerse al dar de alta clientes nuevos. Los que ya la usan la conservan.'
          : 'Vuelve a estar disponible para elegirse.',
      textoConfirmar: ruta.activo ? 'Desactivar' : 'Activar',
      tono: ruta.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(rutasProvider.notifier).cambiarEstado(ruta);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(ruta.activo ? '${ruta.nombre} desactivada' : '${ruta.nombre} activada'),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, Ruta ruta) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${ruta.nombre}',
      mensaje: ruta.clientes > 0
          ? 'La usan ${ruta.clientes} cliente(s), así que no se podrá eliminar. Desactívala en su lugar.'
          : 'Se borra definitivamente.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(rutasProvider.notifier).eliminar(ruta.id);
      mensajero.showSnackBar(SnackBar(content: Text('${ruta.nombre} eliminada')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({
    required this.ruta,
    required this.color,
    required this.onEditar,
    required this.onEstado,
    required this.onEliminar,
  });

  final Ruta ruta;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;
  final VoidCallback onEliminar;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Clientes', '${ruta.clientes}'),
    CampoDetalle(
      'Estado',
      ruta.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        ruta.activo ? 'Activo' : 'Inactivo',
        tono: ruta.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.route_outlined,
      color: color,
      titulo: ruta.nombre,
      campos: _campos,
      onTap: onEditar,
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
        ),
        IconButton(
          onPressed: onEstado,
          tooltip: ruta.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            ruta.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: ruta.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
        IconButton(
          onPressed: onEliminar,
          tooltip: 'Eliminar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline, size: 18, color: Colores.peligro),
        ),
      ],
    );
  }
}
