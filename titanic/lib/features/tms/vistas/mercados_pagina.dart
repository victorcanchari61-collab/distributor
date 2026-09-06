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
import '../datos/mercado.dart';
import '../estado/tms_controlador.dart';
import 'mercado_formulario.dart';

/// Listado de mercados: dónde se entrega, un mercado de abastos, una zona
/// con tiendas o una empresa. Lo elige cada cliente en Maestros → Clientes.
class MercadosPagina extends ConsumerWidget {
  const MercadosPagina({super.key});

  static const ruta = '/tms/mercados';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(mercadosProvider).valueOrNull ?? const <Mercado>[];
    final activos = todos.where((m) => m.activo).length;

    return AppListaPagina<Mercado>(
      titulo: 'Mercados',
      ruta: ruta,
      estado: ref.watch(mercadosProvider),
      visibles: ref.watch(mercadosFiltradosProvider),
      busqueda: ref.watch(busquedaMercadosProvider),
      onBuscar: (t) => ref.read(busquedaMercadosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre, dirección, distrito',
      onRecargar: () => ref.read(mercadosProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      textoNuevo: 'Nuevo mercado',
      iconoVacio: Icons.storefront_outlined,
      singular: 'mercado',
      plural: 'mercados',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Mercados',
          valor: '${todos.length}',
          icono: Icons.storefront_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Activos',
          valor: '$activos',
          icono: Icons.check_circle_outline,
        ),
      ],
      fila: (context, mercado) => _TarjetaMercado(
        mercado: mercado,
        color: color,
        onEditar: () => _abrirFormulario(context, mercado),
        onEstado: () => _cambiarEstado(context, ref, mercado),
        onEliminar: () => _eliminar(context, ref, mercado),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Mercado? mercado) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MercadoFormulario(mercado: mercado)),
    );
  }

  Future<void> _cambiarEstado(BuildContext context, WidgetRef ref, Mercado mercado) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${mercado.activo ? 'Desactivar' : 'Activar'} ${mercado.nombre}',
      mensaje: mercado.activo
          ? 'Deja de ofrecerse al dar de alta clientes nuevos. Los que ya lo usan lo conservan.'
          : 'Vuelve a estar disponible para elegirse.',
      textoConfirmar: mercado.activo ? 'Desactivar' : 'Activar',
      tono: mercado.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(mercadosProvider.notifier).cambiarEstado(mercado);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            mercado.activo ? '${mercado.nombre} desactivado' : '${mercado.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, Mercado mercado) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${mercado.nombre}',
      mensaje: mercado.clientes > 0
          ? 'Lo usan ${mercado.clientes} cliente(s), así que no se podrá eliminar. Desactívalo en su lugar.'
          : 'Se borra definitivamente.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(mercadosProvider.notifier).eliminar(mercado.id);
      mensajero.showSnackBar(SnackBar(content: Text('${mercado.nombre} eliminado')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaMercado extends StatelessWidget {
  const _TarjetaMercado({
    required this.mercado,
    required this.color,
    required this.onEditar,
    required this.onEstado,
    required this.onEliminar,
  });

  final Mercado mercado;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;
  final VoidCallback onEliminar;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Dirección', mercado.direccion),
    CampoDetalle('Distrito', mercado.distrito),
    CampoDetalle('Clientes', '${mercado.clientes}'),
    CampoDetalle(
      'Estado',
      mercado.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        mercado.activo ? 'Activo' : 'Inactivo',
        tono: mercado.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.storefront_outlined,
      color: color,
      titulo: mercado.nombre,
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
          tooltip: mercado.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            mercado.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: mercado.activo ? Colores.advertencia : Colores.exito,
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
