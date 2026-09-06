import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';
import 'rol_formulario.dart';

/// Roles que se pueden asignar a un usuario.
class RolesPagina extends ConsumerWidget {
  const RolesPagina({super.key});

  static const ruta = '/config/roles';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppListaPagina<Rol>(
      titulo: 'Roles',
      ruta: ruta,
      estado: ref.watch(rolesProvider),
      visibles: ref.watch(rolesFiltradosProvider),
      busqueda: ref.watch(busquedaRolesProvider),
      onBuscar: (t) => ref.read(busquedaRolesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre o descripción',
      onRecargar: () => ref.read(rolesProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      iconoVacio: Icons.verified_user_outlined,
      singular: 'rol',
      plural: 'roles',
      fila: (context, rol) => _TarjetaRol(
        rol: rol,
        color: resolverRuta(ruta).grupo?.color ?? Colores.marca,
        onEditar: () => _abrirFormulario(context, rol),
        onEstado: () => _cambiarEstado(context, ref, rol),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Rol? rol) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RolFormulario(rol: rol)));
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Rol rol,
  ) async {
    final mensajero = ScaffoldMessenger.of(context);

    // El rol protegido es el que sostiene el sistema: se avisa aqui en vez de
    // dejar que el backend responda un error despues de la confirmacion.
    if (rol.protegido && rol.activo) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('El rol Administrador no se puede desactivar.'),
        ),
      );
      return;
    }

    final ok = await confirmarAccion(
      context,
      titulo: '${rol.activo ? 'Desactivar' : 'Activar'} ${rol.nombre}',
      mensaje: rol.activo
          ? 'Deja de poder asignarse a nuevos usuarios. Los ${rol.usuarios} que ya lo tienen lo conservan.'
          : 'Vuelve a estar disponible para asignarse.',
      textoConfirmar: rol.activo ? 'Desactivar' : 'Activar',
      tono: rol.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(rolesProvider.notifier).cambiarEstado(rol);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            rol.activo ? '${rol.nombre} desactivado' : '${rol.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaRol extends StatelessWidget {
  const _TarjetaRol({
    required this.rol,
    required this.color,
    required this.onEditar,
    required this.onEstado,
  });

  final Rol rol;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Descripción', rol.descripcion),
    CampoDetalle(
      'Usuarios',
      '${rol.usuarios}',
      widget: AppEtiqueta(
        '${rol.usuarios}',
        tono: EtiquetaTono.modulo,
        color: color,
      ),
    ),
    CampoDetalle(
      'Origen',
      rol.delSistema ? 'Del sistema' : 'Creado aquí',
      enTarjeta: false,
    ),
    CampoDetalle(
      'Estado',
      rol.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        rol.activo ? 'Activo' : 'Inactivo',
        tono: rol.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.verified_user_outlined,
      color: color,
      titulo: rol.nombre,
      insignia: rol.protegido
          ? const AppEtiqueta('Protegido', tono: EtiquetaTono.aviso)
          : null,
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.verified_user_outlined,
        color: color,
        titulo: rol.nombre,
        subtitulo: rol.descripcion,
        insignia: rol.protegido
            ? const AppEtiqueta('Protegido', tono: EtiquetaTono.aviso)
            : null,
        campos: _campos,
        acciones: [
          AppBoton(
            texto: rol.activo ? 'Desactivar' : 'Activar',
            variante: BotonVariante.secundario,
            onPressed: () {
              Navigator.of(context).pop();
              onEstado();
            },
          ),
          AppBoton(
            texto: 'Editar',
            onPressed: () {
              Navigator.of(context).pop();
              onEditar();
            },
          ),
        ],
      ),
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
        ),
        IconButton(
          onPressed: onEstado,
          tooltip: rol.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            rol.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: rol.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }
}
