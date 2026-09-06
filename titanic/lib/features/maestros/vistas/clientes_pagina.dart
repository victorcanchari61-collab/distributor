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
import '../../../core/tema/colores.dart';
import '../datos/cliente.dart';
import '../estado/maestros_controlador.dart';
import 'cliente_formulario.dart';

/// Listado de clientes.
class ClientesPagina extends ConsumerWidget {
  const ClientesPagina({super.key});

  static const ruta = '/maestros/clientes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(clientesProvider).valueOrNull ?? const <Cliente>[];
    final activos = todos.where((c) => c.activo).toList();
    final rutas = ref.watch(rutasProvider);
    final puestos = ref.watch(filtrosClientesActivosProvider);

    return AppListaPagina<Cliente>(
      titulo: 'Clientes',
      ruta: ruta,
      estado: ref.watch(clientesProvider),
      visibles: ref.watch(clientesFiltradosProvider),
      busqueda: ref.watch(busquedaClientesProvider),
      onBuscar: (t) => ref.read(busquedaClientesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre, documento o punto de reparto',
      onRecargar: () => ref.read(clientesProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      iconoVacio: Icons.contacts_outlined,
      singular: 'cliente',
      plural: 'clientes',
      detalleVacio: puestos > 0
          ? 'Ninguno coincide con los filtros puestos.'
          : null,
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Clientes activos',
          valor: '${activos.length}',
          icono: Icons.contacts_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Desactivados',
          valor: '${todos.length - activos.length}',
          icono: Icons.block,
          tono: todos.length == activos.length
              ? DatoTono.neutral
              : DatoTono.aviso,
          nota: 'no salen en ventas',
        ),
        AppTarjetaDato(
          etiqueta: 'Con ruta',
          valor: '${activos.where((c) => c.ruta != null).length}',
          icono: Icons.route_outlined,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Rutas',
          valor: '${rutas.length}',
          icono: Icons.map_outlined,
          tono: DatoTono.neutral,
          nota: 'de reparto',
        ),
      ],
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref, color),
      ),
      fila: (context, cliente) => _TarjetaCliente(
        cliente: cliente,
        color: color,
        onEditar: () => _abrirFormulario(context, cliente),
        onEstado: () => _cambiarEstado(context, ref, cliente),
      ),
    );
  }

  /// Filtros de la vista. Cada grupo se pinta dentro de un Consumer para que
  /// la pastilla elegida se marque al instante sin cerrar el modal.
  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref, Color color) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosClientesActivosProvider),
      onLimpiar: () {
        ref.read(estadoFiltroProvider.notifier).state = FiltroEstado.activos;
        ref.read(diaVisitaFiltroProvider.notifier).state = null;
        ref.read(rutaFiltroProvider.notifier).state = null;
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
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Dia de visita',
            valor: ref.watch(diaVisitaFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro('LUNES', 'Lunes'),
              OpcionFiltro('MARTES', 'Martes'),
              OpcionFiltro('MIERCOLES', 'Miercoles'),
              OpcionFiltro('JUEVES', 'Jueves'),
              OpcionFiltro('VIERNES', 'Viernes'),
              OpcionFiltro('SABADO', 'Sabado'),
              OpcionFiltro('DOMINGO', 'Domingo'),
            ],
            onCambio: (v) =>
                ref.read(diaVisitaFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            // Las rutas salen de los datos, no de una lista fija.
            final rutas = ref.watch(rutasProvider);
            if (rutas.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Ruta',
              valor: ref.watch(rutaFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todas'),
                for (final r in rutas) OpcionFiltro(r, r),
              ],
              onCambio: (v) => ref.read(rutaFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Cliente? cliente) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClienteFormulario(cliente: cliente)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Cliente cliente,
  ) async {
    // Igual que en el panel web: desactivar nunca ocurre de un toque, primero
    // se avisa que pasa con el registro.
    final ok = await confirmarAccion(
      context,
      titulo: '${cliente.activo ? 'Desactivar' : 'Activar'} ${cliente.nombre}',
      mensaje: cliente.activo
          ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
          : 'Vuelve a estar disponible para usarse.',
      textoConfirmar: cliente.activo ? 'Desactivar' : 'Activar',
      tono: cliente.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(clientesProvider.notifier).cambiarEstado(cliente);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            cliente.activo
                ? '${cliente.nombre} desactivado'
                : '${cliente.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaCliente extends StatelessWidget {
  const _TarjetaCliente({
    required this.cliente,
    required this.color,
    required this.onEditar,
    required this.onEstado,
  });

  final Cliente cliente;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  /// Los mismos datos que muestra la tabla del panel web, en el mismo orden.
  /// Los marcados `enTarjeta: false` solo salen en la ficha de detalle: en el
  /// listado estorban y hacen que entren menos registros en pantalla.
  List<CampoDetalle> get _campos => [
    CampoDetalle('Nombre', cliente.nombre),
    CampoDetalle('Dirección', cliente.direccion),
    CampoDetalle('Distrito', cliente.distrito, enTarjeta: false),
    CampoDetalle('Teléfono', cliente.telefono, enTarjeta: false),
    CampoDetalle(
      'Dia visita',
      cliente.diaVisita,
      widget: cliente.diaVisita == null
          ? null
          : AppEtiqueta(
              cliente.diaVisita!,
              tono: EtiquetaTono.modulo,
              color: color,
            ),
    ),
    CampoDetalle('Ruta', cliente.ruta, enTarjeta: false),
    CampoDetalle('Mercado', cliente.mercado, enTarjeta: false),
    CampoDetalle(
      'Estado',
      cliente.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        cliente.activo ? 'Activo' : 'Inactivo',
        tono: cliente.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.storefront_outlined,
      color: color,
      titulo: cliente.documento,
      insignia: AppEtiqueta(cliente.tipoDoc),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
        ),
        IconButton(
          onPressed: onEstado,
          tooltip: cliente.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            cliente.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: cliente.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.storefront_outlined,
      color: color,
      titulo: cliente.nombre,
      subtitulo: '${cliente.tipoDoc} ${cliente.documento}',
      insignia: cliente.activo
          ? null
          : const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
      campos: _campos,
      acciones: [
        AppBoton(
          texto: cliente.activo ? 'Desactivar' : 'Activar',
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
