import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'conductor_formulario.dart';
import 'flota_pagina.dart';

/// Quienes conducen.
///
/// Lo que de verdad se consulta aquí no es el teléfono sino la licencia: con
/// la licencia vencida no puede salir, y descubrirlo el día del reparto deja
/// un camión cargado sin quien lo lleve.
class ConductoresPagina extends ConsumerWidget {
  const ConductoresPagina({super.key});

  static const ruta = '/tms/conductores';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final resumen = ref.watch(resumenConductoresProvider).valueOrNull;

    return AppListaPagina<Conductor>(
      titulo: 'Conductores',
      ruta: ruta,
      estado: ref.watch(conductoresProvider),
      visibles: ref.watch(conductoresFiltradosProvider),
      busqueda: ref.watch(busquedaConductoresProvider),
      onBuscar: (t) => ref.read(busquedaConductoresProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre, documento, licencia',
      onRecargar: () => ref.read(conductoresProvider.notifier).recargar(),
      onNuevo: () => _abrirFormulario(context, null),
      textoNuevo: 'Nuevo conductor',
      iconoVacio: Icons.badge_outlined,
      singular: 'conductor',
      plural: 'conductores',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Conductores',
          valor: '${resumen?.conductores ?? 0}',
          icono: Icons.badge_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Activos',
          valor: '${resumen?.activos ?? 0}',
          icono: Icons.check_circle_outline,
        ),
        AppTarjetaDato(
          etiqueta: 'Licencia vencida',
          valor: '${resumen?.conLicenciaVencida ?? 0}',
          icono: Icons.gpp_bad_outlined,
          tono: (resumen?.conLicenciaVencida ?? 0) > 0 ? DatoTono.peligro : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Por vencer',
          valor: '${resumen?.porVencer ?? 0}',
          icono: Icons.schedule_outlined,
          tono: (resumen?.porVencer ?? 0) > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
      ],
      fila: (context, conductor) => _TarjetaConductor(
        conductor: conductor,
        color: color,
        onEditar: () => _abrirFormulario(context, conductor),
        onEliminar: () => _eliminar(context, ref, conductor),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Conductor? conductor) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConductorFormulario(conductor: conductor)),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, Conductor conductor) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar ${conductor.nombre}',
      mensaje: conductor.vehiculos.isEmpty
          ? 'Se borra definitivamente. Si solo dejó la empresa, desactívalo al editarlo.'
          : 'Los vehículos que tiene asignados (${conductor.vehiculos.join(', ')}) '
                'se quedan sin conductor habitual, no se eliminan.',
      textoConfirmar: 'Eliminar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(conductoresProvider.notifier).eliminar(conductor.id);
      mensajero.showSnackBar(SnackBar(content: Text('${conductor.nombre} eliminado')));
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }
}

class _TarjetaConductor extends StatelessWidget {
  const _TarjetaConductor({
    required this.conductor,
    required this.color,
    required this.onEditar,
    required this.onEliminar,
  });

  final Conductor conductor;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  List<CampoDetalle> get _campos {
    final licencia = conductor.vencimientos.isEmpty ? null : conductor.vencimientos.first;

    return [
      CampoDetalle('Documento', conductor.documento),
      CampoDetalle('Teléfono', conductor.telefono),
      CampoDetalle(
        'Licencia',
        [
          conductor.licenciaNumero,
          conductor.licenciaCategoria,
        ].where((t) => t != null && t.isNotEmpty).join(' · '),
      ),
      if (licencia != null && licencia.estado != EstadoVencimiento.sinFecha)
        CampoDetalle(
          'Vence',
          licencia.plazo,
          widget: AppEtiqueta(licencia.plazo, tono: etiquetaEstado(licencia.estado).tono),
        ),
      CampoDetalle(
        'Vehículos',
        conductor.vehiculos.isEmpty ? 'sin asignar' : conductor.vehiculos.join(', '),
      ),
      CampoDetalle(
        'Estado',
        conductor.activo ? 'Activo' : 'Inactivo',
        widget: AppEtiqueta(
          conductor.activo ? 'Activo' : 'Inactivo',
          tono: conductor.activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.badge_outlined,
      color: color,
      titulo: conductor.nombre,
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
