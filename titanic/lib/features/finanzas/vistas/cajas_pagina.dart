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
import '../../config/estado/config_controlador.dart';
import '../datos/mi_caja.dart';
import '../datos/tesoreria.dart';
import '../estado/tesoreria_controlador.dart';
import 'hoja_movimientos_cuenta.dart';
import 'hoja_mover_plata.dart';
import 'hojas_finanzas.dart';

/// La caja de cada persona que cobra en la calle: con cuanto anda y que se
/// movio. Sin caja no se puede cobrar en efectivo; aqui se asigna una a quien
/// no la tiene y se desactiva la de quien ya no cobra. Igual que el panel web.
class CajasPagina extends ConsumerWidget {
  const CajasPagina({super.key});

  static const ruta = '/finanzas/cajas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final pestanas = _Pestanas(
      boveda: ref.watch(verBovedaProvider),
      onCambio: (v) => ref.read(verBovedaProvider.notifier).state = v,
    );
    if (ref.watch(verBovedaProvider)) {
      return _paginaBoveda(context, ref, color, pestanas);
    }

    final activas =
        (ref.watch(cajasProvider).valueOrNull ?? const <CuentaFinanciera>[])
            .where((c) => c.activo);
    final total = activas.fold<double>(0, (s, c) => s + c.saldoActual);

    return AppListaPagina<CuentaFinanciera>(
      titulo: 'Cajas',
      ruta: ruta,
      estado: ref.watch(cajasProvider),
      visibles: ref.watch(cajasFiltradasProvider),
      busqueda: ref.watch(busquedaCajasProvider),
      onBuscar: (t) => ref.read(busquedaCajasProvider.notifier).state = t,
      pistaBusqueda: 'Buscar usuario o caja',
      onRecargar: () async {
        ref.invalidate(cuentasFinancierasProvider);
        try {
          await ref.read(cuentasFinancierasProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      onNuevo: puede(ref, 'finanzas.cajas', Accion.crear)
          ? () => abrirHojaFinanzas(context, (_) => const _HojaNuevaCaja())
          : null,
      textoNuevo: 'Asignar caja',
      iconoVacio: Icons.point_of_sale_outlined,
      singular: 'caja',
      plural: 'cajas',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'En las cajas',
          valor: formatoSoles(total),
          icono: Icons.account_balance_wallet_outlined,
          color: color,
          nota: '${activas.length} activas',
        ),
      ],
      encabezado: pestanas,
      filtro: BotonFiltros(
        activos: ref.watch(verInactivasCajasProvider) ? 1 : 0,
        color: color,
        onAbrir: () => mostrarFiltros(
          context,
          activos: ref.read(verInactivasCajasProvider) ? 1 : 0,
          onLimpiar: () =>
              ref.read(verInactivasCajasProvider.notifier).state = false,
          grupos: [
            Consumer(
              builder: (context, ref, _) => GrupoFiltro<bool>(
                titulo: 'Estado',
                valor: ref.watch(verInactivasCajasProvider),
                opciones: const [
                  OpcionFiltro(false, 'Activas'),
                  OpcionFiltro(true, 'Todas'),
                ],
                onCambio: (v) =>
                    ref.read(verInactivasCajasProvider.notifier).state = v,
              ),
            ),
          ],
        ),
      ),
      fila: (context, c) => _TarjetaCaja(
        caja: c,
        color: color,
        onEstado: puede(ref, 'finanzas.cajas', Accion.editar)
            ? () => _cambiarEstado(context, ref, c)
            : null,
      ),
    );
  }

  /// La pestaña de la Boveda: su saldo, lo que entro y salio, y sus
  /// movimientos de los ultimos 30 dias.
  Widget _paginaBoveda(
    BuildContext context,
    WidgetRef ref,
    Color color,
    Widget pestanas,
  ) {
    final cuentas = ref.watch(cuentasFinancierasProvider);
    final boveda = ref.watch(bovedaProvider);
    final AsyncValue<List<MovimientoCaja>> estado = boveda == null
        ? cuentas.whenData((_) => const <MovimientoCaja>[])
        : ref.watch(movimientosCuentaProvider(boveda.id));
    final movimientos = estado.valueOrNull ?? const <MovimientoCaja>[];
    final texto = ref.watch(busquedaBovedaProvider).trim().toLowerCase();
    final entro = movimientos
        .where((m) => m.esIngreso)
        .fold<double>(0, (s, m) => s + m.monto);
    final salio = movimientos
        .where((m) => !m.esIngreso)
        .fold<double>(0, (s, m) => s + m.monto);
    final puedeMover =
        puede(ref, 'finanzas.movimientos', Accion.crear) ||
        puede(ref, 'finanzas.cajas', Accion.editar);

    return AppListaPagina<MovimientoCaja>(
      titulo: 'Cajas',
      ruta: ruta,
      estado: estado,
      visibles: movimientos
          .where((m) => texto.isEmpty || m.buscable.contains(texto))
          .toList(),
      busqueda: ref.watch(busquedaBovedaProvider),
      onBuscar: (t) => ref.read(busquedaBovedaProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por detalle',
      onRecargar: () async {
        ref.invalidate(cuentasFinancierasProvider);
        if (boveda != null) {
          ref.invalidate(movimientosCuentaProvider(boveda.id));
        }
      },
      // El boton principal: crearla si falta, o mover plata si ya existe.
      onNuevo: boveda == null
          ? (puede(ref, 'finanzas.cajas', Accion.crear)
                ? () => abrirHojaFinanzas(context, (_) => const _HojaBoveda())
                : null)
          : (puedeMover ? () => _mover(context, ref) : null),
      textoNuevo: boveda == null ? 'Crear bóveda' : 'Mover plata',
      iconoVacio: Icons.account_balance,
      singular: 'movimiento',
      plural: 'movimientos',
      tituloVacio: boveda == null ? 'Sin Bóveda' : 'Sin movimientos',
      detalleVacio: boveda == null
          ? 'Créala para que los cierres de caja tengan adónde entregar el efectivo.'
          : 'No hay movimientos en la Bóveda en los últimos 30 días.',
      indicadores: boveda == null
          ? null
          : [
              AppTarjetaDato(
                etiqueta: 'En la Bóveda',
                valor: formatoSoles(boveda.saldoActual),
                icono: Icons.account_balance,
                color: color,
                nota: 'Solo efectivo',
              ),
              AppTarjetaDato(
                etiqueta: 'Entró',
                valor: formatoSoles(entro),
                icono: Icons.trending_up,
                tono: DatoTono.exito,
                nota: 'Últimos 30 días',
              ),
              AppTarjetaDato(
                etiqueta: 'Salió',
                valor: formatoSoles(salio),
                icono: Icons.trending_down,
                tono: DatoTono.peligro,
                nota: 'Últimos 30 días',
              ),
            ],
      encabezado: pestanas,
      fila: (context, m) => AppTarjetaRegistro(
        icono: m.esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
        color: color,
        titulo: m.concepto,
        insignia: AppEtiqueta(
          m.esIngreso ? 'Entra' : 'Sale',
          tono: m.esIngreso ? EtiquetaTono.exito : EtiquetaTono.peligro,
        ),
        campos: [
          CampoDetalle(
            'Monto',
            null,
            widget: Text(
              '${m.esIngreso ? '+' : '-'}${formatoSoles(m.monto)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: m.esIngreso ? Colores.exito : Colores.peligro,
              ),
            ),
          ),
          CampoDetalle('Saldo', formatoSoles(m.saldoResultante)),
          CampoDetalle('Fecha', fechaHora(m.fecha)),
          CampoDetalle('Detalle', m.observacion),
        ],
      ),
    );
  }

  /// Mover plata desde la Boveda (u otra cuenta) a donde haga falta.
  void _mover(BuildContext context, WidgetRef ref) {
    final cuentas =
        (ref.read(cuentasFinancierasProvider).valueOrNull ??
                const <CuentaFinanciera>[])
            .where((c) => c.activo)
            .map(
              (c) => CuentaParaMover(
                id: c.id,
                etiqueta: c.esBoveda
                    ? c.nombre
                    : c.naturaleza == 'CAJA'
                    ? '${c.nombre} · Caja'
                    : '${c.nombre} · Banco',
                saldo: c.saldoActual,
              ),
            )
            .toList();
    abrirHojaFinanzas(
      context,
      (_) => HojaMoverPlata(
        cuentas: cuentas,
        origenInicial: ref.read(bovedaProvider)?.id,
      ),
    );
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    CuentaFinanciera c,
  ) async {
    final ok = await confirmarAccion(
      context,
      titulo: '${c.activo ? 'Desactivar' : 'Activar'} ${c.nombre}',
      mensaje: c.activo
          ? 'Deja de poder cobrar en efectivo hasta que se le vuelva a activar.'
          : 'Vuelve a poder cobrar en efectivo.',
      textoConfirmar: c.activo ? 'Desactivar' : 'Activar',
      tono: c.activo ? ConfirmTono.aviso : ConfirmTono.pregunta,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref
          .read(tesoreriaApiProvider)
          .actualizarCuenta(c.id, c.aJson(activo: !c.activo));
      ref.invalidate(cuentasFinancierasProvider);
      mensajero.mostrar('${c.nombre} ${c.activo ? 'desactivada' : 'activada'}');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }
}

/// Las dos pestañas de Cajas: las cajas de cada persona y la Boveda.
class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.boveda, required this.onCambio});

  final bool boveda;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Cajas'),
            icon: Icon(Icons.groups_outlined, size: 18),
          ),
          ButtonSegment(
            value: true,
            label: Text('Bóveda'),
            icon: Icon(Icons.account_balance, size: 18),
          ),
        ],
        selected: {boveda},
        onSelectionChanged: (s) => onCambio(s.first),
      ),
    );
  }
}

/// Crear la Boveda: con cuanto efectivo arranca.
class _HojaBoveda extends ConsumerStatefulWidget {
  const _HojaBoveda();

  @override
  ConsumerState<_HojaBoveda> createState() => _HojaBovedaState();
}

class _HojaBovedaState extends ConsumerState<_HojaBoveda> {
  final _inicial = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _inicial.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref
          .read(tesoreriaApiProvider)
          .crearBoveda(double.tryParse(_inicial.text.trim()) ?? 0);
      ref.invalidate(cuentasFinancierasProvider);
      navegador.pop();
      mensajero.mostrar('Bóveda creada');
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
      padding: margenHoja(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloHoja(
            'Crear la Bóveda',
            apoyo:
                'La caja de la empresa: no es de nadie y solo guarda efectivo. Una sola.',
          ),
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          AppCampo(
            controlador: _inicial,
            etiqueta: 'Efectivo que ya hay',
            icono: Icons.payments_outlined,
            pista: '0.00',
            opcional: true,
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
            formateadores: [soloMonto],
            habilitado: !_guardando,
          ),
          const SizedBox(height: Dimen.espacio5),
          AppBoton(
            texto: 'Crear bóveda',
            cargando: _guardando,
            onPressed: _crear,
          ),
        ],
      ),
    );
  }
}

class _TarjetaCaja extends StatelessWidget {
  const _TarjetaCaja({required this.caja, required this.color, this.onEstado});

  final CuentaFinanciera caja;
  final Color color;
  final VoidCallback? onEstado;

  @override
  Widget build(BuildContext context) {
    final c = caja;
    return AppTarjetaRegistro(
      icono: Icons.point_of_sale_outlined,
      color: color,
      titulo: c.usuarioResponsable ?? c.nombre,
      insignia: c.activo
          ? null
          : const AppEtiqueta('Inactiva', tono: EtiquetaTono.aviso),
      campos: [
        CampoDetalle('Caja', c.nombre),
        CampoDetalle(
          'Saldo',
          null,
          widget: Text(
            formatoSoles(c.saldoActual),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.saldoActual < 0 ? Colores.peligro : null,
            ),
          ),
        ),
      ],
      onTap: () =>
          abrirHojaFinanzas(context, (_) => HojaMovimientosCuenta(cuenta: c)),
      acciones: [
        IconButton(
          onPressed: () => abrirHojaFinanzas(
            context,
            (_) => HojaMovimientosCuenta(cuenta: c),
          ),
          tooltip: 'Movimientos',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.receipt_long_outlined,
            size: 18,
            color: Acento.de(context),
          ),
        ),
        if (onEstado != null)
          IconButton(
            onPressed: onEstado,
            tooltip: c.activo ? 'Desactivar' : 'Activar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              c.activo ? Icons.block : Icons.check_circle_outline,
              size: 18,
              color: c.activo ? Colores.advertencia : Colores.exito,
            ),
          ),
      ],
    );
  }
}

/// Asignar una caja a un usuario que todavia no tiene una activa.
class _HojaNuevaCaja extends ConsumerStatefulWidget {
  const _HojaNuevaCaja();

  @override
  ConsumerState<_HojaNuevaCaja> createState() => _HojaNuevaCajaState();
}

class _HojaNuevaCajaState extends ConsumerState<_HojaNuevaCaja> {
  int? _usuarioId;
  final _nombre = TextEditingController();
  final _inicial = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _inicial.dispose();
    super.dispose();
  }

  Future<void> _guardar(String nombreUsuario) async {
    FocusScope.of(context).unfocus();
    if (_usuarioId == null) {
      setState(() => _error = 'Elige a quién se le asigna la caja.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);

    try {
      await ref.read(tesoreriaApiProvider).crearCuenta({
        'nombre': _nombre.text.trim().isEmpty
            ? 'Caja de $nombreUsuario'
            : _nombre.text.trim(),
        'naturaleza': 'CAJA',
        'usuarioResponsableId': _usuarioId,
        // Con cuanta plata arranca: la que ya tenia en la mano.
        'montoInicial': double.tryParse(_inicial.text.trim()) ?? 0,
        'activo': true,
      });
      ref.invalidate(cuentasFinancierasProvider);
      navegador.pop();
      mensajero.mostrar('Caja asignada');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = ref.watch(usuariosProvider);
    final cajas =
        ref.watch(cajasProvider).valueOrNull ?? const <CuentaFinanciera>[];

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloHoja(
              'Asignar caja',
              apoyo: 'Sin caja no puede cobrar en efectivo. Una por persona.',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            usuarios.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar los usuarios.',
              ),
              data: (lista) {
                // Solo quien no tiene ya una caja activa.
                final disponibles = lista
                    .where(
                      (u) =>
                          u.activo &&
                          !cajas.any(
                            (c) => c.activo && c.usuarioResponsableId == u.id,
                          ),
                    )
                    .toList();
                final elegido = disponibles
                    .where((u) => u.id == _usuarioId)
                    .firstOrNull;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSelector<int>(
                      valor: _usuarioId,
                      etiqueta: 'Usuario',
                      icono: Icons.person_outline,
                      habilitado: !_guardando,
                      opciones: [
                        for (final u in disponibles) Opcion(u.id, u.nombre),
                      ],
                      onCambio: (v) => setState(() => _usuarioId = v),
                    ),
                    const SizedBox(height: Dimen.espacio4),
                    AppCampo(
                      controlador: _nombre,
                      etiqueta: 'Nombre de la caja',
                      icono: Icons.label_outline,
                      pista: elegido == null
                          ? 'Caja de ...'
                          : 'Caja de ${elegido.nombre}',
                      opcional: true,
                      habilitado: !_guardando,
                    ),
                    const SizedBox(height: Dimen.espacio4),
                    AppCampo(
                      controlador: _inicial,
                      etiqueta: 'Monto inicial',
                      icono: Icons.payments_outlined,
                      pista: '0.00',
                      opcional: true,
                      tipoTeclado: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      formateadores: [soloMonto],
                      habilitado: !_guardando,
                    ),
                    const SizedBox(height: Dimen.espacio5),
                    AppBoton(
                      texto: 'Asignar',
                      cargando: _guardando,
                      onPressed: () => _guardar(elegido?.nombre ?? ''),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
