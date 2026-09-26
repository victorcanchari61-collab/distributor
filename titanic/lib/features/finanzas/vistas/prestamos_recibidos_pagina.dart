import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_filtros.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/permisos/permisos.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/acento.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/tesoreria.dart';
import '../estado/tesoreria_controlador.dart';
import 'hojas_finanzas.dart';

EtiquetaTono _tonoEstado(String estado) => switch (estado) {
  EstadoPrestamo.vigente => EtiquetaTono.aviso,
  EstadoPrestamo.cancelado => EtiquetaTono.exito,
  _ => EtiquetaTono.neutral,
};

/// Los prestamos recibidos, como deuda: la plata que entro y lo que falta
/// devolver. Se pagan con un monto total, sin separar capital e interes; el
/// costo del prestamo se ve en lo que se devuelve de mas. Igual que el panel
/// web.
class PrestamosRecibidosPagina extends ConsumerWidget {
  const PrestamosRecibidosPagina({super.key});

  static const ruta = '/finanzas/financiamiento';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final vigentes =
        (ref.watch(prestamosRecibidosProvider).valueOrNull ??
                const <Prestamo>[])
            .where((p) => p.vigente);
    final saldo = vigentes.fold<double>(0, (s, p) => s + p.saldo);
    final puedeCrear = puede(ref, 'finanzas.financiamiento', Accion.crear);
    final puedeAnular = puede(ref, 'finanzas.financiamiento', Accion.anular);

    return AppListaPagina<Prestamo>(
      titulo: 'Préstamos recibidos',
      ruta: ruta,
      estado: ref.watch(prestamosRecibidosProvider),
      visibles: ref.watch(prestamosFiltradosProvider),
      busqueda: ref.watch(busquedaPrestamosProvider),
      onBuscar: (t) => ref.read(busquedaPrestamosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar acreedor',
      onRecargar: () async {
        ref.invalidate(prestamosRecibidosProvider);
        try {
          await ref.read(prestamosRecibidosProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      onNuevo: puedeCrear
          ? () => abrirHojaFinanzas(context, (_) => const _HojaNuevo())
          : null,
      textoNuevo: 'Nuevo préstamo',
      iconoVacio: Icons.savings_outlined,
      singular: 'préstamo',
      plural: 'préstamos',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Por pagar',
          valor: formatoSoles(saldo),
          icono: Icons.account_balance_wallet_outlined,
          tono: saldo > 0 ? DatoTono.aviso : DatoTono.neutral,
          nota: '${vigentes.length} vigentes',
        ),
      ],
      filtro: BotonFiltros(
        activos: ref.watch(filtrosPrestamosActivosProvider),
        color: color,
        onAbrir: () => mostrarFiltros(
          context,
          activos: ref.read(filtrosPrestamosActivosProvider),
          onLimpiar: () =>
              ref.read(estadoPrestamosFiltroProvider.notifier).state =
                  EstadoPrestamo.vigente,
          grupos: [
            Consumer(
              builder: (context, ref, _) => GrupoFiltro<String?>(
                titulo: 'Estado',
                valor: ref.watch(estadoPrestamosFiltroProvider),
                opciones: [
                  for (final e in EstadoPrestamo.todos)
                    OpcionFiltro<String?>(e, EstadoPrestamo.etiqueta(e)),
                  const OpcionFiltro<String?>(null, 'Todos'),
                ],
                onCambio: (v) =>
                    ref.read(estadoPrestamosFiltroProvider.notifier).state = v,
              ),
            ),
          ],
        ),
      ),
      fila: (context, p) => _TarjetaPrestamo(
        prestamo: p,
        color: color,
        onPagar: p.vigente && puedeCrear
            ? () => abrirHojaFinanzas(context, (_) => _HojaPago(prestamo: p))
            : null,
        onPagos: p.pagos.isEmpty
            ? null
            : () => abrirHojaFinanzas(
                context,
                (_) => _HojaPagos(prestamoId: p.id, puedeAnular: puedeAnular),
              ),
        // Solo sin pagos vigentes: primero se anulan los pagos.
        onAnular:
            puedeAnular &&
                p.estado != EstadoPrestamo.anulado &&
                !p.pagos.any((x) => !x.anulado)
            ? () => _anular(context, ref, p)
            : null,
      ),
    );
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, Prestamo p) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular préstamo',
      mensaje:
          'El préstamo de ${p.acreedor} por ${formatoSoles(p.montoRecibido)}. '
          'Se revierte el ingreso en ${p.cuentaFinanciera}.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).anularPrestamo(p.id);
      ref.invalidate(prestamosRecibidosProvider);
      mensajero.mostrar('Préstamo anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

class _TarjetaPrestamo extends StatelessWidget {
  const _TarjetaPrestamo({
    required this.prestamo,
    required this.color,
    this.onPagar,
    this.onPagos,
    this.onAnular,
  });

  final Prestamo prestamo;
  final Color color;
  final VoidCallback? onPagar;
  final VoidCallback? onPagos;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    final p = prestamo;
    return AppTarjetaRegistro(
      icono: Icons.savings_outlined,
      color: color,
      titulo: p.acreedor,
      insignia: AppEtiqueta(
        EstadoPrestamo.etiqueta(p.estado),
        tono: _tonoEstado(p.estado),
      ),
      campos: [
        CampoDetalle('Recibido', formatoSoles(p.montoRecibido)),
        CampoDetalle(
          'A devolver',
          p.costo > 0
              ? '${formatoSoles(p.totalADevolver)} (+${formatoSoles(p.costo)})'
              : formatoSoles(p.totalADevolver),
        ),
        CampoDetalle('Pagado', formatoSoles(p.pagado)),
        CampoDetalle(
          'Saldo',
          null,
          widget: Text(
            formatoSoles(p.saldo),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.saldo > 0 ? Colores.advertencia : Colores.exito,
            ),
          ),
        ),
        CampoDetalle('Entró a', p.cuentaFinanciera),
        CampoDetalle('Fecha', fechaCorta(p.fecha)),
        CampoDetalle('Descripción', p.descripcion),
      ],
      acciones: [
        if (onPagar != null)
          IconButton(
            onPressed: onPagar,
            tooltip: 'Registrar pago',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.payments_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
        if (onPagos != null)
          IconButton(
            onPressed: onPagos,
            tooltip: 'Ver pagos',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: Acento.de(context),
            ),
          ),
        if (onAnular != null)
          IconButton(
            onPressed: onAnular,
            tooltip: 'Anular',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.block, size: 18, color: Colores.advertencia),
          ),
      ],
    );
  }
}

/// Un prestamo nuevo: quien presto, cuanto entro, cuanto se devuelve y a que
/// cuenta llego la plata.
class _HojaNuevo extends ConsumerStatefulWidget {
  const _HojaNuevo();

  @override
  ConsumerState<_HojaNuevo> createState() => _HojaNuevoState();
}

class _HojaNuevoState extends ConsumerState<_HojaNuevo> {
  final _acreedor = TextEditingController();
  final _descripcion = TextEditingController();
  final _recibido = TextEditingController();
  final _devolver = TextEditingController();
  int? _cuentaId;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_acreedor, _descripcion, _recibido, _devolver]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final recibido = double.tryParse(_recibido.text.trim());
    final devolver = double.tryParse(_devolver.text.trim());
    final error = _acreedor.text.trim().isEmpty
        ? 'Indica quién prestó (banco o persona).'
        : recibido == null || recibido <= 0
        ? 'Ingresa cuánto se recibió.'
        : devolver != null && devolver < recibido
        ? 'Lo que se devuelve no puede ser menos de lo recibido.'
        : _cuentaId == null
        ? 'Elige a qué cuenta entró la plata.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref.read(tesoreriaApiProvider).crearPrestamo({
        'acreedor': _acreedor.text.trim(),
        'descripcion': _descripcion.text.trim().isEmpty
            ? null
            : _descripcion.text.trim(),
        'montoRecibido': recibido,
        // Vacio es lo mismo que lo recibido: un prestamo sin intereses.
        'totalADevolver': devolver,
        'cuentaFinancieraId': _cuentaId,
      });
      ref.invalidate(prestamosRecibidosProvider);
      navegador.pop();
      mensajero.mostrar('Préstamo registrado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasPrestamoProvider);

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloHoja(
              'Nuevo préstamo',
              apoyo:
                  'La plata entra a la cuenta y queda como deuda hasta pagarla.',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppCampo(
              controlador: _acreedor,
              etiqueta: 'Acreedor',
              icono: Icons.person_outline,
              pista: 'Banco o persona',
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            Row(
              children: [
                Expanded(
                  child: AppCampo(
                    controlador: _recibido,
                    etiqueta: 'Recibido',
                    icono: Icons.south_west,
                    pista: '0.00',
                    tipoTeclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    formateadores: [soloMonto],
                    habilitado: !_guardando,
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Expanded(
                  child: AppCampo(
                    controlador: _devolver,
                    etiqueta: 'A devolver',
                    icono: Icons.north_east,
                    pista: 'Igual si no hay interés',
                    opcional: true,
                    tipoTeclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    formateadores: [soloMonto],
                    habilitado: !_guardando,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimen.espacio4),
            cuentas.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar las cuentas.',
              ),
              data: (lista) => AppSelector<int>(
                valor: _cuentaId,
                etiqueta: 'Entró a',
                icono: Icons.account_balance_outlined,
                habilitado: !_guardando,
                opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
                onCambio: (v) => setState(() => _cuentaId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _descripcion,
              etiqueta: 'Descripción',
              icono: Icons.notes_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBoton(
              texto: 'Registrar',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un pago del prestamo: un monto total, de la cuenta que se elija.
class _HojaPago extends ConsumerStatefulWidget {
  const _HojaPago({required this.prestamo});

  final Prestamo prestamo;

  @override
  ConsumerState<_HojaPago> createState() => _HojaPagoState();
}

class _HojaPagoState extends ConsumerState<_HojaPago> {
  late final _monto = TextEditingController(
    text: widget.prestamo.saldo.toStringAsFixed(2),
  );
  final _observacion = TextEditingController();
  int? _cuentaId;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final monto = double.tryParse(_monto.text.trim());
    final saldo = widget.prestamo.saldo;
    final error = monto == null || monto <= 0
        ? 'Ingresa un monto mayor a cero.'
        : monto > saldo + 0.001
        ? 'El pago no puede pasar del saldo (${formatoSoles(saldo)}).'
        : _cuentaId == null
        ? 'Elige de qué cuenta sale el pago.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref.read(tesoreriaApiProvider).pagarPrestamo(widget.prestamo.id, {
        'monto': monto,
        'cuentaFinancieraId': _cuentaId,
        'observacion': _observacion.text.trim().isEmpty
            ? null
            : _observacion.text.trim(),
      });
      ref.invalidate(prestamosRecibidosProvider);
      navegador.pop();
      mensajero.mostrar('Pago registrado');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = ref.watch(cuentasPrestamoProvider);
    final p = widget.prestamo;

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloHoja(
              'Pagar a ${p.acreedor}',
              apoyo:
                  'Saldo ${formatoSoles(p.saldo)} de ${formatoSoles(p.totalADevolver)}',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppCampo(
              controlador: _monto,
              etiqueta: 'Monto',
              icono: Icons.payments_outlined,
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              formateadores: [soloMonto],
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            cuentas.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar las cuentas.',
              ),
              data: (lista) => AppSelector<int>(
                valor: _cuentaId,
                etiqueta: 'Sale de',
                icono: Icons.account_balance_outlined,
                habilitado: !_guardando,
                opciones: [for (final c in lista) Opcion(c.id, c.etiqueta)],
                onCambio: (v) => setState(() => _cuentaId = v),
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _observacion,
              etiqueta: 'Observación',
              icono: Icons.notes_outlined,
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBoton(
              texto: 'Registrar pago',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Los pagos de un prestamo, con la opcion de anular uno mal registrado.
///
/// Lee el prestamo del listado y no el que se abrio: al anular un pago la
/// lista se recarga y la hoja se actualiza sola.
class _HojaPagos extends ConsumerWidget {
  const _HojaPagos({required this.prestamoId, required this.puedeAnular});

  final int prestamoId;
  final bool puedeAnular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p =
        (ref.watch(prestamosRecibidosProvider).valueOrNull ??
                const <Prestamo>[])
            .where((x) => x.id == prestamoId)
            .firstOrNull;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: margenHoja(context),
        child: p == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TituloHoja(
                    'Pagos a ${p.acreedor}',
                    apoyo:
                        'Pagado ${formatoSoles(p.pagado)} · saldo ${formatoSoles(p.saldo)}',
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: p.pagos.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final pago = p.pagos[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            formatoSoles(pago.monto),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: pago.anulado
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            '${fechaHora(pago.fecha)} · ${pago.cuentaFinanciera}'
                            '${pago.observacion != null ? ' · ${pago.observacion}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: pago.anulado
                              ? const AppEtiqueta(
                                  'Anulado',
                                  tono: EtiquetaTono.neutral,
                                )
                              : puedeAnular
                              ? TextButton(
                                  onPressed: () =>
                                      _anularPago(context, ref, p, pago),
                                  child: const Text('Anular'),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _anularPago(
    BuildContext context,
    WidgetRef ref,
    Prestamo p,
    PagoPrestamo pago,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular pago',
      mensaje:
          'El pago de ${formatoSoles(pago.monto)} del ${fechaCorta(pago.fecha)}. '
          'La plata vuelve a ${pago.cuentaFinanciera} y el préstamo reabre su saldo.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.aviso,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(tesoreriaApiProvider).anularPagoPrestamo(p.id, pago.id);
      ref.invalidate(prestamosRecibidosProvider);
      mensajero.mostrar('Pago anulado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}
