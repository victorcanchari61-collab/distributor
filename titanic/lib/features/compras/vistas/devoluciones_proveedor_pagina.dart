import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton_fila.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/permisos/sin_permiso.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/devolucion_proveedor.dart';
import '../estado/compras_controlador.dart';
import 'devolucion_proveedor_formulario.dart';

/// Lo que se le devolvio a los proveedores: lo que llego mal o no llego, y que
/// dieron a cambio. Arriba, cuanto deben los proveedores de saldo a favor.
///
/// Registrar que un proveedor devolvio la plata se hace en el panel web
/// (Compras > Devoluciones a proveedor > Saldos a favor); usarlo en otra
/// compra, al pagarla en Cuentas por pagar.
class DevolucionesProveedorPagina extends ConsumerWidget {
  const DevolucionesProveedorPagina({super.key});

  static const ruta = '/compras/devoluciones';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas =
        ref.watch(devolucionesProveedorProvider).valueOrNull ??
        const <DevolucionProveedor>[];
    final vigentes = todas.where((d) => !d.anulada).toList();
    final descontado = vigentes.fold<double>(0, (s, d) => s + d.montoDescuento);
    final aReponer = vigentes.fold<double>(0, (s, d) => s + d.montoReposicion);
    final saldos =
        ref.watch(saldosFavorProvider).valueOrNull ??
        const <SaldoFavorProveedor>[];
    final saldoTotal = saldos.fold<double>(0, (s, x) => s + x.saldo);
    final estadoFiltro = ref.watch(estadoDevolucionProveedorFiltroProvider);

    return AppListaPagina<DevolucionProveedor>(
      titulo: 'Devoluciones a proveedor',
      ruta: ruta,
      estado: ref.watch(devolucionesProveedorProvider),
      visibles: ref.watch(devolucionesProveedorFiltradasProvider),
      busqueda: ref.watch(busquedaDevolucionesProveedorProvider),
      onBuscar: (t) =>
          ref.read(busquedaDevolucionesProveedorProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número, compra o proveedor',
      onRecargar: () async {
        ref.invalidate(saldosFavorProvider);
        await ref.read(devolucionesProveedorProvider.notifier).recargar();
      },
      onNuevo: permitir(
        puede(ref, 'compras.devoluciones', Accion.crear),
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DevolucionProveedorFormulario(),
          ),
        ),
      ),
      textoNuevo: 'Nueva devolución',
      iconoVacio: Icons.assignment_return_outlined,
      singular: 'devolución',
      plural: 'devoluciones',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Devoluciones',
          valor: '${vigentes.length}',
          icono: Icons.assignment_return_outlined,
          color: color,
          progreso: todas.isNotEmpty ? vigentes.length / todas.length : 0,
          accion: AccionDato(
            etiqueta: 'Ver todas',
            onTap: () =>
                ref
                        .read(estadoDevolucionProveedorFiltroProvider.notifier)
                        .state =
                    null,
          ),
        ),
        AppTarjetaDato(
          etiqueta: 'Descontado',
          valor: 'S/ ${descontado.toStringAsFixed(2)}',
          icono: Icons.percent,
          tono: DatoTono.aviso,
        ),
        AppTarjetaDato(
          etiqueta: 'A reponer',
          valor: 'S/ ${aReponer.toStringAsFixed(2)}',
          icono: Icons.autorenew,
          tono: DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Saldo a favor',
          valor: 'S/ ${saldoTotal.toStringAsFixed(2)}',
          icono: Icons.account_balance_wallet_outlined,
          tono: DatoTono.exito,
          accion: saldos.isEmpty
              ? null
              : AccionDato(
                  etiqueta: 'Ver quién debe',
                  onTap: () => _verSaldos(context, saldos),
                ),
        ),
      ],
      filtro: BotonFiltros(
        activos: estadoFiltro == null ? 0 : 1,
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, d) => _TarjetaDevolucion(
        devolucion: d,
        color: color,
        onAnular: d.anulada
            ? null
            : permitir(
                puede(ref, 'compras.devoluciones', Accion.anular),
                () => _anular(context, ref, d),
              ),
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(estadoDevolucionProveedorFiltroProvider) == null ? 0 : 1,
      onLimpiar: () =>
          ref.read(estadoDevolucionProveedorFiltroProvider.notifier).state =
              null,
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoDevolucionProveedorFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todas'),
              OpcionFiltro('CONFIRMADA', 'Vigentes'),
              OpcionFiltro('ANULADA', 'Anuladas'),
            ],
            onCambio: (v) =>
                ref
                        .read(estadoDevolucionProveedorFiltroProvider.notifier)
                        .state =
                    v,
          ),
        ),
      ],
    );
  }

  Future<void> _verSaldos(
    BuildContext context,
    List<SaldoFavorProveedor> saldos,
  ) {
    return mostrarHoja<void>(
      context,
      titulo: 'Saldos a favor',
      subtitulo: 'Lo que los proveedores deben devolver',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in saldos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimen.espacio2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.proveedor,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colores.tinta,
                          ),
                        ),
                        Text(
                          'Generado en total: S/ ${s.totalGenerado.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colores.tintaSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'S/ ${s.saldo.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colores.exito,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Dimen.espacio2),
          const Text(
            'Cuando el proveedor devuelva la plata, regístralo en el panel web. '
            'Para usarlo en otra compra suya, págala desde Cuentas por pagar.',
            style: TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
        ],
      ),
    );
  }

  Future<void> _anular(
    BuildContext context,
    WidgetRef ref,
    DevolucionProveedor d,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular ${d.numero}',
      mensaje:
          'Lo devuelto vuelve al stock, la compra queda como estaba y el saldo '
          'a favor que dio se retira.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(devolucionesProveedorProvider.notifier).anular(d.id);
      mensajero.mostrar('${d.numero} anulada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaDevolucion extends StatelessWidget {
  const _TarjetaDevolucion({
    required this.devolucion,
    required this.color,
    this.onAnular,
  });

  final DevolucionProveedor devolucion;
  final Color color;
  final VoidCallback? onAnular;

  String get _aCambio {
    final descuento = devolucion.detalle.any(
      (l) => l.resolucion == ResolucionDevolucion.descuento,
    );
    final reposicion = devolucion.detalle.any(
      (l) => l.resolucion == ResolucionDevolucion.reposicion,
    );
    return [
      if (descuento) 'Descuento',
      if (reposicion) 'Reposición',
    ].join(' y ');
  }

  List<CampoDetalle> get _campos => [
    CampoDetalle('Proveedor', devolucion.proveedor),
    CampoDetalle('Compra', devolucion.compraNumero),
    CampoDetalle('Fecha', _fecha(devolucion.fecha)),
    CampoDetalle('Motivo', devolucion.motivo),
    CampoDetalle('A cambio', _aCambio),
    if (devolucion.montoDescuento > 0)
      CampoDetalle(
        'Descuento',
        'S/ ${devolucion.montoDescuento.toStringAsFixed(2)}',
      ),
    if (devolucion.montoReposicion > 0)
      CampoDetalle(
        'A reponer',
        'S/ ${devolucion.montoReposicion.toStringAsFixed(2)}',
      ),
    if (devolucion.saldoFavorGenerado > 0)
      CampoDetalle(
        'Saldo a favor',
        'S/ ${devolucion.saldoFavorGenerado.toStringAsFixed(2)}',
      ),
    if (devolucion.almacen != null)
      CampoDetalle('Salió de', devolucion.almacen, enTarjeta: false),
    if (devolucion.fechaReposicion != null)
      CampoDetalle(
        'Lo repone el',
        _fecha(devolucion.fechaReposicion!),
        enTarjeta: false,
      ),
    if (devolucion.numeroNotaCredito != null)
      CampoDetalle(
        'Nota de crédito',
        '${devolucion.serieNotaCredito ?? ''}-${devolucion.numeroNotaCredito}',
        enTarjeta: false,
      ),
    if (devolucion.usuario != null)
      CampoDetalle('Registró', devolucion.usuario, enTarjeta: false),
    if (devolucion.observacion != null)
      CampoDetalle('Observación', devolucion.observacion, enTarjeta: false),
  ];

  AppEtiqueta get _estado => AppEtiqueta(
    devolucion.anulada ? 'Anulada' : 'Vigente',
    tono: devolucion.anulada ? EtiquetaTono.peligro : EtiquetaTono.exito,
  );

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.assignment_return_outlined,
      color: color,
      titulo: devolucion.numero,
      estado: _estado,
      campos: _campos,
      onTap: () => _abrirDetalle(context),
      acciones: [
        AppBotonFila(
          icono: Icons.visibility,
          etiqueta: 'Ver ${devolucion.numero}',
          tono: TonoAccion.ver,
          onPressed: () => _abrirDetalle(context),
        ),
        AppBotonFila(
          icono: Icons.undo,
          etiqueta: 'Anular ${devolucion.numero}',
          tono: TonoAccion.peligro,
          onPressed: onAnular,
          motivo: 'Ya está anulada',
        ),
      ],
    );
  }

  Future<void> _abrirDetalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.assignment_return_outlined,
      color: color,
      titulo: devolucion.numero,
      subtitulo: devolucion.proveedor,
      estado: _estado,
      campos: _campos,
      contenidoExtra: [
        for (final l in devolucion.detalle)
          LineaProductoTarjeta(
            titulo: l.producto,
            subtitulo:
                '${l.codigo} · ${l.origen == OrigenDevolucion.recibido ? 'lo que llegó' : 'lo que no llegó'}',
            filas: [
              [
                ('Cant.', '${formatoNumero(l.cantidad)} ${l.unidadBase}'),
                ('A cambio', ResolucionDevolucion.etiqueta(l.resolucion)),
                ('Importe', 'S/ ${l.importe.toStringAsFixed(2)}'),
              ],
            ],
          ),
      ],
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
