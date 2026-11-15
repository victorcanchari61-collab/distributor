import 'package:flutter/material.dart';

import '../../core/tema/dimensiones.dart';
import 'app_tarjeta_dato.dart';

/// Cuánto hay que pagar, cuánto ya se registró y cuánto falta, en tres
/// tarjetas, igual que `ResumenPagos` en el panel web.
///
/// Va arriba de la lista de pagos de una venta o una compra: antes era una
/// línea "Pagado: S/ X de S/ Y" al pie, que había que leer y restar a mano
/// para saber si faltaba algo. Si lo registrado pasa del total, la tercera
/// tarjeta avisa en rojo cuánto sobra.
class AppResumenPagos extends StatelessWidget {
  const AppResumenPagos({
    super.key,
    required this.total,
    required this.pagado,
    this.sangria = Dimen.espacio4,
  });

  final double total;
  final double pagado;

  /// El margen lateral del contenedor donde va: la fila se sale de él para
  /// deslizarse de borde a borde, como en las listas, y la primera tarjeta
  /// queda alineada con los campos de abajo.
  final double sangria;

  static String _soles(double n) => 'S/ ${n.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final falta = total - pagado > 0 ? total - pagado : 0.0;
    final sobra = pagado - total > 0.001 ? pagado - total : 0.0;

    final tarjetas = <AppTarjetaDato>[
      AppTarjetaDato(
        etiqueta: 'Total a pagar',
        valor: _soles(total),
        icono: Icons.receipt_long_outlined,
        tono: DatoTono.neutral,
      ),
      AppTarjetaDato(
        etiqueta: 'Pagado',
        valor: _soles(pagado),
        icono: Icons.check_circle_outline,
        tono: DatoTono.exito,
        progreso: total > 0 ? pagado / total : 0,
      ),
      if (sobra > 0)
        AppTarjetaDato(
          etiqueta: 'Sobra',
          valor: _soles(sobra),
          nota: 'los pagos pasan del total',
          icono: Icons.warning_amber_rounded,
          tono: DatoTono.peligro,
        )
      else
        AppTarjetaDato(
          etiqueta: 'Falta',
          valor: _soles(falta),
          nota: falta > 0.001 ? 'por registrar' : 'completo',
          icono: Icons.hourglass_empty,
          tono: falta > 0.001 ? DatoTono.aviso : DatoTono.exito,
        ),
    ];
    final alto = tarjetas.fold<double>(88, (m, t) => t.alto > m ? t.alto : m);

    // AppFilaDatos ya trae su margen lateral: se ensancha lo que mide el del
    // contenedor para no sumar los dos.
    return LayoutBuilder(
      builder: (context, limites) => SizedBox(
        height: alto,
        child: OverflowBox(
          minWidth: limites.maxWidth + sangria * 2,
          maxWidth: limites.maxWidth + sangria * 2,
          child: AppFilaDatos(tarjetas: tarjetas),
        ),
      ),
    );
  }
}
