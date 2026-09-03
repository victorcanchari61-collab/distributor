import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/estado/filtro_estado.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../datos/almacen.dart';
import '../estado/inventario_controlador.dart';
import 'almacen_formulario.dart';

/// Listado de almacenes.
class AlmacenesPagina extends ConsumerWidget {
  const AlmacenesPagina({super.key});

  static const ruta = '/inv/almacenes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(almacenesProvider).valueOrNull ?? const <Almacen>[];
    final activos = todos.where((a) => a.activo).toList();
    final valorTotal = todos.fold<double>(0, (n, a) => n + a.valorizado);
    final puestos = ref.watch(filtrosAlmacenesActivosProvider);

    return AppListaPagina<Almacen>(
      titulo: 'Almacenes',
      ruta: ruta,
      estado: ref.watch(almacenesProvider),
      visibles: ref.watch(almacenesFiltradosProvider),
      busqueda: ref.watch(busquedaAlmacenesProvider),
      onBuscar: (t) => ref.read(busquedaAlmacenesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por código, nombre o dirección',
      onRecargar: () => ref.read(almacenesProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      iconoVacio: Icons.warehouse_outlined,
      singular: 'almacén',
      plural: 'almacenes',
      detalleVacio: puestos > 0
          ? 'Ninguno coincide con los filtros puestos.'
          : null,
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Almacenes activos',
          valor: '${activos.length}',
          icono: Icons.warehouse_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Desactivados',
          valor: '${todos.length - activos.length}',
          icono: Icons.block,
          tono: todos.length == activos.length
              ? DatoTono.neutral
              : DatoTono.aviso,
          nota: 'no reciben movimientos',
        ),
        AppTarjetaDato(
          etiqueta: 'Valor total',
          valor: 'S/ ${valorTotal.toStringAsFixed(2)}',
          icono: Icons.payments_outlined,
          tono: DatoTono.exito,
          nota: 'al costo de compra',
        ),
      ],
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, almacen) => _TarjetaAlmacen(
        almacen: almacen,
        color: color,
        onEditar: () => _abrirFormulario(context, almacen),
        onEstado: () => _cambiarEstado(context, ref, almacen),
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosAlmacenesActivosProvider),
      onLimpiar: () {
        ref.read(estadoFiltroProvider.notifier).state = FiltroEstado.activos;
      },
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

  Future<void> _abrirFormulario(BuildContext context, Almacen? almacen) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AlmacenFormulario(almacen: almacen)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Almacen almacen,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${almacen.activo ? 'Desactivar' : 'Activar'} ${almacen.nombre}',
      mensaje: almacen.activo
          ? 'Deja de recibir movimientos nuevos. Su historial se conserva.'
          : 'Vuelve a estar disponible para movimientos.',
      textoConfirmar: almacen.activo ? 'Desactivar' : 'Activar',
      tono: almacen.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(almacenesProvider.notifier).cambiarEstado(almacen);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            almacen.activo
                ? '${almacen.nombre} desactivado'
                : '${almacen.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaAlmacen extends StatelessWidget {
  const _TarjetaAlmacen({
    required this.almacen,
    required this.color,
    required this.onEditar,
    required this.onEstado,
  });

  final Almacen almacen;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Dirección', almacen.direccion),
    CampoDetalle('Productos', '${almacen.productos}'),
    CampoDetalle('Valorizado', 'S/ ${almacen.valorizado.toStringAsFixed(2)}'),
    CampoDetalle(
      'Estado',
      almacen.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        almacen.activo ? 'Activo' : 'Inactivo',
        tono: almacen.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.warehouse_outlined,
      color: color,
      titulo: almacen.nombre,
      insignia: almacen.esPrincipal
          ? AppEtiqueta('Principal', tono: EtiquetaTono.modulo, color: color)
          : AppEtiqueta(almacen.codigo),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
        ),
        // El principal siempre esta activo: no se ofrece apagarlo.
        if (!almacen.esPrincipal)
          IconButton(
            onPressed: onEstado,
            tooltip: almacen.activo ? 'Desactivar' : 'Activar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              almacen.activo ? Icons.block : Icons.check_circle_outline,
              size: 18,
              color: almacen.activo ? Colores.advertencia : Colores.exito,
            ),
          ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.warehouse_outlined,
      color: color,
      titulo: almacen.nombre,
      subtitulo: almacen.codigo,
      insignia: !almacen.activo
          ? const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso)
          : almacen.esPrincipal
          ? AppEtiqueta('Principal', tono: EtiquetaTono.modulo, color: color)
          : null,
      campos: _campos,
      acciones: [
        if (!almacen.esPrincipal)
          AppBoton(
            texto: almacen.activo ? 'Desactivar' : 'Activar',
            variante: BotonVariante.secundario,
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onEstado();
            },
          ),
        AppBoton(
          texto: 'Editar',
          expandido: true,
          onPressed: () {
            Navigator.of(context).pop();
            onEditar();
          },
        ),
      ],
    );
  }
}
