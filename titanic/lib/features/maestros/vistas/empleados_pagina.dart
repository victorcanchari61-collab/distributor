import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/navegacion/menu.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/empleado.dart';
import '../estado/maestros_controlador.dart';
import 'empleado_formulario.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Fecha corta, como se lee en la ficha: 05/03/2024.
String _fechaTexto(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// Listado de empleados: quien trabaja en el negocio.
///
/// Es un maestro y no una cuenta de acceso. Se registra a todos —el estibador
/// que nunca entra al sistema tambien— y al crear un usuario se elige,
/// opcionalmente, a quien pertenece esa cuenta.
class EmpleadosPagina extends ConsumerWidget {
  const EmpleadosPagina({super.key});

  static const ruta = '/rrhh/empleados';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos =
        ref.watch(empleadosProvider).valueOrNull ?? const <Empleado>[];
    final activos = todos.where((e) => e.activo).toList();
    final conUsuario = activos.where((e) => e.usuarioId != null).length;
    final cesados = todos.length - activos.length;
    final puestos = ref.watch(filtrosEmpleadosActivosProvider);

    return AppListaPagina<Empleado>(
      titulo: 'Empleados',
      ruta: ruta,
      estado: ref.watch(empleadosProvider),
      visibles: ref.watch(empleadosFiltradosProvider),
      busqueda: ref.watch(busquedaEmpleadosProvider),
      onBuscar: (t) => ref.read(busquedaEmpleadosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre, documento o cargo',
      onRecargar: () => ref.read(empleadosProvider.notifier).recargar(),
      onNuevo: puede(ref, 'rrhh.empleados', Accion.crear)
          ? () => _abrirFormulario(context, null)
          : null,
      iconoVacio: Icons.groups_outlined,
      singular: 'empleado',
      plural: 'empleados',
      detalleVacio: puestos > 0
          ? 'Ninguno coincide con los filtros puestos.'
          : null,
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Empleados activos',
          valor: '${activos.length}',
          icono: Icons.groups_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Con usuario',
          valor: '$conUsuario',
          icono: Icons.verified_user_outlined,
          tono: DatoTono.exito,
          nota: '${activos.length - conUsuario} no entran al sistema',
        ),
        AppTarjetaDato(
          etiqueta: 'Cesados',
          valor: '$cesados',
          icono: Icons.block,
          tono: cesados > 0 ? DatoTono.aviso : DatoTono.neutral,
          nota: cesados > 0 ? 'conservan su historial' : 'ninguno',
        ),
      ],
      filtro: BotonFiltros(
        activos: puestos,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref, color),
      ),
      fila: (context, empleado) => _TarjetaEmpleado(
        empleado: empleado,
        color: color,
        onEditar: puede(ref, 'rrhh.empleados', Accion.editar)
            ? () => _abrirFormulario(context, empleado)
            : null,
        onEstado: puede(ref, 'rrhh.empleados', Accion.editar)
            ? () => _cambiarEstado(context, ref, empleado)
            : null,
        onEliminar: puede(ref, 'rrhh.empleados', Accion.eliminar)
            ? () => _eliminar(context, ref, empleado)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref, Color color) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosEmpleadosActivosProvider),
      onLimpiar: () {
        ref.read(estadoFiltroProvider.notifier).state = FiltroEstado.activos;
        ref.read(cargoFiltroProvider.notifier).state = null;
        ref.read(areaFiltroProvider.notifier).state = null;
        ref.read(conUsuarioFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroEstado>(
            titulo: 'Estado',
            valor: ref.watch(estadoFiltroProvider),
            opciones: const [
              OpcionFiltro(FiltroEstado.activos, 'Activos'),
              OpcionFiltro(FiltroEstado.inactivos, 'Cesados'),
              OpcionFiltro(FiltroEstado.todos, 'Todos'),
            ],
            onCambio: (v) => ref.read(estadoFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final cargos = ref.watch(cargosProvider);
            if (cargos.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Cargo',
              valor: ref.watch(cargoFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final c in cargos) OpcionFiltro(c, c),
              ],
              onCambio: (v) => ref.read(cargoFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final areas = ref.watch(areasProvider);
            if (areas.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Área',
              valor: ref.watch(areaFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todas'),
                for (final a in areas) OpcionFiltro(a, a),
              ],
              onCambio: (v) => ref.read(areaFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<bool?>(
            titulo: 'Usuario',
            valor: ref.watch(conUsuarioFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro(true, 'Con usuario'),
              OpcionFiltro(false, 'Sin usuario'),
            ],
            onCambio: (v) =>
                ref.read(conUsuarioFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Empleado? empleado) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EmpleadoFormulario(empleado: empleado)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Empleado empleado,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo:
          '${empleado.activo ? 'Desactivar' : 'Activar'} a ${empleado.nombreCompleto}',
      mensaje: empleado.activo
          ? 'Deja de poder elegirse al crear un usuario, pero conserva su ficha y su historial.'
          : 'Vuelve a estar disponible para usarse.',
      textoConfirmar: empleado.activo ? 'Desactivar' : 'Activar',
      tono: empleado.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);

    try {
      await ref.read(empleadosProvider.notifier).cambiarEstado(empleado);
      mensajero.mostrar(
        '${empleado.nombreCompleto} ${empleado.activo ? 'desactivado' : 'activado'}',
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Empleado empleado,
  ) async {
    final mensajero = Aviso.de(context);

    // Con cuenta enlazada el servidor lo rechaza: se dice aqui, con el nombre
    // de la cuenta, en vez de dejar confirmar un borrado que va a fallar.
    if (empleado.usuarioId != null) {
      mensajero.error(
        'No se puede eliminar: la cuenta ${empleado.usuario ?? 'de esta persona'} usa esta ficha. '
        'Desenlázala desde Usuarios o desactiva al empleado.',
      );
      return;
    }

    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar a ${empleado.nombreCompleto}',
      mensaje:
          'Se borra definitivamente y no se puede deshacer. Si la persona dejó de trabajar, '
          'ponle fecha de cese y desactívala en vez de eliminarla.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(empleadosProvider.notifier).eliminar(empleado);
      mensajero.mostrar('${empleado.nombreCompleto} eliminado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaEmpleado extends StatelessWidget {
  const _TarjetaEmpleado({
    required this.empleado,
    required this.color,
    this.onEditar,
    this.onEstado,
    this.onEliminar,
  });

  final Empleado empleado;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onEstado;
  final VoidCallback? onEliminar;

  /// Mismo criterio que en clientes y proveedores: en la tarjeta solo lo que
  /// sirve para reconocer a la persona; el resto vive en la hoja de detalle.
  List<CampoDetalle> get _campos => [
    CampoDetalle('Empleado', empleado.nombreCompleto),
    CampoDetalle(
      'Cargo',
      empleado.cargo,
      widget: empleado.cargo == null
          ? null
          : AppEtiqueta(
              empleado.cargo!,
              tono: EtiquetaTono.modulo,
              color: color,
            ),
    ),
    CampoDetalle('Área', empleado.area, enTarjeta: false),
    CampoDetalle('Teléfono', empleado.telefono),
    CampoDetalle('Correo', empleado.email, enTarjeta: false),
    CampoDetalle('Dirección', empleado.direccion, enTarjeta: false),
    CampoDetalle(
      'Ingreso',
      empleado.fechaIngreso == null
          ? null
          : _fechaTexto(empleado.fechaIngreso!),
      enTarjeta: false,
    ),
    CampoDetalle(
      'Cese',
      empleado.fechaCese == null ? null : _fechaTexto(empleado.fechaCese!),
      enTarjeta: false,
    ),
    // Se dice siempre, tambien cuando no tiene: que alguien no entre al
    // sistema es un dato, no un campo vacio.
    CampoDetalle(
      'Usuario',
      empleado.usuario ?? 'No entra al sistema',
      widget: empleado.usuarioId == null
          ? null
          : AppEtiqueta(
              empleado.usuario!,
              tono: EtiquetaTono.modulo,
              color: color,
            ),
      enTarjeta: false,
    ),
    CampoDetalle('Observación', empleado.observacion, enTarjeta: false),
    CampoDetalle(
      'Estado',
      empleado.activo ? 'Activo' : 'Cesado',
      widget: AppEtiqueta(
        empleado.activo ? 'Activo' : 'Cesado',
        tono: empleado.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.person_outline,
      color: color,
      titulo: empleado.documento,
      insignia: AppEtiqueta(empleado.tipoDoc),
      campos: _campos,
      onTap: () => _abrirDetalle(context),
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
        if (onEstado != null)
          IconButton(
            onPressed: onEstado,
            tooltip: empleado.activo ? 'Desactivar' : 'Activar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              empleado.activo ? Icons.block : Icons.check_circle_outline,
              size: 18,
              color: empleado.activo ? Colores.advertencia : Colores.exito,
            ),
          ),
        if (onEliminar != null)
          IconButton(
            onPressed: onEliminar,
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: Colores.peligro,
            ),
          ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.person_outline,
      color: color,
      titulo: empleado.nombreCompleto,
      subtitulo: '${empleado.tipoDoc} ${empleado.documento}',
      estado: empleado.activo
          ? null
          : const AppEtiqueta('Cesado', tono: EtiquetaTono.aviso),
      campos: _campos,
      acciones: [
        if (onEliminar != null)
          AppBoton(
            texto: 'Eliminar',
            variante: BotonVariante.secundario,
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onEliminar!();
            },
          ),
        if (onEstado != null)
          AppBoton(
            texto: empleado.activo ? 'Desactivar' : 'Activar',
            variante: BotonVariante.secundario,
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onEstado!();
            },
          ),
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
