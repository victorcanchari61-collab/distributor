import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/dimensiones.dart';
import '../estado/mi_caja_controlador.dart';
import '../estado/tesoreria_controlador.dart';
import 'hojas_finanzas.dart';

/// Una cuenta que se puede elegir; el saldo solo si quien abre la hoja lo conoce.
class CuentaParaMover {
  const CuentaParaMover({required this.id, required this.etiqueta, this.saldo});

  final int id;
  final String etiqueta;
  final double? saldo;
}

/// Mover plata de una cuenta propia a otra: depositar lo de la Boveda en el
/// banco, darle sencillo a un repartidor, retirar del banco. No es ingreso ni
/// gasto: en el estado de resultados no suma nada.
class HojaMoverPlata extends ConsumerStatefulWidget {
  const HojaMoverPlata({super.key, required this.cuentas, this.origenInicial});

  final List<CuentaParaMover> cuentas;
  final int? origenInicial;

  @override
  ConsumerState<HojaMoverPlata> createState() => _HojaMoverPlataState();
}

class _HojaMoverPlataState extends ConsumerState<HojaMoverPlata> {
  late int? _origenId = widget.origenInicial;
  int? _destinoId;
  final _monto = TextEditingController();
  final _detalle = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _mover() async {
    FocusScope.of(context).unfocus();
    final monto = double.tryParse(_monto.text.trim());
    final error = _origenId == null
        ? 'Elige de dónde sale la plata.'
        : _destinoId == null
        ? 'Elige a dónde va la plata.'
        : monto == null || monto <= 0
        ? 'Ingresa un monto mayor a cero.'
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
      await ref
          .read(tesoreriaApiProvider)
          .transferir(
            origenId: _origenId!,
            destinoId: _destinoId!,
            monto: monto!,
            observacion: _detalle.text.trim().isEmpty
                ? null
                : _detalle.text.trim(),
          );
      ref.invalidate(cuentasFinancierasProvider);
      ref.invalidate(movimientosDineroProvider);
      ref.invalidate(miCajaProvider);
      ref.invalidate(movimientosMiCajaProvider);
      navegador.pop();
      mensajero.mostrar('Plata movida');
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  Opcion<int> _opcion(CuentaParaMover c) => Opcion(
    c.id,
    c.saldo == null ? c.etiqueta : '${c.etiqueta} · ${formatoSoles(c.saldo!)}',
  );

  @override
  Widget build(BuildContext context) {
    final origen = widget.cuentas.where((c) => c.id == _origenId).firstOrNull;

    return Padding(
      padding: margenHoja(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloHoja(
              'Mover plata',
              apoyo:
                  'De una cuenta propia a otra: un depósito, el sencillo de un '
                  'repartidor, un retiro. No es ingreso ni gasto.',
            ),
            if (_error != null) ...[
              AppAlerta(_error!),
              const SizedBox(height: Dimen.espacio3),
            ],
            AppSelector<int>(
              valor: _origenId,
              etiqueta: 'Sale de',
              icono: Icons.north_east,
              habilitado: !_guardando,
              opciones: [for (final c in widget.cuentas) _opcion(c)],
              onCambio: (v) => setState(() {
                _origenId = v;
                if (_destinoId == v) _destinoId = null;
              }),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppSelector<int>(
              valor: _destinoId,
              etiqueta: 'Va a',
              icono: Icons.south_west,
              habilitado: !_guardando,
              opciones: [
                for (final c in widget.cuentas.where((c) => c.id != _origenId))
                  _opcion(c),
              ],
              onCambio: (v) => setState(() => _destinoId = v),
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _monto,
              etiqueta: 'Monto',
              icono: Icons.payments_outlined,
              pista: origen?.saldo == null
                  ? '0.00'
                  : 'Disponible ${formatoSoles(origen!.saldo!)}',
              tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
              formateadores: [soloMonto],
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio4),
            AppCampo(
              controlador: _detalle,
              etiqueta: 'Detalle',
              icono: Icons.notes_outlined,
              pista: 'Depósito del día, sencillo para la ruta...',
              opcional: true,
              habilitado: !_guardando,
            ),
            const SizedBox(height: Dimen.espacio5),
            AppBoton(texto: 'Mover', cargando: _guardando, onPressed: _mover),
          ],
        ),
      ),
    );
  }
}
