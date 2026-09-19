import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/novedad.dart';
import '../estado/novedades_controlador.dart';

/// Novedades de entrega: lo que no llegó al cliente y por qué.
///
/// Sale de dos lugares: un producto que se entregó en menos al convertir el
/// pedido en venta, o un pedido entero que no se pudo entregar. Cuando la
/// mercadería viajaba en el camión, el encargado la cuenta al volver y deja
/// constancia: llegó completa, o faltó algo.
class NovedadesPagina extends ConsumerWidget {
  const NovedadesPagina({super.key});

  static const ruta = '/tms/novedades';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final resumen = ref.watch(resumenNovedadesProvider).valueOrNull ?? const ResumenNovedades();
    final puedeRevisar = puede(ref, 'tms.novedades', Accion.confirmar);
    final puedeExportar = puede(ref, 'tms.novedades', Accion.exportar);

    return AppListaPagina<Novedad>(
      titulo: 'Novedades',
      ruta: ruta,
      estado: ref.watch(novedadesProvider),
      visibles: ref.watch(novedadesFiltradasProvider),
      busqueda: ref.watch(busquedaNovedadesProvider),
      onBuscar: (t) => ref.read(busquedaNovedadesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por producto, pedido, cliente, motivo',
      onRecargar: () => ref.read(novedadesProvider.notifier).recargar(),
      iconoVacio: Icons.inventory_2_outlined,
      singular: 'novedad',
      plural: 'novedades',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Por revisar',
          valor: '${resumen.porRevisar}',
          icono: Icons.fact_check_outlined,
          tono: resumen.porRevisar > 0 ? DatoTono.aviso : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'Recibidas',
          valor: '${resumen.recibidas}',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Faltantes',
          valor: '${resumen.faltantes}',
          icono: Icons.warning_amber_rounded,
          tono: resumen.faltantes > 0 ? DatoTono.peligro : DatoTono.neutral,
        ),
        AppTarjetaDato(
          etiqueta: 'No entregado',
          valor: 'S/ ${resumen.importe.toStringAsFixed(2)}',
          icono: Icons.payments_outlined,
          color: color,
        ),
      ],
      // El reporte va pegado al embudo porque respeta lo que ese embudo puso.
      filtro: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonFiltros(
            activos: ref.watch(filtrosNovedadesActivosProvider),
            color: color,
            onAbrir: () => _abrirFiltros(context, ref),
          ),
          if (puedeExportar) const _BotonReporte(),
        ],
      ),
      fila: (context, novedad) => _TarjetaNovedad(
        novedad: novedad,
        color: color,
        onVer: () => _verDetalle(context, ref, novedad, color, puedeRevisar),
        onRevisar: puedeRevisar && novedad.porRevisar ? () => _revisar(context, ref, novedad) : null,
        onReabrir: puedeRevisar && novedad.revisada ? () => _reabrir(context, ref, novedad) : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosNovedadesActivosProvider),
      onLimpiar: () {
        ref.read(estadoNovedadFiltroProvider.notifier).state = null;
        ref.read(motivoNovedadFiltroProvider.notifier).state = null;
        ref.read(tipoNovedadFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Estado',
            valor: ref.watch(estadoNovedadFiltroProvider),
            opciones: [
              const OpcionFiltro(null, 'Todos'),
              for (final e in const [
                EstadoNovedad.pendiente,
                EstadoNovedad.recibida,
                EstadoNovedad.faltante,
                EstadoNovedad.sinRetorno,
                EstadoNovedad.anulada,
              ])
                OpcionFiltro(e, EstadoNovedad.texto(e)),
            ],
            onCambio: (v) => ref.read(estadoNovedadFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<String?>(
            titulo: 'Qué pasó',
            valor: ref.watch(tipoNovedadFiltroProvider),
            opciones: const [
              OpcionFiltro(null, 'Todos'),
              OpcionFiltro(TipoNovedad.linea, 'Entregado en menos'),
              OpcionFiltro(TipoNovedad.pedido, 'Pedido sin entregar'),
            ],
            onCambio: (v) => ref.read(tipoNovedadFiltroProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final motivos = ref.watch(motivosDeNovedadesProvider);
            if (motivos.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Motivo',
              valor: ref.watch(motivoNovedadFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final m in motivos) OpcionFiltro(m, m),
              ],
              onCambio: (v) => ref.read(motivoNovedadFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }

  Future<void> _reabrir(BuildContext context, WidgetRef ref, Novedad novedad) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Reabrir la revisión de ${novedad.producto}',
      mensaje: 'Se borra lo que se contó y vuelve a quedar por revisar.',
      textoConfirmar: 'Reabrir',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(novedadesProvider.notifier).reabrir(novedad.id);
      mensajero.mostrar('La novedad volvió a quedar por revisar');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  /// El encargado cuenta lo que volvió en el camión: llegó todo, o faltó algo.
  /// Lo que no llegó queda como faltante, a cargo de quien lo llevó.
  Future<void> _revisar(BuildContext context, WidgetRef ref, Novedad novedad) async {
    String resultado = EstadoNovedad.recibida;
    final regresada = TextEditingController(text: '0');
    final observacion = TextEditingController();
    String? error;

    final guardar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colores.superficie,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: Dimen.espacio4,
                right: Dimen.espacio4,
                top: Dimen.espacio2,
                bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Revisar ${novedad.producto}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
                    ),
                    const SizedBox(height: Dimen.espacio2),
                    Text(
                      'No se entregó ${novedad.cantidad(novedad.cantidadNoEntregada)} (${novedad.motivo}). '
                      '¿Qué encontraste al contar lo que volvió?',
                      style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
                    ),
                    const SizedBox(height: Dimen.espacio4),
                    if (error != null) ...[
                      Text(error!, style: const TextStyle(fontSize: 12, color: Colores.peligro)),
                      const SizedBox(height: Dimen.espacio2),
                    ],
                    AppSelector<String>(
                      valor: resultado,
                      etiqueta: 'Resultado',
                      icono: Icons.fact_check_outlined,
                      opciones: const [
                        Opcion(EstadoNovedad.recibida, 'Volvió completa'),
                        Opcion(EstadoNovedad.faltante, 'Faltó algo'),
                      ],
                      onCambio: (v) => setSheetState(() {
                        resultado = v ?? EstadoNovedad.recibida;
                        error = null;
                      }),
                    ),
                    if (resultado == EstadoNovedad.faltante) ...[
                      const SizedBox(height: Dimen.espacio4),
                      AppCampo(
                        controlador: regresada,
                        etiqueta: 'Cuánto volvió (${novedad.unidadBase})',
                        icono: Icons.inventory_2_outlined,
                        tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                    const SizedBox(height: Dimen.espacio4),
                    AppCampo(
                      controlador: observacion,
                      etiqueta: 'Observación',
                      icono: Icons.notes_outlined,
                      opcional: true,
                      maxLargo: 250,
                    ),
                    const SizedBox(height: Dimen.espacio3),
                    AppBoton(
                      texto: 'Guardar revisión',
                      onPressed: () {
                        if (resultado == EstadoNovedad.faltante) {
                          final volvio = double.tryParse(regresada.text.replaceAll(',', '.')) ?? -1;
                          if (volvio < 0 || volvio >= novedad.cantidadNoEntregada) {
                            setSheetState(
                              () => error =
                                  'Lo que volvió tiene que ser menos de '
                                  '${novedad.cantidadNoEntregada} ${novedad.unidadBase}.',
                            );
                            return;
                          }
                        }
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final cuerpo = <String, dynamic>{
      'estado': resultado,
      'cantidadRegresada': resultado == EstadoNovedad.faltante
          ? double.tryParse(regresada.text.replaceAll(',', '.')) ?? 0
          : null,
      'observacion': observacion.text.trim().isEmpty ? null : observacion.text.trim(),
    };
    regresada.dispose();
    observacion.dispose();

    if (guardar != true || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(novedadesProvider.notifier).verificar(novedad.id, cuerpo);
      mensajero.mostrar('Revisión guardada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _verDetalle(
    BuildContext context,
    WidgetRef ref,
    Novedad n,
    Color color,
    bool puedeRevisar,
  ) {
    return mostrarDetalle(
      context,
      icono: Icons.inventory_2_outlined,
      color: color,
      titulo: n.producto,
      subtitulo: '${n.pedido} · ${n.cliente}',
      estado: _etiquetaEstado(n),
      campos: [
        CampoDetalle('Qué pasó', n.tipo == TipoNovedad.pedido ? 'Pedido sin entregar' : 'Entregado en menos'),
        CampoDetalle('Pedido', n.cantidad(n.cantidadPedida)),
        CampoDetalle('Se entregó', n.cantidad(n.cantidadEntregada)),
        CampoDetalle('No se entregó', n.cantidad(n.cantidadNoEntregada)),
        CampoDetalle('Importe', 'S/ ${n.importe.toStringAsFixed(2)}'),
        CampoDetalle('Motivo', n.motivo),
        CampoDetalle(
          'La mercadería',
          n.regresaAlAlmacen ? 'Viajó y vuelve al almacén' : 'Nunca salió del almacén',
        ),
        if (n.observacion != null) CampoDetalle('Observación', n.observacion),
        CampoDetalle('Despacho', n.despacho),
        CampoDetalle('Venta', n.notaVenta),
        CampoDetalle('Registrado', '${_fecha(n.fecha)}${n.usuario != null ? ' · ${n.usuario}' : ''}'),
        if (n.verificadoEn != null) ...[
          CampoDetalle('Volvió', n.cantidad(n.cantidadRegresada ?? 0)),
          CampoDetalle(
            'Faltó',
            n.cantidad((n.cantidadNoEntregada - (n.cantidadRegresada ?? 0)).clamp(0, double.infinity)),
          ),
          CampoDetalle(
            'Revisó',
            '${_fecha(n.verificadoEn!)}${n.verificadoPor != null ? ' · ${n.verificadoPor}' : ''}',
          ),
          if (n.observacionVerificacion != null)
            CampoDetalle('Obs. de la revisión', n.observacionVerificacion),
        ],
      ],
      acciones: [
        if (puedeRevisar && n.porRevisar)
          AppBoton(
            texto: 'Revisar',
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              _revisar(context, ref, n);
            },
          ),
      ],
    );
  }
}

/// El reporte en PDF de las novedades, con lo mismo que muestra la lista: la
/// búsqueda y los filtros que estén puestos al tocarlo.
///
/// Se baja del servidor y no se arma con las filas del teléfono: la lista solo
/// trae las últimas 200 y el papel lleva todo lo que pasa el filtro. Se abre con
/// el visor del sistema, igual que el resto de PDF de la app.
class _BotonReporte extends ConsumerStatefulWidget {
  const _BotonReporte();

  @override
  ConsumerState<_BotonReporte> createState() => _BotonReporteState();
}

class _BotonReporteState extends ConsumerState<_BotonReporte> {
  bool _generando = false;

  Future<void> _abrir() async {
    // El aviso se toma antes del await: al volver, el context puede haberse ido.
    final mensajero = Aviso.de(context);
    setState(() => _generando = true);

    try {
      final bytes = await ref
          .read(novedadApiProvider)
          .pdf(ref.read(consultaNovedadesProvider));

      // Con la fecha en el nombre, como lo nombra el servidor: son papeles que
      // se sacan a diario y en la carpeta del teléfono conviene distinguirlos.
      final hoy = DateTime.now().toIso8601String().substring(0, 10);
      final carpeta = await getTemporaryDirectory();
      final archivo = File('${carpeta.path}/novedades-$hoy.pdf');
      await archivo.writeAsBytes(bytes);
      await OpenFilex.open(archivo.path);
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    } catch (_) {
      mensajero.error('No pudimos generar el reporte.');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // Mientras baja, apagado: con 2000 filas tarda y un segundo toque
      // pediría el mismo papel dos veces.
      onPressed: _generando ? null : _abrir,
      tooltip: 'Reporte PDF',
      icon: _generando
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.picture_as_pdf_outlined, size: 22, color: Colores.tintaSuave),
    );
  }
}

AppEtiqueta _etiquetaEstado(Novedad n) => AppEtiqueta(
  EstadoNovedad.texto(n.estado),
  tono: switch (n.estado) {
    EstadoNovedad.pendiente => EtiquetaTono.aviso,
    EstadoNovedad.recibida => EtiquetaTono.exito,
    EstadoNovedad.faltante => EtiquetaTono.peligro,
    _ => EtiquetaTono.neutral,
  },
);

class _TarjetaNovedad extends StatelessWidget {
  const _TarjetaNovedad({
    required this.novedad,
    required this.color,
    required this.onVer,
    this.onRevisar,
    this.onReabrir,
  });

  final Novedad novedad;
  final Color color;
  final VoidCallback onVer;
  final VoidCallback? onRevisar;
  final VoidCallback? onReabrir;

  @override
  Widget build(BuildContext context) {
    final n = novedad;

    return AppTarjetaRegistro(
      icono: Icons.inventory_2_outlined,
      color: color,
      titulo: n.producto,
      estado: _etiquetaEstado(n),
      campos: [
        CampoDetalle('No entregado', n.cantidad(n.cantidadNoEntregada)),
        CampoDetalle('Importe', 'S/ ${n.importe.toStringAsFixed(2)}'),
        CampoDetalle('Motivo', n.observacion == null ? n.motivo : '${n.motivo} — ${n.observacion}'),
        CampoDetalle('Pedido', '${n.pedido} · ${n.cliente}'),
        if (n.despacho != null) CampoDetalle('Despacho', n.despacho),
        CampoDetalle('Fecha', _fecha(n.fecha)),
      ],
      onTap: onVer,
      acciones: [
        IconButton(
          onPressed: onVer,
          tooltip: 'Ver detalle',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.visibility_outlined, size: 18, color: Colores.tintaSuave),
        ),
        if (onRevisar != null)
          IconButton(
            onPressed: onRevisar,
            tooltip: 'Revisar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.fact_check_outlined, size: 18, color: Colores.exito),
          ),
        if (onReabrir != null)
          IconButton(
            onPressed: onReabrir,
            tooltip: 'Reabrir la revisión',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.replay, size: 18, color: Colores.advertencia),
          ),
      ],
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
