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
        onVer: () => _verDetalle(context, conductor, color),
        onEditar: () => _abrirFormulario(context, conductor),
        onEstado: () => _cambiarEstado(context, ref, conductor),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Conductor? conductor) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConductorFormulario(conductor: conductor)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Conductor conductor,
  ) async {
    final asignados = conductor.vehiculos;

    final ok = await confirmarAccion(
      context,
      titulo: '${conductor.activo ? 'Desactivar' : 'Activar'} ${conductor.nombre}',
      mensaje: conductor.activo
          ? 'Deja de ofrecerse para repartir y sale de las alertas de licencia. '
                'Su historial se conserva.'
                '${asignados.isEmpty ? '' : ' Sigue asignado a ${asignados.join(', ')}.'}'
          : 'Vuelve a ofrecerse para repartir y su licencia entra otra vez en '
                'las alertas.',
      textoConfirmar: conductor.activo ? 'Desactivar' : 'Activar',
      tono: conductor.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      // El PUT reemplaza el registro entero, asi que se reenvia lo que ya
      // tenia: mandar solo `activo` vaciaria el resto de la ficha.
      await ref.read(conductoresProvider.notifier).guardar(
        id: conductor.id,
        cuerpo: {
          'nombre': conductor.nombre,
          'documento': conductor.documento,
          'telefono': conductor.telefono,
          'direccion': conductor.direccion,
          'licenciaNumero': conductor.licenciaNumero,
          'licenciaCategoria': conductor.licenciaCategoria,
          'licenciaVence': conductor.licenciaVence?.toIso8601String(),
          'foto': conductor.foto,
          'fechaIngreso': conductor.fechaIngreso?.toIso8601String(),
          'observacion': conductor.observacion,
          'activo': !conductor.activo,
        },
      );
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            conductor.activo
                ? '${conductor.nombre} desactivado'
                : '${conductor.nombre} activado',
          ),
        ),
      );
    } on ApiExcepcion catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.texto)));
    }
  }

  /// Ficha de solo lectura.
  ///
  /// Existe para poder consultar al conductor sin entrar al formulario, donde
  /// un toque de mas guarda cambios que nadie queria hacer.
  Future<void> _verDetalle(BuildContext context, Conductor conductor, Color color) {
    final licencia = conductor.vencimientos.isEmpty ? null : conductor.vencimientos.first;
    final estado = etiquetaEstado(conductor.estadoDocumentos);

    return mostrarDetalle(
      context,
      icono: Icons.badge_outlined,
      color: color,
      titulo: conductor.nombre,
      subtitulo: conductor.documento,
      insignia: AppEtiqueta(estado.texto, tono: estado.tono),
      campos: [
        CampoDetalle('Nombre', conductor.nombre),
        CampoDetalle('Documento', conductor.documento),
        CampoDetalle('Teléfono', conductor.telefono),
        CampoDetalle('Dirección', conductor.direccion),
        CampoDetalle('N° de licencia', conductor.licenciaNumero),
        CampoDetalle('Categoría de licencia', conductor.licenciaCategoria),
        if (licencia != null)
          CampoDetalle(
            'Vencimiento de licencia',
            licencia.vence == null ? null : fechaCorta(licencia.vence!),
            widget: FechaConPlazo(licencia),
          ),
        CampoDetalle(
          'Fecha de ingreso',
          conductor.fechaIngreso == null ? null : fechaCorta(conductor.fechaIngreso!),
        ),
        CampoDetalle(
          'Vehículos asignados',
          conductor.vehiculos.isEmpty ? null : conductor.vehiculos.join(', '),
        ),
        CampoDetalle(
          'Estado',
          conductor.activo ? 'Activo' : 'Inactivo',
          widget: insigniaActivo(conductor.activo),
        ),
      ],
      contenidoExtra: [?fotoFicha(conductor.foto)],
    );
  }
}

class _TarjetaConductor extends StatelessWidget {
  const _TarjetaConductor({
    required this.conductor,
    required this.color,
    required this.onVer,
    required this.onEditar,
    required this.onEstado,
  });

  final Conductor conductor;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

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
        widget: insigniaActivo(conductor.activo),
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
          tooltip: conductor.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            conductor.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: conductor.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }
}
