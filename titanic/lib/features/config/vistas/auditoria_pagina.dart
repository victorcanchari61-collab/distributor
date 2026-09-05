import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../datos/auditoria.dart';
import '../estado/auditoria_controlador.dart';

/// Auditoria: que cambio en el sistema, quien lo hizo y cuando. Solo lectura.
class AuditoriaPagina extends ConsumerWidget {
  const AuditoriaPagina({super.key});

  static const ruta = '/config/auditoria';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todos = ref.watch(auditoriaProvider).valueOrNull ?? const <RegistroAuditoria>[];
    final creados = todos.where((r) => r.accion == AccionAuditoria.creado).length;
    final actualizados = todos.where((r) => r.accion == AccionAuditoria.actualizado).length;
    final eliminados = todos.where((r) => r.accion == AccionAuditoria.eliminado).length;
    final accionFiltro = ref.watch(accionAuditoriaFiltroProvider);

    return AppListaPagina<RegistroAuditoria>(
      titulo: 'Auditoría',
      ruta: ruta,
      estado: ref.watch(auditoriaProvider),
      visibles: ref.watch(auditoriaFiltradaProvider),
      busqueda: ref.watch(busquedaAuditoriaProvider),
      onBuscar: (t) => ref.read(busquedaAuditoriaProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por usuario, entidad o registro',
      onRecargar: () => ref.read(auditoriaProvider.notifier).recargar(),
      iconoVacio: Icons.history_outlined,
      singular: 'cambio',
      plural: 'cambios',
      tituloVacio: 'Sin cambios',
      detalleVacio: 'No hay cambios registrados con esos filtros.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Creados',
          valor: '$creados',
          icono: Icons.add_circle_outline,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Actualizados',
          valor: '$actualizados',
          icono: Icons.edit_outlined,
          tono: DatoTono.aviso,
        ),
        AppTarjetaDato(
          etiqueta: 'Eliminados',
          valor: '$eliminados',
          icono: Icons.delete_outline,
          tono: DatoTono.neutral,
        ),
      ],
      filtro: BotonFiltros(
        activos: accionFiltro == null ? 0 : 1,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, registro) => _TarjetaAuditoria(registro: registro, color: color),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(accionAuditoriaFiltroProvider) == null ? 0 : 1,
      onLimpiar: () => ref.read(accionAuditoriaFiltroProvider.notifier).state = null,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Acción',
            valor: ref.watch(accionAuditoriaFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todas'),
              OpcionFiltro(AccionAuditoria.creado, 'Creados'),
              OpcionFiltro(AccionAuditoria.actualizado, 'Actualizados'),
              OpcionFiltro(AccionAuditoria.eliminado, 'Eliminados'),
            ],
            onCambio: (v) => ref.read(accionAuditoriaFiltroProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }
}

EtiquetaTono _tonoAccion(String accion) => switch (accion) {
  AccionAuditoria.creado => EtiquetaTono.exito,
  AccionAuditoria.eliminado => EtiquetaTono.peligro,
  _ => EtiquetaTono.aviso,
};

String _etiquetaAccion(String accion) => switch (accion) {
  AccionAuditoria.creado => 'Creado',
  AccionAuditoria.eliminado => 'Eliminado',
  _ => 'Actualizado',
};

/// Un valor de la bitacora, legible: fechas cortas, vacios como "—".
String _formatearValor(dynamic valor) {
  if (valor == null || valor == '') return '—';
  if (valor is bool) return valor ? 'Sí' : 'No';
  if (valor is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(valor)) {
    final f = DateTime.tryParse(valor)?.toLocal();
    if (f != null) return _fechaHora(f);
  }
  return valor.toString();
}

String _fechaHora(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

class _TarjetaAuditoria extends StatelessWidget {
  const _TarjetaAuditoria({required this.registro, required this.color});

  final RegistroAuditoria registro;
  final Color color;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Fecha', _fechaHora(registro.fecha.toLocal())),
    CampoDetalle('Usuario', registro.usuario),
    CampoDetalle('Registro', '#${registro.entidadId}'),
    CampoDetalle('Campos', '${registro.campos.length}', enTarjeta: false),
  ];

  /// Una tarjeta por campo: antes y despues, segun la accion.
  List<Widget> get _cambios => [
    for (final campo in registro.campos)
      LineaProductoTarjeta(
        titulo: campo,
        subtitulo: _etiquetaAccion(registro.accion),
        filas: [
          [
            if (registro.accion != AccionAuditoria.creado)
              ('Antes', _formatearValor(registro.valoresAnteriores?[campo])),
            if (registro.accion != AccionAuditoria.eliminado)
              ('Después', _formatearValor(registro.valoresNuevos?[campo])),
          ],
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final insignia = AppEtiqueta(_etiquetaAccion(registro.accion), tono: _tonoAccion(registro.accion));

    return AppTarjetaRegistro(
      icono: Icons.history_outlined,
      color: color,
      titulo: registro.entidad,
      insignia: insignia,
      campos: _campos,
      onTap: () => mostrarDetalle(
        context,
        icono: Icons.history_outlined,
        color: color,
        titulo: '${registro.entidad} #${registro.entidadId}',
        subtitulo: '${_fechaHora(registro.fecha.toLocal())} · ${registro.usuario}',
        insignia: insignia,
        campos: _campos,
        contenidoExtra: _cambios,
      ),
    );
  }
}
