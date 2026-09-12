import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
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
        onVer: () => _verDetalle(context, ruta, color),
        onEditar: () => _abrirFormulario(context, ruta),
        onEstado: () => _cambiarEstado(context, ref, ruta),
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

  /// Ficha de solo lectura.
  ///
  /// Existe para poder consultar una ruta sin entrar al formulario, donde un
  /// toque de mas guarda cambios que nadie queria hacer.
  Future<void> _verDetalle(BuildContext context, Ruta ruta, Color color) {
    return mostrarDetalle(
      context,
      icono: Icons.route_outlined,
      color: color,
      titulo: ruta.nombre,
      insignia: _insigniaEstado(ruta.activo),
      campos: [
        CampoDetalle('Nombre', ruta.nombre),
        CampoDetalle('Clientes', '${ruta.clientes}'),
        CampoDetalle(
          'Estado',
          ruta.activo ? 'Activo' : 'Inactivo',
          widget: _insigniaEstado(ruta.activo),
        ),
      ],
    );
  }
}

AppEtiqueta _insigniaEstado(bool activo) => AppEtiqueta(
  activo ? 'Activo' : 'Inactivo',
  tono: activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
);

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({
    required this.ruta,
    required this.color,
    required this.onVer,
    required this.onEditar,
    required this.onEstado,
  });

  final Ruta ruta;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Clientes', '${ruta.clientes}'),
    CampoDetalle(
      'Estado',
      ruta.activo ? 'Activo' : 'Inactivo',
      widget: _insigniaEstado(ruta.activo),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.route_outlined,
      color: color,
      titulo: ruta.nombre,
      campos: _campos,
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
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
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
      ],
    );
  }
}
