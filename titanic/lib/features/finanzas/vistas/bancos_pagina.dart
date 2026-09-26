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
import 'hoja_movimientos_cuenta.dart';
import 'hojas_finanzas.dart';

/// Las cuentas bancarias: cuanta plata hay en cada una y que se movio. Los
/// metodos de pago (Yape, transferencia) apuntan a una de estas. La
/// conciliacion contra el extracto se hace en el panel web.
class BancosPagina extends ConsumerWidget {
  const BancosPagina({super.key});

  static const ruta = '/finanzas/bancos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final activas =
        (ref.watch(cuentasBancariasProvider).valueOrNull ??
                const <CuentaFinanciera>[])
            .where((c) => c.activo);
    final total = activas.fold<double>(0, (s, c) => s + c.saldoActual);
    final puedeEditar = puede(ref, 'finanzas.bancos', Accion.editar);

    return AppListaPagina<CuentaFinanciera>(
      titulo: 'Bancos',
      ruta: ruta,
      estado: ref.watch(cuentasBancariasProvider),
      visibles: ref.watch(cuentasBancariasFiltradasProvider),
      busqueda: ref.watch(busquedaBancosProvider),
      onBuscar: (t) => ref.read(busquedaBancosProvider.notifier).state = t,
      pistaBusqueda: 'Buscar cuenta, banco o número',
      onRecargar: () async {
        ref.invalidate(cuentasFinancierasProvider);
        try {
          await ref.read(cuentasFinancierasProvider.future);
        } catch (_) {
          // El fallo ya se ve en la pantalla, con su botón de reintentar.
        }
      },
      onNuevo: puede(ref, 'finanzas.bancos', Accion.crear)
          ? () => abrirHojaFinanzas(context, (_) => const _HojaCuenta())
          : null,
      textoNuevo: 'Nueva cuenta',
      iconoVacio: Icons.account_balance_outlined,
      singular: 'cuenta',
      plural: 'cuentas',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'En bancos',
          valor: formatoSoles(total),
          icono: Icons.account_balance_outlined,
          color: color,
          nota: '${activas.length} cuentas activas',
        ),
      ],
      filtro: BotonFiltros(
        activos: ref.watch(verInactivasBancosProvider) ? 1 : 0,
        color: color,
        onAbrir: () => mostrarFiltros(
          context,
          activos: ref.read(verInactivasBancosProvider) ? 1 : 0,
          onLimpiar: () =>
              ref.read(verInactivasBancosProvider.notifier).state = false,
          grupos: [
            Consumer(
              builder: (context, ref, _) => GrupoFiltro<bool>(
                titulo: 'Estado',
                valor: ref.watch(verInactivasBancosProvider),
                opciones: const [
                  OpcionFiltro(false, 'Activas'),
                  OpcionFiltro(true, 'Todas'),
                ],
                onCambio: (v) =>
                    ref.read(verInactivasBancosProvider.notifier).state = v,
              ),
            ),
          ],
        ),
      ),
      fila: (context, c) => _TarjetaCuenta(
        cuenta: c,
        color: color,
        onEditar: puedeEditar
            ? () => abrirHojaFinanzas(context, (_) => _HojaCuenta(cuenta: c))
            : null,
        onEstado: puedeEditar ? () => _cambiarEstado(context, ref, c) : null,
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
          ? 'Deja de ofrecerse para cobrar y pagar. Su historial se conserva.'
          : 'Vuelve a estar disponible.',
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

class _TarjetaCuenta extends StatelessWidget {
  const _TarjetaCuenta({
    required this.cuenta,
    required this.color,
    this.onEditar,
    this.onEstado,
  });

  final CuentaFinanciera cuenta;
  final Color color;
  final VoidCallback? onEditar;
  final VoidCallback? onEstado;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    void verMovimientos() =>
        abrirHojaFinanzas(context, (_) => HojaMovimientosCuenta(cuenta: c));

    return AppTarjetaRegistro(
      icono: Icons.account_balance_outlined,
      color: color,
      titulo: c.nombre,
      insignia: c.activo
          ? (c.banco == null ? null : AppEtiqueta(c.banco!))
          : const AppEtiqueta('Inactiva', tono: EtiquetaTono.aviso),
      campos: [
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
        CampoDetalle('Número', c.numeroCuenta),
        CampoDetalle('CCI', c.cci),
        CampoDetalle('Titular', c.titular),
      ],
      onTap: verMovimientos,
      acciones: [
        IconButton(
          onPressed: verMovimientos,
          tooltip: 'Movimientos',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.receipt_long_outlined,
            size: 18,
            color: Acento.de(context),
          ),
        ),
        if (onEditar != null)
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
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

/// Alta y edicion de una cuenta bancaria.
class _HojaCuenta extends ConsumerStatefulWidget {
  const _HojaCuenta({this.cuenta});

  /// Null cuando es nueva.
  final CuentaFinanciera? cuenta;

  @override
  ConsumerState<_HojaCuenta> createState() => _HojaCuentaState();
}

class _HojaCuentaState extends ConsumerState<_HojaCuenta> {
  late final _nombre = TextEditingController(text: widget.cuenta?.nombre ?? '');
  late final _numero = TextEditingController(
    text: widget.cuenta?.numeroCuenta ?? '',
  );
  late final _cci = TextEditingController(text: widget.cuenta?.cci ?? '');
  late final _titular = TextEditingController(
    text: widget.cuenta?.titular ?? '',
  );
  final _inicial = TextEditingController();
  late int? _bancoId = widget.cuenta?.bancoId;
  bool _guardando = false;
  String? _error;

  bool get _esNueva => widget.cuenta == null;

  @override
  void dispose() {
    for (final c in [_nombre, _numero, _cci, _titular, _inicial]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _texto(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final error = _nombre.text.trim().isEmpty
        ? 'Ingresa el nombre de la cuenta.'
        : _bancoId == null
        ? 'Elige el banco.'
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

    final cuerpo = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'naturaleza': 'BANCO',
      'bancoId': _bancoId,
      'numeroCuenta': _texto(_numero),
      'cci': _texto(_cci),
      'titular': _texto(_titular),
      'activo': widget.cuenta?.activo ?? true,
      // Solo al crearla: con cuanto ya venia la cuenta.
      if (_esNueva) 'montoInicial': double.tryParse(_inicial.text.trim()) ?? 0,
    };

    try {
      final api = ref.read(tesoreriaApiProvider);
      if (_esNueva) {
        await api.crearCuenta(cuerpo);
      } else {
        await api.actualizarCuenta(widget.cuenta!.id, cuerpo);
      }
      ref.invalidate(cuentasFinancierasProvider);
      navegador.pop();
      mensajero.mostrar(_esNueva ? 'Cuenta creada' : 'Cuenta actualizada');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  /// Da de alta el banco que falta sin salir del formulario, y lo elige.
  Future<void> _crearBanco() async {
    final nombre = TextEditingController();
    final escrito = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Nuevo banco'),
        content: TextField(
          controller: nombre,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'BCP, BBVA, Interbank...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(nombre.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    nombre.dispose();
    if (escrito == null || escrito.isEmpty || !mounted) return;

    try {
      final banco = await ref.read(tesoreriaApiProvider).crearBanco(escrito);
      ref.invalidate(bancosCatalogoProvider);
      setState(() => _bancoId = banco.id);
    } on ApiExcepcion catch (e) {
      setState(() => _error = e.texto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bancos = ref.watch(bancosCatalogoProvider);
    final puedeCrearBanco = puede(ref, 'finanzas.bancos', Accion.crear);

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloHoja(
              _esNueva
                  ? 'Nueva cuenta bancaria'
                  : 'Editar ${widget.cuenta!.nombre}',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppCampo(
              controlador: _nombre,
              etiqueta: 'Nombre',
              icono: Icons.label_outline,
              pista: 'BCP Cuenta corriente',
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            bancos.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppAlerta(
                e is ApiExcepcion ? e.texto : 'No pudimos cargar los bancos.',
              ),
              data: (lista) => AppSelector<int>(
                valor: lista.any((b) => b.id == _bancoId) ? _bancoId : null,
                etiqueta: 'Banco',
                icono: Icons.account_balance_outlined,
                habilitado: !_guardando,
                opciones: [
                  for (final b in lista.where(
                    (b) => b.activo || b.id == _bancoId,
                  ))
                    Opcion(b.id, b.nombre),
                ],
                onCambio: (v) => setState(() => _bancoId = v),
                onCrear: puedeCrearBanco ? _crearBanco : null,
                etiquetaCrear: 'Nuevo banco',
              ),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _numero,
              etiqueta: 'Número de cuenta',
              icono: Icons.numbers_outlined,
              opcional: true,
              tipoTeclado: TextInputType.number,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _cci,
              etiqueta: 'CCI',
              icono: Icons.tag,
              opcional: true,
              tipoTeclado: TextInputType.number,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _titular,
              etiqueta: 'Titular',
              icono: Icons.person_outline,
              opcional: true,
              habilitado: !_guardando,
            ),
            if (_esNueva) ...[
              const SizedBox(height: Dimen.espacio4),
              AppCampo(
                controlador: _inicial,
                etiqueta: 'Saldo inicial',
                icono: Icons.payments_outlined,
                pista: 'Lo que ya tiene la cuenta',
                opcional: true,
                tipoTeclado: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                formateadores: [soloMonto],
                habilitado: !_guardando,
              ),
            ],
            const SizedBox(height: Dimen.espacio5),
            AppBoton(
              texto: _esNueva ? 'Crear' : 'Guardar',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
