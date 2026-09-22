import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_detalle_hoja.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_linea_producto.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/dms_modelos.dart';
import '../estado/dms_controlador.dart';

/// Devoluciones de cliente.
///
/// Aquí no se registra ninguna: nacen de editarle la cantidad a una nota de
/// venta, que es donde de verdad ocurre —el cliente trae de vuelta parte de lo
/// que se llevó—. Esta pantalla es para verlas todas juntas y resolverlas.
///
/// Ninguna mueve nada hasta que se aprueba: quien recibe la mercadería en la
/// calle no es quien decide aceptarla. Al aprobarse entra el stock y la venta
/// baja de importe, con lo que la deuda del cliente baja sola.
class DevolucionesPagina extends ConsumerWidget {
  const DevolucionesPagina({super.key});

  static const ruta = '/dms/devoluciones';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final resumen = ref.watch(resumenDevolucionesProvider).valueOrNull;
    final resuelve = puede(ref, 'dms.devoluciones', Accion.confirmar);

    return AppListaPagina<Devolucion>(
      titulo: 'Devoluciones',
      ruta: ruta,
      estado: ref.watch(devolucionesProvider),
      visibles: ref.watch(devolucionesFiltradasProvider),
      busqueda: ref.watch(busquedaDevolucionesProvider),
      onBuscar: (t) =>
          ref.read(busquedaDevolucionesProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número, venta o cliente',
      onRecargar: () async {
        ref.invalidate(devolucionesProvider);
        await ref.read(devolucionesProvider.future);
      },
      iconoVacio: Icons.undo_outlined,
      singular: 'devolución',
      plural: 'devoluciones',
      detalleVacio: ref.watch(filtrosDevolucionesActivosProvider) == 0
          ? 'Ninguna espera respuesta. Se registran al editarle la cantidad a '
                'una nota de venta.'
          : 'Ninguna coincide con los filtros puestos.',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Por aprobar',
          valor: '${resumen?.solicitadas ?? 0}',
          icono: Icons.pending_actions_outlined,
          tono: (resumen?.solicitadas ?? 0) > 0
              ? DatoTono.aviso
              : DatoTono.neutral,
          nota: 'esperando decisión',
        ),
        AppTarjetaDato(
          etiqueta: 'Aprobadas',
          valor: '${resumen?.aprobadas ?? 0}',
          icono: Icons.check_circle_outline,
          tono: DatoTono.exito,
        ),
        AppTarjetaDato(
          etiqueta: 'Descontado a clientes',
          valor: formatoSoles(resumen?.importe ?? 0),
          icono: Icons.undo_outlined,
          color: color,
          nota: 'solo lo aprobado',
        ),
      ],
      filtro: BotonFiltros(
        activos: ref.watch(filtrosDevolucionesActivosProvider),
        color: color,
        onAbrir: () => _abrirFiltros(context, ref),
      ),
      fila: (context, devolucion) => _TarjetaDevolucion(
        devolucion: devolucion,
        color: color,
        onAprobar: resuelve && devolucion.pendiente
            ? () => _aprobar(context, ref, devolucion)
            : null,
        onRechazar: resuelve && devolucion.pendiente
            ? () => _rechazar(context, ref, devolucion)
            : null,
      ),
    );
  }

  Future<void> _abrirFiltros(BuildContext context, WidgetRef ref) {
    return mostrarFiltros(
      context,
      activos: ref.read(filtrosDevolucionesActivosProvider),
      onLimpiar: () {
        ref.read(filtroDevolucionEstadoProvider.notifier).state =
            FiltroEstadoDevolucion.solicitadas;
        ref.read(clienteDevolucionFiltroProvider.notifier).state = null;
        ref.read(motivoDevolucionFiltroProvider.notifier).state = null;
      },
      grupos: [
        Consumer(
          builder: (context, ref, _) => GrupoFiltro<FiltroEstadoDevolucion>(
            titulo: 'Estado',
            valor: ref.watch(filtroDevolucionEstadoProvider),
            opciones: const [
              OpcionFiltro(FiltroEstadoDevolucion.solicitadas, 'Por aprobar'),
              OpcionFiltro(FiltroEstadoDevolucion.aprobadas, 'Aprobadas'),
              OpcionFiltro(FiltroEstadoDevolucion.rechazadas, 'Rechazadas'),
              OpcionFiltro(FiltroEstadoDevolucion.todas, 'Todas'),
            ],
            onCambio: (v) =>
                ref.read(filtroDevolucionEstadoProvider.notifier).state = v,
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final clientes = ref.watch(clientesDevolucionProvider);
            if (clientes.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Cliente',
              valor: ref.watch(clienteDevolucionFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final c in clientes) OpcionFiltro(c, c),
              ],
              onCambio: (v) =>
                  ref.read(clienteDevolucionFiltroProvider.notifier).state = v,
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final motivos = ref.watch(motivosDevolucionProvider);
            if (motivos.isEmpty) return const SizedBox.shrink();

            return GrupoFiltro<String?>(
              titulo: 'Motivo',
              valor: ref.watch(motivoDevolucionFiltroProvider),
              opciones: [
                const OpcionFiltro(null, 'Todos'),
                for (final m in motivos) OpcionFiltro(m, m),
              ],
              onCambio: (v) =>
                  ref.read(motivoDevolucionFiltroProvider.notifier).state = v,
            );
          },
        ),
      ],
    );
  }

  Future<void> _aprobar(
    BuildContext context,
    WidgetRef ref,
    Devolucion devolucion,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Aprobar ${devolucion.numero}',
      mensaje:
          'Entra la mercadería que vuelve al stock y la venta baja de importe, '
          'así que el cliente deja de deberla. No se puede deshacer.',
      textoConfirmar: 'Aprobar',
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(dmsApiProvider).aprobar(devolucion.id);
      ref.invalidate(devolucionesProvider);
      mensajero.mostrar('${devolucion.numero} aprobada');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  Future<void> _rechazar(
    BuildContext context,
    WidgetRef ref,
    Devolucion devolucion,
  ) {
    final acento = Acento.de(context);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colores.superficie,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimen.radioPanel),
        ),
      ),
      builder: (_) => Acento(
        color: acento,
        child: _HojaRechazo(devolucion: devolucion),
      ),
    );
  }
}

/// Rechazar pide el porqué: un rechazo sin explicación es lo primero que el
/// vendedor va a preguntar, y quien lo decidió puede no estar para responder.
class _HojaRechazo extends ConsumerStatefulWidget {
  const _HojaRechazo({required this.devolucion});

  final Devolucion devolucion;

  @override
  ConsumerState<_HojaRechazo> createState() => _HojaRechazoState();
}

class _HojaRechazoState extends ConsumerState<_HojaRechazo> {
  final _motivo = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_motivo.text.trim().isEmpty) {
      setState(() => _error = 'Di por qué se rechaza.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref
          .read(dmsApiProvider)
          .rechazar(widget.devolucion.id, _motivo.text.trim());
      ref.invalidate(devolucionesProvider);
      navegador.pop();
      mensajero.mostrar('Devolución rechazada');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Dimen.espacio4,
        right: Dimen.espacio4,
        bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rechazar ${widget.devolucion.numero}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'No entra mercadería ni se le descuenta nada al cliente.',
            style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio4),
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          AppCampo(
            controlador: _motivo,
            etiqueta: 'Motivo del rechazo',
            pista: 'El cliente no trajo la mercadería',
            maxLargo: 250,
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio4),
          AppBoton(
            texto: 'Rechazar',
            color: Colores.peligro,
            cargando: _guardando,
            onPressed: _confirmar,
          ),
          const SizedBox(height: Dimen.espacio2),
        ],
      ),
    );
  }
}

class _TarjetaDevolucion extends StatelessWidget {
  const _TarjetaDevolucion({
    required this.devolucion,
    required this.color,
    this.onAprobar,
    this.onRechazar,
  });

  final Devolucion devolucion;
  final Color color;

  /// Null si ya se resolvió o si quien mira no puede resolverla.
  final VoidCallback? onAprobar;
  final VoidCallback? onRechazar;

  Widget get _estado => switch (devolucion.estado) {
    EstadoDevolucion.aprobada => const AppEtiqueta(
      'Aprobada',
      tono: EtiquetaTono.exito,
    ),
    EstadoDevolucion.rechazada => const AppEtiqueta(
      'Rechazada',
      tono: EtiquetaTono.peligro,
    ),
    _ => const AppEtiqueta('Por aprobar', tono: EtiquetaTono.aviso),
  };

  String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  List<CampoDetalle> get _campos => [
    CampoDetalle('Venta', devolucion.notaVenta),
    CampoDetalle('Cliente', devolucion.cliente),
    CampoDetalle('Fecha', _fecha(devolucion.fecha)),
    CampoDetalle('Importe', formatoSoles(devolucion.total)),
    CampoDetalle('Vuelve a', devolucion.almacen, enTarjeta: false),
    CampoDetalle('Motivo', devolucion.motivo, enTarjeta: false),
    CampoDetalle('Registró', devolucion.usuario, enTarjeta: false),

    // Quién la resolvió y por qué: sin esto, un rechazo no se explica.
    if (!devolucion.pendiente) ...[
      CampoDetalle(
        devolucion.estado == EstadoDevolucion.aprobada
            ? 'Aprobada por'
            : 'Rechazada por',
        devolucion.aprobadoPor,
        enTarjeta: false,
      ),
      CampoDetalle('Por qué', devolucion.motivoRechazo, enTarjeta: false),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return AppTarjetaRegistro(
      icono: Icons.undo_outlined,
      color: color,
      titulo: devolucion.numero,
      insignia: _estado,
      campos: _campos,
      onTap: () => _detalle(context),
      acciones: [
        if (onRechazar != null)
          IconButton(
            onPressed: onRechazar,
            tooltip: 'Rechazar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colores.peligro,
            ),
          ),
        if (onAprobar != null)
          IconButton(
            onPressed: onAprobar,
            tooltip: 'Aprobar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.check_rounded,
              size: 18,
              color: Colores.exito,
            ),
          ),
      ],
    );
  }

  Future<void> _detalle(BuildContext context) {
    return mostrarDetalle(
      context,
      icono: Icons.undo_outlined,
      color: color,
      titulo: devolucion.numero,
      subtitulo: '${devolucion.cliente} · vuelve a ${devolucion.almacen}',
      estado: _estado,
      campos: _campos,
      contenidoExtra: [
        for (final l in devolucion.detalle)
          LineaProductoTarjeta(
            titulo: l.producto,
            subtitulo: '${l.codigo} · ${l.presentacion ?? l.unidadBase}',
            filas: [
              [
                ('Cant.', formatoNumero(l.cantidadPresentacion)),
                ('Precio', formatoSoles(l.precioUnitario)),
                ('Importe', formatoSoles(l.importe)),
              ],
              [
                // Si vuelve a venderse o se pierde: un producto abierto no
                // entra al stock vendible aunque se acepte la devolución.
                ('Destino', l.reingresaStock ? 'Vuelve al stock' : 'Merma'),
              ],
            ],
          ),
      ],
      acciones: [
        if (onRechazar != null)
          AppBoton(
            texto: 'Rechazar',
            variante: BotonVariante.secundario,
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onRechazar!();
            },
          ),
        if (onAprobar != null)
          AppBoton(
            texto: 'Aprobar',
            expandido: true,
            onPressed: () {
              Navigator.of(context).pop();
              onAprobar!();
            },
          ),
      ],
    );
  }
}
