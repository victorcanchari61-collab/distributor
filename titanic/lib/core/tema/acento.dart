import 'package:flutter/material.dart';

import 'colores.dart';

/// El color del módulo en el que se está, heredado por todo lo que hay debajo.
///
/// Es el equivalente del `data-sys` del panel web: allá el módulo se declara
/// una vez en un contenedor y los hijos leen `var(--sys-rgb)`. Aquí no había
/// nada parecido, así que cada componente compartido pintaba el azul de marca
/// a pelo y una hoja de productos abierta desde Compras salía azul en vez de
/// violeta.
///
/// Se resuelve por herencia y no pasando el color por parámetro porque los
/// componentes intermedios —tarjetas, listas, campos— no tienen por qué saber
/// de módulos solo para hacerle de correo al que sí lo necesita.
class Acento extends InheritedWidget {
  const Acento({super.key, required this.color, required super.child});

  final Color color;

  /// El acento vigente. Sin nadie que lo declare, el azul de marca.
  static Color de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Acento>()?.color ?? Colores.marca;

  /// El mismo color al 8%, para fondos de chip y de fila marcada.
  static Color suave(BuildContext context) => de(context).withValues(alpha: 0.08);

  /// El acento de un módulo por su clave del menú: 'compras', 'inv', 'fact'...
  static Color deModulo(String modulo) => Colores.modulos[modulo] ?? Colores.marca;

  /// Envuelve algo con el acento de un módulo.
  ///
  /// Lo usan las pantallas que no pasan por AppShell —los formularios, que son
  /// su propio Scaffold— y las hojas modales, que cuelgan del Navigator y por
  /// eso no ven el acento de la pantalla que las abrió.
  static Widget modulo(String modulo, Widget child) =>
      Acento(color: deModulo(modulo), child: child);

  @override
  bool updateShouldNotify(Acento anterior) => anterior.color != color;
}
