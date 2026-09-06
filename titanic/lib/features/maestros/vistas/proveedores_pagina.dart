import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../core/navegacion/menu.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/proveedor.dart';
import '../estado/maestros_controlador.dart';
import 'proveedor_formulario.dart';

/// Listado de proveedores.
class ProveedoresPagina extends ConsumerWidget {
  const ProveedoresPagina({super.key});

  static const ruta = '/maestros/proveedores';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos =
        ref.watch(proveedoresProvider).valueOrNull ?? const <Proveedor>[];
    final activos = todos.where((p) => p.activo).toList();
    final rubros = ref.watch(rubrosProvider);
    final puestos = ref.watch(filtrosProveedoresActivosProvider);

    return AppListaPagina<Proveedor>(
      titulo: 'Proveedores',
      ruta: ruta,
      estado: ref.watch(proveedoresProvider),
      visibles: ref.watch(proveedoresFiltradosProvider),
      busqueda: ref.watch(busquedaProveedoresProvider),
      onBuscar: (t) => ref.read(busquedaProveedoresProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por razon social, documento o rubro',
      onRecargar: () => ref.read(proveedoresProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      iconoVacio: Icons.business_outlined,
      singular: 'proveedor',
      plural: 'proveedores',
      detalleVacio: puestos > 0
          ? 'Ninguno coincide con los filtros puestos.'
          : null,
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Proveedores activos',
          valor: '${activos.length}',
          icono: Icons.business_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Desactivados',
          valor: '${todos.length - activos.length}',
          icono: Icons.block,
          tono: todos.length == activos.length
              ? DatoTono.neutral
              : DatoTono.aviso,
          nota: 'no salen en compras',
        ),
        AppTarjetaDato(
          etiqueta: 'Con rubro',
          valor: '${activos.where((p) => p.rubro != null).length}',
          icono: Icons.category_outlined,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Rubros',
          valor: '${rubros.length}',
          icono: Icons.sell_outlined,
          tono: DatoTono.neutral,
          nota: 'distintos',
        ),
      ],
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref, color),
      ),
      fila: (context, proveedor) => _TarjetaProveedor(
        proveedor: proveedor,
        color: color,
        onEditar: () => _abrirFormulario(context, proveedor),
        onEstado: () => _cambiarEstado(context, ref, proveedor),
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref, Color color) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosProveedoresActivosProvider),
      onLimpiar: () {
        ref.read(estadoFiltroProvider.notifier).state = FiltroEstado.activos;
        ref.read(rubroFiltroProvider.notifier).state = null;
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
        Consumer(
          builder: (context, ref, _) {
            final rubros = ref.watch(rubrosProvider);
            if (rubros.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Rubro',
              valor: ref.watch(rubroFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final r in rubros) OpcionFiltro(r, r),
              ],
              onCambio: (v) => ref.read(rubroFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Proveedor? proveedor) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProveedorFormulario(proveedor: proveedor),
      ),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Proveedor proveedor,
  ) async {
    // Igual que en el panel web: desactivar nunca ocurre de un toque, primero
    // se avisa que pasa con el registro.
    final ok = await confirmarAccion(
      context,
      titulo:
          '${proveedor.activo ? 'Desactivar' : 'Activar'} ${proveedor.nombre}',
      mensaje: proveedor.activo
          ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
          : 'Vuelve a estar disponible para usarse.',
      textoConfirmar: proveedor.activo ? 'Desactivar' : 'Activar',
      tono: proveedor.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(proveedoresProvider.notifier).cambiarEstado(proveedor);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            proveedor.activo
                ? '${proveedor.nombre} desactivado'
                : '${proveedor.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaProveedor extends StatelessWidget {
  const _TarjetaProveedor({
    required this.proveedor,
    required this.color,
    required this.onEditar,
    required this.onEstado,
  });

  final Proveedor proveedor;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  /// Mismo criterio que en clientes: en la tarjeta solo lo que sirve para
  /// reconocer al proveedor; el resto vive en la ficha de detalle.
  List<CampoDetalle> get _campos => [
    CampoDetalle('Razón social', proveedor.nombre),
    CampoDetalle(
      'Nombre comercial',
      proveedor.nombreComercial,
      enTarjeta: false,
    ),
    CampoDetalle(
      'Rubro',
      proveedor.rubro,
      widget: proveedor.rubro == null
          ? null
          : AppEtiqueta(
              proveedor.rubro!,
              tono: EtiquetaTono.modulo,
              color: color,
            ),
    ),
    CampoDetalle('Dirección', proveedor.direccion, enTarjeta: false),
    CampoDetalle('Distrito', proveedor.distrito, enTarjeta: false),
    CampoDetalle('Teléfono', proveedor.telefono),
    CampoDetalle('Correo', proveedor.email, enTarjeta: false),
    CampoDetalle(
      'Estado',
      proveedor.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        proveedor.activo ? 'Activo' : 'Inactivo',
        tono: proveedor.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.business_outlined,
      color: color,
      titulo: proveedor.documento,
      insignia: AppEtiqueta(proveedor.tipoDoc),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
        ),
        IconButton(
          onPressed: onEstado,
          tooltip: proveedor.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            proveedor.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: proveedor.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.business_outlined,
      color: color,
      titulo: proveedor.nombreComercial?.isNotEmpty == true
          ? proveedor.nombreComercial!
          : proveedor.nombre,
      subtitulo: '${proveedor.tipoDoc} ${proveedor.documento}',
      insignia: proveedor.activo
          ? null
          : const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
      campos: _campos,
      acciones: [
        AppBoton(
          texto: proveedor.activo ? 'Desactivar' : 'Activar',
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
