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
import '../../../core/tema/colores.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';
import 'usuario_formulario.dart';

/// Quien entra a la plataforma y con que rol.
class UsuariosPagina extends ConsumerWidget {
  const UsuariosPagina({super.key});

  static const ruta = '/config/usuarios';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppListaPagina<Usuario>(
      titulo: 'Usuarios',
      ruta: ruta,
      estado: ref.watch(usuariosProvider),
      visibles: ref.watch(usuariosFiltradosProvider),
      busqueda: ref.watch(busquedaUsuariosProvider),
      onBuscar: (t) => ref.read(busquedaUsuariosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre, correo o rol',
      onRecargar: () => ref.read(usuariosProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      iconoVacio: Icons.person_outline,
      singular: 'usuario',
      plural: 'usuarios',
      fila: (context, usuario) => _TarjetaUsuario(
        usuario: usuario,
        color: resolverRuta(ruta).grupo?.color ?? Colores.marca,
        onEditar: () => _abrirFormulario(context, usuario),
        onEstado: () => _cambiarEstado(context, ref, usuario),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Usuario? usuario) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UsuarioFormulario(usuario: usuario)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Usuario usuario,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${usuario.activo ? 'Desactivar' : 'Activar'} ${usuario.nombre}',
      mensaje: usuario.activo
          ? 'No podrá volver a entrar a la plataforma, pero se conserva su historial y puedes reactivarlo.'
          : 'Vuelve a poder iniciar sesión con su correo de siempre.',
      textoConfirmar: usuario.activo ? 'Desactivar' : 'Activar',
      tono: usuario.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref.read(usuariosProvider.notifier).cambiarEstado(usuario);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            usuario.activo
                ? '${usuario.nombre} desactivado'
                : '${usuario.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaUsuario extends StatelessWidget {
  const _TarjetaUsuario({
    required this.usuario,
    required this.color,
    required this.onEditar,
    required this.onEstado,
  });

  final Usuario usuario;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Correo', usuario.email),
    CampoDetalle(
      'Rol',
      usuario.rol,
      widget: AppEtiqueta(usuario.rol, tono: EtiquetaTono.modulo, color: color),
    ),
    CampoDetalle('DNI', usuario.dni, enTarjeta: false),
    CampoDetalle(
      'Estado',
      usuario.activo ? 'Activo' : 'Inactivo',
      widget: AppEtiqueta(
        usuario.activo ? 'Activo' : 'Inactivo',
        tono: usuario.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.person_outline,
      color: color,
      titulo: usuario.nombre,
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.person_outline,
        color: color,
        titulo: usuario.nombre,
        subtitulo: usuario.email,
        insignia: usuario.activo
            ? null
            : const AppEtiqueta('Inactivo', tono: EtiquetaTono.aviso),
        campos: _campos,
        acciones: [
          AppBoton(
            texto: usuario.activo ? 'Desactivar' : 'Activar',
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
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colores.marca),
        ),
        IconButton(
          onPressed: onEstado,
          tooltip: usuario.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            usuario.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: usuario.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }
}
