import 'package:flutter/material.dart';

import '../../../compartido/fechas.dart';

/// Cada cuánto se vuelven a calcular las categorías de los clientes.
enum CicloCategorizacion {
  mensual('MENSUAL', 'Mensual', 'último mes cerrado', 'cada mes'),
  trimestral(
    'TRIMESTRAL',
    'Trimestral',
    'último trimestre cerrado',
    'cada trimestre',
  ),
  cuatrimestral(
    'CUATRIMESTRAL',
    'Cuatrimestral',
    'último cuatrimestre cerrado',
    'cada cuatrimestre',
  ),
  anual('ANUAL', 'Anual', 'últimos doce meses cerrados', 'cada mes');

  const CicloCategorizacion(
    this.clave,
    this.etiqueta,
    this.evalua,
    this.renueva,
  );

  final String clave;
  final String etiqueta;

  /// Qué se evalúa, para explicárselo a quien solo mira.
  final String evalua;
  final String renueva;

  static CicloCategorizacion desdeClave(String? clave) => values.firstWhere(
    (c) => c.clave == clave,
    orElse: () => CicloCategorizacion.trimestral,
  );
}

/// Los colores con nombre que guarda el backend: cada pantalla los pinta a su
/// manera.
const coloresCategoria = <String, ({String etiqueta, Color color})>{
  'sky': (etiqueta: 'Celeste', color: Color(0xFF0284C7)),
  'emerald': (etiqueta: 'Verde', color: Color(0xFF059669)),
  'amber': (etiqueta: 'Amarillo', color: Color(0xFFB45309)),
  'orange': (etiqueta: 'Naranja', color: Color(0xFFEA580C)),
  'violet': (etiqueta: 'Violeta', color: Color(0xFF7C3AED)),
  'rose': (etiqueta: 'Rosa', color: Color(0xFFE11D48)),
  'slate': (etiqueta: 'Gris', color: Color(0xFF64748B)),
};

Color colorDeCategoria(String? nombre) =>
    (coloresCategoria[nombre] ?? coloresCategoria['slate']!).color;

class CategoriaCliente {
  const CategoriaCliente({
    required this.codigo,
    required this.nombre,
    required this.color,
    required this.desde,
    required this.clientes,
  });

  /// A a F. La A es la más alta.
  final String codigo;
  final String nombre;
  final String color;

  /// Desde cuántos soles comprados entra en esta categoría.
  final double desde;

  /// Cuántos clientes tiene según el último cálculo.
  final int clientes;

  factory CategoriaCliente.desdeJson(Map<String, dynamic> json) =>
      CategoriaCliente(
        codigo: json['codigo'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
        color: json['color'] as String? ?? 'slate',
        desde: (json['desde'] as num?)?.toDouble() ?? 0,
        clientes: (json['clientes'] as num?)?.toInt() ?? 0,
      );
}

/// Qué se evalúa y desde cuándo rige el resultado.
class VentanaCategorizacion {
  const VentanaCategorizacion({
    required this.evaluadoDesde,
    required this.evaluadoHasta,
    required this.vigenteDesde,
    required this.vigenteHasta,
  });

  final DateTime evaluadoDesde;
  final DateTime evaluadoHasta;
  final DateTime vigenteDesde;

  /// El último día en que rige: el resultado cambia al día siguiente.
  final DateTime vigenteHasta;

  factory VentanaCategorizacion.desdeJson(Map<String, dynamic> json) =>
      VentanaCategorizacion(
        evaluadoDesde: fechaDeJson(json['evaluadoDesde'] as String),
        evaluadoHasta: fechaDeJson(json['evaluadoHasta'] as String),
        vigenteDesde: fechaDeJson(json['vigenteDesde'] as String),
        vigenteHasta: fechaDeJson(json['vigenteHasta'] as String),
      );
}

class Categorizacion {
  const Categorizacion({
    required this.ciclo,
    required this.categorias,
    required this.periodos,
    required this.recalculado,
  });

  final CicloCategorizacion ciclo;
  final List<CategoriaCliente> categorias;

  /// La ventana de cada ciclo: la pantalla muestra la del que se elige sin
  /// repetir la cuenta de las fechas.
  final Map<CicloCategorizacion, VentanaCategorizacion> periodos;

  /// La respuesta viene de guardar un cambio de ciclo, que recalculó las
  /// categorías en el acto.
  final bool recalculado;

  factory Categorizacion.desdeJson(Map<String, dynamic> json) {
    final periodos = (json['periodos'] as Map?) ?? const {};
    return Categorizacion(
      ciclo: CicloCategorizacion.desdeClave(json['ciclo'] as String?),
      categorias: [
        for (final c in (json['categorias'] as List?) ?? const [])
          CategoriaCliente.desdeJson(c as Map<String, dynamic>),
      ],
      periodos: {
        for (final c in CicloCategorizacion.values)
          if (periodos[c.clave] is Map)
            c: VentanaCategorizacion.desdeJson(
              periodos[c.clave] as Map<String, dynamic>,
            ),
      },
      recalculado: json['recalculado'] as bool? ?? false,
    );
  }
}
