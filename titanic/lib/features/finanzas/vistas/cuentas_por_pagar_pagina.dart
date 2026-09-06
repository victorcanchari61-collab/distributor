import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_lista_pagina.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_tarjeta_dato.dart';
import '../../../compartido/widgets/app_tarjeta_registro.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../../compras/datos/compra.dart';
import '../../compras/estado/compras_controlador.dart';
import '../datos/metodo_pago.dart';
import '../estado/finanzas_controlador.dart';

/// Compras al credito con saldo pendiente de pago al proveedor.
class CuentasPorPagarPagina extends ConsumerWidget {
  const CuentasPorPagarPagina({super.key});

  static const ruta = '/finanzas/pagar';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolverRuta(ruta).grupo?.color ?? Colores.marca;
    final todas = ref.watch(cuentasPorPagarProvider).valueOrNull ?? const <Compra>[];
    final totalSaldo = todas.fold<double>(0, (n, v) => n + (v.total - v.totalPagado));

    return AppListaPagina<Compra>(
      titulo: 'Cuentas por pagar',
      ruta: ruta,
      estado: ref.watch(cuentasPorPagarProvider),
      visibles: ref.watch(cuentasPorPagarFiltradasProvider),
      busqueda: ref.watch(busquedaCuentasPorPagarProvider),
      onBuscar: (t) => ref.read(busquedaCuentasPorPagarProvider.notifier).state = t,
      pistaBusqueda: 'Buscar por número o proveedor',
      onRecargar: () => ref.read(cuentasPorPagarProvider.notifier).recargar(),
      iconoVacio: Icons.credit_card_outlined,
      singular: 'cuenta por pagar',
      plural: 'cuentas por pagar',
      indicadores: [
        AppTarjetaDato(
          etiqueta: 'Cuentas por pagar',
          valor: '${todas.length}',
          icono: Icons.credit_card_outlined,
          color: color,
        ),
        AppTarjetaDato(
          etiqueta: 'Saldo pendiente',
          valor: 'S/ ${totalSaldo.toStringAsFixed(2)}',
          icono: Icons.pending_actions_outlined,
          tono: totalSaldo > 0 ? DatoTono.aviso : DatoTono.exito,
        ),
      ],
      fila: (context, compra) => _TarjetaCuentaPagar(
        compra: compra,
        color: color,
        onGestionarPagos: () => _gestionarPagos(context, ref, compra),
      ),
    );
  }

  Future<void> _gestionarPagos(BuildContext context, WidgetRef ref, Compra compra) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colores.superficie,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimen.radioPanel)),
      ),
      builder: (context) => _HojaPagosPagar(compraId: compra.id),
    );
  }
}

class _TarjetaCuentaPagar extends StatelessWidget {
  const _TarjetaCuentaPagar({
    required this.compra,
    required this.color,
    required this.onGestionarPagos,
  });

  final Compra compra;
  final Color color;
  final VoidCallback onGestionarPagos;

  @override
  Widget build(BuildContext context) {
    final saldo = compra.total - compra.totalPagado;

    return AppTarjetaRegistro(
      icono: Icons.credit_card_outlined,
      color: color,
      titulo: compra.numero,
      insignia: const AppEtiqueta('Vigente', tono: EtiquetaTono.exito),
      campos: [
        CampoDetalle('Proveedor', compra.proveedor),
        CampoDetalle('Fecha', _fecha(compra.fecha)),
        CampoDetalle('Total', 'S/ ${compra.total.toStringAsFixed(2)}'),
        CampoDetalle('Pagado', 'S/ ${compra.totalPagado.toStringAsFixed(2)}'),
        CampoDetalle(
          'Saldo',
          'S/ ${saldo.toStringAsFixed(2)}',
          widget: Text(
            'S/ ${saldo.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colores.advertencia,
            ),
          ),
        ),
      ],
      acciones: [
        IconButton(
          onPressed: onGestionarPagos,
          tooltip: 'Gestionar pagos',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.request_quote_outlined, size: 18, color: Colores.marca),
        ),
      ],
    );
  }
}

/// Contenido de la hoja de gestion de pagos: lista los pagos de la compra
/// (incluidos los anulados) y permite registrar uno nuevo, editar o anular.
class _HojaPagosPagar extends ConsumerStatefulWidget {
  const _HojaPagosPagar({required this.compraId});

  final int compraId;

  @override
  ConsumerState<_HojaPagosPagar> createState() => _HojaPagosPagarState();
}

class _HojaPagosPagarState extends ConsumerState<_HojaPagosPagar> {
  PagoCompra? _editando;
  String? _tipoNuevo;
  int? _metodoNuevoId;
  final _montoCtrl = TextEditingController();
  String? _tipoEditar;
  int? _metodoEditarId;
  final _montoEditarCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _montoEditarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compras = ref.watch(cuentasPorPagarProvider).valueOrNull ?? const <Compra>[];
    Compra? compra;
    for (final c in compras) {
      if (c.id == widget.compraId) compra = c;
    }
    if (compra == null) {
      // El saldo llego a cero: la compra salio de la lista. Cierra la hoja.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    final metodos = ref.watch(metodosPagoActivosProvider);
    final saldo = compra.total - compra.totalPagado;

    return Padding(
      padding: EdgeInsets.only(
        left: Dimen.espacio4,
        right: Dimen.espacio4,
        top: Dimen.espacio2,
        bottom: Dimen.espacio4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pagos de ${compra.numero}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.tinta),
            ),
            const SizedBox(height: Dimen.espacio1),
            Text(
              'Saldo pendiente: S/ ${saldo.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
            ),
            const SizedBox(height: Dimen.espacio4),

            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],

            for (final pago in compra.pagos) ...[
              _FilaPago(
                pago: pago,
                enEdicion: _editando?.id == pago.id,
                onEditar: pago.anulado
                    ? null
                    : () => setState(() {
                        _editando = pago;
                        _tipoEditar = null;
                        _metodoEditarId = pago.metodoPagoId;
                        _montoEditarCtrl.text = pago.monto.toStringAsFixed(2);
                        _error = null;
                      }),
                onAnular: pago.anulado
                    ? null
                    : () => _anular(context, compra!, pago),
              ),
              if (_editando?.id == pago.id)
                _FormularioEdicion(
                  metodos: metodos,
                  tipo: _tipoEditar,
                  metodoId: _metodoEditarId,
                  montoCtrl: _montoEditarCtrl,
                  onTipo: (v) => setState(() {
                    _tipoEditar = v;
                    _metodoEditarId = null;
                  }),
                  onMetodo: (v) => setState(() => _metodoEditarId = v),
                  onCancelar: () => setState(() => _editando = null),
                  onGuardar: () => _guardarEdicion(context, compra!, pago),
                ),
              const SizedBox(height: Dimen.espacio2),
            ],
            if (compra.pagos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Dimen.espacio3),
                child: Text(
                  'Todavía no hay pagos registrados.',
                  style: TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
                ),
              ),

            const SizedBox(height: Dimen.espacio3),
            const Divider(height: 1),
            const SizedBox(height: Dimen.espacio3),

            const Text(
              'Agregar pago',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colores.tinta),
            ),
            const SizedBox(height: Dimen.espacio3),

            AppSelector<String>(
              valor: _tipoNuevo,
              etiqueta: 'Tipo',
              icono: Icons.category_outlined,
              opciones: [for (final t in TipoMetodoPago.todos) Opcion(t, TipoMetodoPago.etiqueta(t))],
              onCambio: (v) => setState(() {
                _tipoNuevo = v;
                _metodoNuevoId = null;
              }),
            ),
            const SizedBox(height: Dimen.espacio3),

            AppSelector<int>(
              valor: _metodoNuevoId,
              etiqueta: 'Método',
              icono: Icons.payments_outlined,
              habilitado: _tipoNuevo != null,
              opciones: [
                for (final m in metodos.where((m) => m.tipo == _tipoNuevo))
                  Opcion(m.id, m.nombre),
              ],
              onCambio: (v) => setState(() => _metodoNuevoId = v),
            ),
            const SizedBox(height: Dimen.espacio3),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppCampo(
                    controlador: _montoCtrl,
                    etiqueta: 'Monto',
                    icono: Icons.attach_money,
                    tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                AppBoton(texto: 'Agregar', onPressed: () => _registrar(context, compra!)),
              ],
            ),
            const SizedBox(height: Dimen.espacio3),

            AppBoton(
              texto: 'Listo',
              variante: BotonVariante.secundario,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registrar(BuildContext context, Compra compra) async {
    final monto = double.tryParse(_montoCtrl.text.trim().replaceAll(',', '.'));
    if (_metodoNuevoId == null) {
      setState(() => _error = 'Elige el método de pago.');
      return;
    }
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresa un monto válido.');
      return;
    }

    try {
      await ref
          .read(cuentasPorPagarProvider.notifier)
          .registrarPago(compra.id, {'metodoPagoId': _metodoNuevoId, 'monto': monto});
      if (!mounted) return;
      setState(() {
        _error = null;
        _tipoNuevo = null;
        _metodoNuevoId = null;
        _montoCtrl.clear();
      });
    } on ApiExcepcion catch (e) {
      setState(() => _error = e.texto);
    }
  }

  Future<void> _guardarEdicion(BuildContext context, Compra compra, PagoCompra pago) async {
    final monto = double.tryParse(_montoEditarCtrl.text.trim().replaceAll(',', '.'));
    if (_metodoEditarId == null) {
      setState(() => _error = 'Elige el método de pago.');
      return;
    }
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresa un monto válido.');
      return;
    }

    try {
      await ref
          .read(cuentasPorPagarProvider.notifier)
          .actualizarPago(compra.id, pago.id, {'metodoPagoId': _metodoEditarId, 'monto': monto});
      if (!mounted) return;
      setState(() {
        _error = null;
        _editando = null;
      });
    } on ApiExcepcion catch (e) {
      setState(() => _error = e.texto);
    }
  }

  Future<void> _anular(BuildContext context, Compra compra, PagoCompra pago) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Anular pago de S/ ${pago.monto.toStringAsFixed(2)}',
      mensaje:
          'Queda en el historial marcado como anulado y su monto vuelve al saldo pendiente. No se puede revertir.',
      textoConfirmar: 'Anular',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !mounted) return;

    try {
      await ref.read(cuentasPorPagarProvider.notifier).anularPago(compra.id, pago.id);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.texto);
    }
  }
}

class _FilaPago extends StatelessWidget {
  const _FilaPago({
    required this.pago,
    required this.enEdicion,
    this.onEditar,
    this.onAnular,
  });

  final PagoCompra pago;
  final bool enEdicion;
  final VoidCallback? onEditar;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: enEdicion ? Colores.marcaSuave : Colores.fondo,
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fecha(pago.fecha)} · ${pago.metodoPago}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colores.tinta),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pagado por ${pago.usuario ?? '—'}',
                  style: const TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
                ),
              ],
            ),
          ),
          Text(
            'S/ ${pago.monto.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: pago.anulado ? Colores.tintaTenue : Colores.tinta,
              decoration: pago.anulado ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(width: Dimen.espacio2),
          AppEtiqueta(
            pago.anulado ? 'Anulado' : 'Válido',
            tono: pago.anulado ? EtiquetaTono.peligro : EtiquetaTono.exito,
          ),
          if (onEditar != null)
            IconButton(
              onPressed: onEditar,
              tooltip: 'Editar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 17, color: Colores.marca),
            ),
          if (onAnular != null)
            IconButton(
              onPressed: onAnular,
              tooltip: 'Anular',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.block, size: 17, color: Colores.peligro),
            ),
        ],
      ),
    );
  }
}

class _FormularioEdicion extends StatelessWidget {
  const _FormularioEdicion({
    required this.metodos,
    required this.tipo,
    required this.metodoId,
    required this.montoCtrl,
    required this.onTipo,
    required this.onMetodo,
    required this.onCancelar,
    required this.onGuardar,
  });

  final List<MetodoPago> metodos;
  final String? tipo;
  final int? metodoId;
  final TextEditingController montoCtrl;
  final ValueChanged<String?> onTipo;
  final ValueChanged<int?> onMetodo;
  final VoidCallback onCancelar;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Dimen.espacio2),
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.lineaFuerte),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSelector<String>(
            valor: tipo,
            etiqueta: 'Tipo',
            icono: Icons.category_outlined,
            opciones: [for (final t in TipoMetodoPago.todos) Opcion(t, TipoMetodoPago.etiqueta(t))],
            onCambio: onTipo,
          ),
          const SizedBox(height: Dimen.espacio3),
          AppSelector<int>(
            valor: metodoId,
            etiqueta: 'Método',
            icono: Icons.payments_outlined,
            opciones: [
              for (final m in metodos.where((m) => tipo == null || m.tipo == tipo))
                Opcion(m.id, m.nombre),
            ],
            onCambio: onMetodo,
          ),
          const SizedBox(height: Dimen.espacio3),
          AppCampo(
            controlador: montoCtrl,
            etiqueta: 'Monto',
            icono: Icons.attach_money,
            tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: Dimen.espacio3),
          Row(
            children: [
              Expanded(
                child: AppBoton(
                  texto: 'Cancelar',
                  variante: BotonVariante.secundario,
                  expandido: true,
                  onPressed: onCancelar,
                ),
              ),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: AppBoton(texto: 'Guardar', expandido: true, onPressed: onGuardar),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
