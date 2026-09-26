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
import '../datos/tesoreria.dart';
import '../estado/tesoreria_controlador.dart';
import 'hoja_movimientos_cuenta.dart';
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
