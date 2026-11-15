import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Gravedad del indicador, los mismos tonos que `StatCard` en el panel web.
enum DatoTono { modulo, neutral, exito, aviso, peligro }

/// El enlace al pie de una tarjeta: lo normal es que aplique su filtro en la lista de abajo ("Ver los 12"), igual que
/// en el panel web.
class AccionDato {
  const AccionDato({required this.etiqueta, required this.onTap});

  final String etiqueta;
  final VoidCallback onTap;
}

/// Tarjeta de indicador.
///
/// El icono es obligatorio a proposito, igual que en el web: en una fila de
/// tres o cuatro tarjetas el ojo se guia por la forma antes que por el texto,
/// y una sin icono rompe el ritmo de la fila.
///
/// Como en el web, puede llevar una barra con qué parte del total es su
/// número ([progreso]) y un enlace al pie que lleva a lo que cuenta
/// ([accion]); con enlace, la aclaración ([nota]) baja al pie junto a él.
class AppTarjetaDato extends StatelessWidget {
  const AppTarjetaDato({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.tono = DatoTono.modulo,
    this.nota,
    this.color,
    this.progreso,
    this.accion,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;
  final DatoTono tono;

  /// Aclaracion corta bajo el numero.
  final String? nota;

  /// Color del modulo, cuando el tono es [DatoTono.modulo].
  final Color? color;

  /// Qué parte del total es este número, de 0 a 1: se dibuja una barra y el
  /// porcentaje al lado del número.
  final double? progreso;

  /// El enlace al pie ("Ver los 12 →").
  final AccionDato? accion;

  /// Alto que necesita la tarjeta, para que la fila que se desliza sepa
  /// cuánto reservar.
  double get alto => 88 + (progreso != null ? 6 : 0) + (accion != null ? 30 : 0);

  Color _colorDe(BuildContext context) => switch (tono) {
    DatoTono.modulo => color ?? Acento.de(context),
    DatoTono.neutral => Colores.tintaSuave,
    DatoTono.exito => Colores.exito,
    DatoTono.aviso => Colores.advertencia,
    DatoTono.peligro => Colores.peligro,
  };

  @override
  Widget build(BuildContext context) {
    final colorTono = _colorDe(context);
    final pct = progreso == null ? null : (progreso!.clamp(0.0, 1.0) * 100).round();
    final notaArriba = accion == null ? nota : null;

    return Container(
      // Ancho fijo: en la fila que se desliza cada tarjeta conserva un ancho
      // legible y se ve que hay mas a la derecha.
      width: accion != null ? 196 : 178,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimen.espacio3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Franja de color: da identidad sin llenar la tarjeta de fondo.
                Container(
                  width: 3,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorTono,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: Dimen.espacio3),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorTono.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Dimen.radioCampo),
                  ),
                  child: Icon(icono, size: 17, color: colorTono),
                ),
                const SizedBox(width: Dimen.espacio2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colores.tintaSuave,
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              valor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: Colores.tinta,
                              ),
                            ),
                          ),
                          if (pct != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: colorTono.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$pct%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colorTono,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (notaArriba != null)
                        Text(
                          notaArriba,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colores.tintaTenue,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // La barra va de borde a borde, fina: dice qué parte del total es el número.
          if (progreso != null)
            SizedBox(
              height: 4,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Colores.fondo)),
                  FractionallySizedBox(
                    widthFactor: progreso!.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: colorTono),
                  ),
                ],
              ),
            ),

          if (accion != null)
            InkWell(
              onTap: accion!.onTap,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio3),
                decoration: BoxDecoration(
                  border: progreso == null
                      ? const Border(top: BorderSide(color: Colores.linea))
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        nota ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: Colores.tintaTenue),
                      ),
                    ),
                    Text(
                      '${accion!.etiqueta} →',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Acento.de(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fila de indicadores que se desliza de lado.
///
/// Apiladas una sobre otra empujaban la lista fuera de la pantalla y obligaban
/// a hacer scroll antes de ver el primer registro, el mismo motivo por el que
/// en el web van en una fila desplazable en movil.
class AppFilaDatos extends StatelessWidget {
  const AppFilaDatos({super.key, required this.tarjetas});

  final List<Widget> tarjetas;

  @override
  Widget build(BuildContext context) {
    if (tarjetas.isEmpty) return const SizedBox.shrink();

    // Lo que pida la tarjeta más alta: con barra o enlace al pie miden más que las de solo número.
    final alto = tarjetas
        .whereType<AppTarjetaDato>()
        .fold<double>(88, (maximo, t) => t.alto > maximo ? t.alto : maximo);

    return SizedBox(
      height: alto,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
        itemCount: tarjetas.length,
        separatorBuilder: (context, i) => const SizedBox(width: Dimen.espacio2),
        itemBuilder: (context, i) => Align(alignment: Alignment.topCenter, child: tarjetas[i]),
      ),
    );
  }
}
