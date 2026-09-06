import 'package:flutter/material.dart';

import '../../core/tema/acento.dart';
import '../../core/tema/colores.dart';
import '../../core/tema/dimensiones.dart';

/// Gravedad del indicador, los mismos tonos que `StatCard` en el panel web.
enum DatoTono { modulo, neutral, exito, aviso, peligro }

/// Tarjeta de indicador.
///
/// El icono es obligatorio a proposito, igual que en el web: en una fila de
/// tres o cuatro tarjetas el ojo se guia por la forma antes que por el texto,
/// y una sin icono rompe el ritmo de la fila.
class AppTarjetaDato extends StatelessWidget {
  const AppTarjetaDato({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.tono = DatoTono.modulo,
    this.nota,
    this.color,
  });

  final String etiqueta;
  final String valor;
  final IconData icono;
  final DatoTono tono;

  /// Aclaracion corta bajo el numero.
  final String? nota;

  /// Color del modulo, cuando el tono es [DatoTono.modulo].
  final Color? color;

  Color _colorDe(BuildContext context) => switch (tono) {
    DatoTono.modulo => color ?? Acento.de(context),
    DatoTono.neutral => Colores.tintaSuave,
    DatoTono.exito => Colores.exito,
    DatoTono.aviso => Colores.advertencia,
    DatoTono.peligro => Colores.peligro,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      // Ancho fijo: en la fila que se desliza cada tarjeta conserva un ancho
      // legible y se ve que hay mas a la derecha.
      width: 178,
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Franja de color: da identidad sin llenar la tarjeta de fondo.
          Container(
            width: 3,
            height: 42,
            decoration: BoxDecoration(
              color: _colorDe(context),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: Dimen.espacio3),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _colorDe(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Dimen.radioCampo),
            ),
            child: Icon(icono, size: 17, color: _colorDe(context)),
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
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
                if (nota != null)
                  Text(
                    nota!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Colores.tintaTenue),
                  ),
              ],
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

    return SizedBox(
      // 88: alto suficiente para etiqueta, numero y nota sin recortes.
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
        itemCount: tarjetas.length,
        separatorBuilder: (context, i) => const SizedBox(width: Dimen.espacio2),
        itemBuilder: (context, i) => tarjetas[i],
      ),
    );
  }
}
