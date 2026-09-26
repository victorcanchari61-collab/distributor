import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/formato.dart';
import '../../../compartido/widgets/app_alerta.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/tesoreria.dart';
import '../estado/tesoreria_controlador.dart';
import 'hojas_finanzas.dart';

/// Los movimientos de una caja o cuenta bancaria en los ultimos 30 dias, con
/// el saldo que dejo cada uno. La usan Cajas y Bancos.
class HojaMovimientosCuenta extends ConsumerWidget {
  const HojaMovimientosCuenta({super.key, required this.cuenta});

  final CuentaFinanciera cuenta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(movimientosCuentaProvider(cuenta.id));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: margenHoja(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloHoja(
              cuenta.nombre,
              apoyo:
                  'Saldo actual ${formatoSoles(cuenta.saldoActual)} · últimos 30 días',
            ),
            Flexible(
              child: movimientos.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(Dimen.espacio5),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => AppAlerta(
                  e is ApiExcepcion
                      ? e.texto
                      : 'No pudimos cargar los movimientos.',
                ),
                data: (lista) => lista.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(Dimen.espacio5),
                        child: Text(
                          'Sin movimientos en los últimos 30 días.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colores.tintaSuave),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = lista[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              m.concepto,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${fechaHora(m.fecha)}'
                              '${m.observacion != null ? ' · ${m.observacion}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${m.esIngreso ? '+' : '-'}${formatoSoles(m.monto)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: m.esIngreso
                                        ? Colores.exito
                                        : Colores.peligro,
                                  ),
                                ),
                                Text(
                                  formatoSoles(m.saldoResultante),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colores.tintaSuave,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
