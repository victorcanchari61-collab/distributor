import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
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
import '../../../core/tema/dimensiones.dart';
import '../datos/flota.dart';
import '../datos/flota_api.dart';
import '../estado/tms_controlador.dart';
import 'tipos_vehiculo_pagina.dart';
import 'vehiculo_formulario.dart';
import '../../../compartido/widgets/app_aviso.dart';

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
        onVer: () => _verDetalle(context, vehiculo, color),
        onEditar: () => _abrirFormulario(context, vehiculo),
        onEstado: () => _cambiarEstado(context, ref, vehiculo),
      ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Vehiculo? vehiculo) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehiculoFormulario(vehiculo: vehiculo)),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Vehiculo vehiculo,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${vehiculo.activo ? 'Desactivar' : 'Activar'} ${vehiculo.placa}',
      mensaje: vehiculo.activo
          ? 'Deja de ofrecerse para repartir y sale de las alertas de documentos. '
                'Su historial se conserva.'
          : 'Vuelve a ofrecerse para repartir y sus documentos entran otra vez '
                'en las alertas.',
      textoConfirmar: vehiculo.activo ? 'Desactivar' : 'Activar',
      tono: vehiculo.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      // El PUT reemplaza el registro entero, asi que se reenvia lo que ya
      // tenia: mandar solo `activo` vaciaria el resto de la ficha.
      await ref.read(vehiculosProvider.notifier).guardar(
        id: vehiculo.id,
        cuerpo: {
          'placa': vehiculo.placa,
          'tipoVehiculoId': vehiculo.tipoVehiculoId,
          'marca': vehiculo.marca,
          'modelo': vehiculo.modelo,
          'anio': vehiculo.anio,
          'color': vehiculo.color,
          'capacidadKg': vehiculo.capacidadKg,
          'soatNumero': vehiculo.soatNumero,
          'soatVence': vehiculo.soatVence?.toIso8601String(),
          'revisionTecnicaVence': vehiculo.revisionTecnicaVence?.toIso8601String(),
          'permisoCirculacionVence': vehiculo.permisoCirculacionVence?.toIso8601String(),
          'foto': vehiculo.foto,
          'conductorId': vehiculo.conductorId,
          'observacion': vehiculo.observacion,
          'activo': !vehiculo.activo,
        },
      );
      mensajero.mostrar(vehiculo.activo
                ? '${vehiculo.placa} desactivado'
                : '${vehiculo.placa} activado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  /// Ficha de solo lectura.
  ///
  /// Existe para poder consultar el vehiculo sin entrar al formulario, donde
  /// un toque de mas guarda cambios que nadie queria hacer.
  Future<void> _verDetalle(BuildContext context, Vehiculo vehiculo, Color color) {
    final estado = etiquetaEstado(vehiculo.estadoDocumentos);

    return mostrarDetalle(
      context,
      icono: Icons.local_shipping_outlined,
      color: color,
      titulo: vehiculo.placa,
      subtitulo: vehiculo.descripcion.isEmpty
          ? vehiculo.tipoVehiculo
          : vehiculo.descripcion,
      estado: AppEtiqueta(estado.texto, tono: estado.tono),
      campos: [
        CampoDetalle('Placa', vehiculo.placa),
        CampoDetalle('Tipo', vehiculo.tipoVehiculo),
        CampoDetalle('Marca', vehiculo.marca),
        CampoDetalle('Modelo', vehiculo.modelo),
        CampoDetalle('Año', vehiculo.anio?.toString()),
        CampoDetalle('Color', vehiculo.color),
        CampoDetalle(
          'Capacidad',
          vehiculo.capacidadKg == null
              ? null
              : '${formatoNumero(vehiculo.capacidadKg!)} kg',
        ),
        CampoDetalle('Conductor', vehiculo.conductor),
        CampoDetalle('N° de SOAT', vehiculo.soatNumero),

        // Cada documento con su fecha Y su plazo: la fecha dice cuando vence,
        // el plazo dice si hay que correr a renovarlo.
        for (final v in vehiculo.vencimientos)
          CampoDetalle(
            v.nombre,
            v.vence == null ? null : fechaCorta(v.vence!),
            widget: FechaConPlazo(v),
          ),

        CampoDetalle(
          'Estado',
          vehiculo.activo ? 'Activo' : 'Inactivo',
          widget: insigniaActivo(vehiculo.activo),
        ),
      ],
      contenidoExtra: [?fotoFicha(vehiculo.foto)],
    );
  }
}

/// La etiqueta de activo / inactivo, igual en toda la flota.
AppEtiqueta insigniaActivo(bool activo) => AppEtiqueta(
  activo ? 'Activo' : 'Inactivo',
  tono: activo ? EtiquetaTono.exito : EtiquetaTono.aviso,
);

/// dd/mm/aaaa.
String fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// Fecha de vencimiento con su plazo debajo, para las hojas de detalle.
class FechaConPlazo extends StatelessWidget {
  const FechaConPlazo(this.vencimiento, {super.key});

  final Vencimiento vencimiento;

  @override
  Widget build(BuildContext context) {
    final vence = vencimiento.vence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          vence == null ? '—' : fechaCorta(vence),
          style: TextStyle(
            fontSize: 12,
            color: vence == null ? Colores.tintaTenue : Colores.tinta,
          ),
        ),
        const SizedBox(height: 2),
        AppEtiqueta(vencimiento.plazo, tono: etiquetaEstado(vencimiento.estado).tono),
      ],
    );
  }
}

/// Recuadro con la foto del registro, o nada si no tiene.
///
/// Devuelve null en vez de un hueco vacio porque la mayoria de fichas viejas
/// no tienen foto y un marco gris de 180 px solo estorba.
Widget? fotoFicha(String? ruta) {
  if (ruta == null || ruta.isEmpty) return null;

  return Container(
    height: 180,
    decoration: BoxDecoration(
      color: Colores.fondo,
      border: Border.all(color: Colores.linea),
      borderRadius: BorderRadius.circular(Dimen.radioCampo),
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.network(
      ArchivoApi.url(ruta),
      fit: BoxFit.cover,
      // Si no carga se dice, en vez de dejar un hueco gris que parece que la
      // foto se perdio.
      errorBuilder: (_, _, _) => const Center(
        child: Text(
          'No se pudo cargar la foto',
          style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
        ),
      ),
    ),
  );
}

class _TarjetaVehiculo extends StatelessWidget {
  const _TarjetaVehiculo({
    required this.vehiculo,
    required this.color,
    required this.onVer,
    required this.onEditar,
    required this.onEstado,
  });

  final Vehiculo vehiculo;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback onEditar;
  final VoidCallback onEstado;

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
        widget: insigniaActivo(vehiculo.activo),
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
          tooltip: vehiculo.activo ? 'Desactivar' : 'Activar',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            vehiculo.activo ? Icons.block : Icons.check_circle_outline,
            size: 18,
            color: vehiculo.activo ? Colores.advertencia : Colores.exito,
          ),
        ),
      ],
    );
  }
}
