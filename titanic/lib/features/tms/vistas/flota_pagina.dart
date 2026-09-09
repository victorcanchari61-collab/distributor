import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/flota.dart';
import '../estado/tms_controlador.dart';
import 'tipos_vehiculo_pagina.dart';
import 'vehiculo_formulario.dart';

/// Cómo se pinta cada estado de documento.
///
/// Vive junto a la pantalla y no en el modelo porque es decisión de
/// presentación; el estado en sí lo decide el backend.
({String texto, EtiquetaTono tono}) etiquetaEstado(String estado) => switch (estado) {
  EstadoVencimiento.vencido => (texto: 'Documentos vencidos', tono: EtiquetaTono.peligro),
  EstadoVencimiento.porVencer => (texto: 'Por vencer', tono: EtiquetaTono.aviso),
  EstadoVencimiento.alDia => (texto: 'Al día', tono: EtiquetaTono.exito),
  _ => (texto: 'Sin documentos', tono: EtiquetaTono.neutral),
};

/// Los vehículos de reparto.
///
/// La columna que de verdad se mira no es la placa sino el estado de los
/// documentos: un camión con el SOAT vencido no puede salir, y enterarse la
/// mañana del reparto es enterarse tarde.
class FlotaPagina extends ConsumerWidget {
  const FlotaPagina({super.key});

  static const ruta = '/tms/flota';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final resumen = ref.watch(resumenFlotaProvider).valueOrNull;

    return AppListaPagina<Vehiculo>(
      titulo: 'Flota',
      ruta: ruta,
      estado: ref.watch(vehiculosProvider),
      visibles: ref.watch(vehiculosFiltradosProvider),
      busqueda: ref.watch(busquedaVehiculosProvider),
      onBuscar: (t) => ref.read(busquedaVehiculosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por placa, tipo, marca, conductor',
      onRecargar: () => ref.read(vehiculosProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      textoNuevo: 'Nuevo vehículo',
      iconoVacio: Icons.local_shipping_outlined,
      singular: 'vehículo',
      plural: 'vehículos',
      // Los tipos son el catálogo del que salen los vehículos: se tocan al
      // empezar y casi nunca después, así que van tras un enlace en vez de
      // ocupar una entrada propia del menú.
      encabezado: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TiposVehiculoPagina()),
          ),
          icon: const Icon(Icons.category_outlined, size: 18),
          label: const Text('Tipos de vehículo'),
        ),
      ),
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Vehículos',
          valor: '${resumen?.vehiculos ?? 0}',
          icono: Icons.local_shipping_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Activos',
          valor: '${resumen?.activos ?? 0}',
          icono: Icons.check_circle_outline,
        ),
        AppTarjetaDato(
          etiqueta: 'Documentos vencidos',
          valor: '${resumen?.conDocumentoVencido ?? 0}',
          icono: Icons.gpp_bad_outlined,
          tono: (resumen?.conDocumentoVencido ?? 0) > 0 ? DatoTono.peligro : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Por vencer',
          valor: '${resumen?.porVencer ?? 0}',
          icono: Icons.schedule_outlined,
          tono: (resumen?.porVencer ?? 0) > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
      ],
      fila: (context, vehiculo) => _TarjetaVehiculo(
        vehiculo: vehiculo,
        color: color,
        onEditar: () => _abrirFormulario(context, vehiculo),
        onEliminar: () => _eliminar(context, ref, vehiculo),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Vehiculo? vehiculo) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehiculoFormulario(vehiculo: vehiculo)),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, Vehiculo vehiculo) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${vehiculo.placa}',
      mensaje: 'Se borra definitivamente. Si solo dejó de circular, desactívalo al editarlo.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(vehiculosProvider.notifier).eliminar(vehiculo.id);
      mensajero.showSnackBar(SnackBar(content: Text('${vehiculo.placa} eliminado')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaVehiculo extends StatelessWidget {
  const _TarjetaVehiculo({
    required this.vehiculo,
    required this.color,
    required this.onEditar,
    required this.onEliminar,
  });

  final Vehiculo vehiculo;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  List<CampoDetalle> get _campos {
    final estado = etiquetaEstado(vehiculo.estadoDocumentos);

    return [
      CampoDetalle('Tipo', vehiculo.tipoVehiculo),
      if (vehiculo.descripcion.isNotEmpty) CampoDetalle('Vehículo', vehiculo.descripcion),
      if (vehiculo.capacidadKg != null)
        CampoDetalle('Capacidad', '${formatoNumero(vehiculo.capacidadKg!)} kg'),
      CampoDetalle('Conductor', vehiculo.conductor ?? 'sin asignar'),

      // Cada documento con su plazo, no solo el peor: quien mira la ficha
      // necesita saber CUAL vence, que es lo que va a tener que ir a renovar.
      for (final v in vehiculo.vencimientos)
        if (v.estado != EstadoVencimiento.sinFecha)
          CampoDetalle(
            v.nombre,
            v.plazo,
            widget: AppEtiqueta(v.plazo, tono: etiquetaEstado(v.estado).tono),
          ),

      CampoDetalle(
        'Documentos',
        estado.texto,
        widget: AppEtiqueta(estado.texto, tono: estado.tono),
      ),
      CampoDetalle(
        'Estado',
        vehiculo.activo ? 'Activo' : 'Inactivo',
        widget: AppEtiqueta(
          vehiculo.activo ? 'Activo' : 'Inactivo',
          tono: vehiculo.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.local_shipping_outlined,
      color: color,
      titulo: vehiculo.placa,
      campos: _campos,
      onTap: onEditar,
      acciones: [
        IconButton(
          onPressed: onEditar,
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, size: 18, color: Acento.de(context)),
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
