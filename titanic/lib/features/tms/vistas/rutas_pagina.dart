import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/estado/filtro_estado.dart';
import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_sin_permiso.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/permisos/sin_permiso.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../datos/ruta.dart';
import '../estado/tms_controlador.dart';
import 'chips_nombres.dart';
import 'ruta_formulario.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Listado de rutas de reparto. Lo elige cada cliente en Maestros → Clientes.
class RutasPagina extends ConsumerWidget {
  const RutasPagina({super.key});

  static const ruta = '/tms/rutas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas = ref.watch(rutasProvider).valueOrNull ?? const <Ruta>[];
    final activas = todas.where((r) => r.activo).length;
    final sinVendedor = todas
        .where((r) => r.activo && r.vendedores.isEmpty)
        .length;
    final ventasMes = todas.fold<double>(0, (n, r) => n + r.ventasMes);
    final compraron = todas.fold<int>(0, (n, r) => n + r.clientesConCompraMes);
    final porCobrar = todas.fold<double>(0, (n, r) => n + r.porCobrar);
    final deben = todas.fold<int>(0, (n, r) => n + r.clientesConDeuda);
    // Las tarjetas llevan a lo que cuentan: "Ver las 8" pone ese estado en el filtro.
    void verEstado(FiltroEstado e) =>
        ref.read(estadoFiltroProvider.notifier).state = e;

    return AppListaPagina<Ruta>(
      titulo: 'Rutas',
      ruta: ruta,
      estado: ref.watch(rutasProvider),
      visibles: ref.watch(rutasFiltradasProvider),
      busqueda: ref.watch(busquedaRutasProvider),
      onBuscar: (t) => ref.read(busquedaRutasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por nombre',
      onRecargar: () => ref.read(rutasProvider.notifier).recargar(),
      onNuevo: permitir(
        puede(ref, 'tms.rutas', Accion.crear),
        () => _abrirFormulario(context, null),
      ),
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
          progreso: todas.isNotEmpty ? 1 : 0,
          accion: AccionDato(
            etiqueta: 'Ver todas',
            onTap: () => verEstado(FiltroEstado.todos),
          ),
        ),
        AppTarjetaDato(
          etiqueta: 'Activas',
          valor: '$activas',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
          progreso: todas.isNotEmpty ? activas / todas.length : 0,
          accion: AccionDato(
            etiqueta: activas > 0 ? 'Ver las $activas' : 'Ver',
            onTap: () => verEstado(FiltroEstado.activos),
          ),
        ),
        // Sin enlace: la app no filtra por quién tiene la ruta a cargo.
        AppTarjetaDato(
          etiqueta: 'Sin vendedor',
          valor: '$sinVendedor',
          nota: 'activas sin nadie a cargo',
          icono: Icons.person_off_outlined,
          tono: sinVendedor > 0 ? DatoTono.aviso : DatoTono.exito,
          progreso: activas > 0 ? sinVendedor / activas : 0,
        ),
        AppTarjetaDato(
          etiqueta: 'Ventas del mes',
          valor: formatoSoles(ventasMes),
          nota: compraron == 1
              ? '1 cliente compró'
              : '$compraron clientes compraron',
          icono: Icons.trending_up,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Por cobrar',
          valor: formatoSoles(porCobrar),
          nota: deben == 1 ? '1 cliente debe' : '$deben clientes deben',
          icono: Icons.request_quote_outlined,
          tono: porCobrar > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
      ],
      filtro: BotonFiltros(
        activos: ref.watch(filtrosRutasActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, ruta) => _TarjetaRuta(
        ruta: ruta,
        color: color,
        onVer: () => _verDetalle(context, ruta, color),
        onEditar: permitir(
          puede(ref, 'tms.rutas', Accion.editar),
          () => _abrirFormulario(context, ruta),
        ),
        onEstado: permitir(
          puede(ref, 'tms.rutas', Accion.editar),
          () => _cambiarEstado(context, ref, ruta),
        ),
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosRutasActivosProvider),
      onLimpiar: () {
        ref.read(estadoFiltroProvider.notifier).state = FiltroEstado.activos;
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
      ],
    );
  }

  Future<void> _abrirFormulario(BuildContext context, Ruta? ruta) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RutaFormulario(ruta: ruta)));
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    Ruta ruta,
  ) async {
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

    final mensajero = Aviso.de(context);
    try {
      await ref.read(rutasProvider.notifier).cambiarEstado(ruta);
      mensajero.mostrar(
        ruta.activo ? '${ruta.nombre} desactivada' : '${ruta.nombre} activada',
      );
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
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
      estado: _insigniaEstado(ruta.activo),
      campos: [
        CampoDetalle('Nombre', ruta.nombre),
        CampoDetalle('Clientes', '${ruta.clientes}'),
        CampoDetalle(
          'A cargo de',
          ruta.vendedores.isEmpty ? 'Sin vendedor' : ruta.vendedores.join(', '),
        ),
        CampoDetalle('Mercados', ordenarNombres(ruta.mercados).join(', ')),
        ..._camposReparto(ruta),
        CampoDetalle(
          'Compraron',
          ruta.clientesConCompraMes > 0 ? '${ruta.clientesConCompraMes}' : null,
        ),
        CampoDetalle(
          'Deben',
          ruta.clientesConDeuda > 0 ? '${ruta.clientesConDeuda}' : null,
        ),
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

/// Qué días sale, en qué camión, lo vendido y lo que deben: lo que comparten
/// la tarjeta y la ficha. Sin dato va la raya, como en el web.
List<CampoDetalle> _camposReparto(Ruta ruta) => [
  CampoDetalle(
    'Días',
    ruta.dias.map((d) => SalidaRuta.corto[d] ?? d).join(', '),
  ),
  CampoDetalle('Camión', ruta.placas.join(', ')),
  CampoDetalle(
    'Ventas del mes',
    ruta.ventasMes > 0 ? formatoSoles(ruta.ventasMes) : null,
  ),
  CampoDetalle(
    'Por cobrar',
    ruta.porCobrar > 0 ? formatoSoles(ruta.porCobrar) : null,
    widget: ruta.porCobrar > 0 ? _textoDeuda(ruta.porCobrar) : null,
  ),
];

/// Lo que deben, en ámbar como en el web.
Widget _textoDeuda(double monto) => Text(
  formatoSoles(monto),
  style: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colores.advertencia,
  ),
);

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({
    required this.ruta,
    required this.color,
    required this.onVer,
    this.onEditar,
    this.onEstado,
  });

  final Ruta ruta;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback? onEditar;
  final VoidCallback? onEstado;

  List<CampoDetalle> get _campos => [
    CampoDetalle('Clientes', '${ruta.clientes}'),
    CampoDetalle(
      'Mercados',
      null,
      widget: ruta.mercados.isEmpty ? null : ChipsNombres(ruta.mercados),
    ),
    ..._camposReparto(ruta),
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
        if (onEditar != null)
          AppIconoAccion(
            icono: Icons.edit_outlined,
            tooltip: 'Editar',
            color: Acento.de(context),
            onPressed: onEditar,
          ),
        if (onEstado != null)
          AppIconoAccion(
            icono: ruta.activo ? Icons.block : Icons.check_circle_outline,
            tooltip: ruta.activo ? 'Desactivar' : 'Activar',
            color: ruta.activo ? Colores.advertencia : Colores.exito,
            onPressed: onEstado,
          ),
      ],
    );
  }
}
