/*
 * Qué FILAS ve alguien en cada pantalla: todas, solo las de su ruta, o solo las
 * que registró. Es distinto de los permisos: el permiso dice si entra y qué
 * botones tiene; esto dice de qué clientes y ventas. Se elige en "Qué ve", en
 * la misma matriz de permisos, por rol y, si hace falta, por persona.
 *
 * Espejo de `Frontend/src/features/config/alcanceDatos.ts`.
 */

/// Un nivel de alcance como lo guarda el backend (`AlcanceDatos`), con su
/// texto de pantalla y lo que implica.
class NivelAlcance {
  const NivelAlcance(this.valor, this.texto, this.nota);

  /// `todos`, `misclientes`, `propios`, o '' para "Igual que su rol".
  final String valor;
  final String texto;
  final String nota;
}

/// El texto de pantalla no es el nombre interno: "misclientes" se lee "Solo
/// mis rutas" porque eso es lo que hace ahora —los clientes de las rutas que la
/// persona tiene a cargo—.
const nivelesAlcance = <NivelAlcance>[
  NivelAlcance('todos', 'Todos', 'Sin restricción: ve lo de todas las rutas'),
  NivelAlcance(
    'misclientes',
    'Solo mis rutas',
    'Los clientes de las rutas que tiene a cargo, más lo que él mismo '
        'registró. Sin ruta no ve ninguno',
  ),
  NivelAlcance(
    'propios',
    'Solo lo que registré',
    'Únicamente lo que registró él, de cualquier cliente',
  ),
];

/// Cómo se llama lo que se restringe en cada pantalla.
const _queVe = <String, String>{
  'maestros.clientes': 'Clientes que puede modificar',
  'fact.pedidos': 'Pedidos que ve y clientes que puede vender',
  'fact.notaventa': 'Notas de venta que ve y clientes que puede vender',
  'finanzas.ganancias': 'Ganancias que ve',
  'finanzas.cierres': 'Cierres de caja y cobros digitales que ve',
};

/// Las pantallas sin clientes de por medio: ahí no hay "mis rutas", solo todo
/// o lo propio. Cada una dice cómo se lee "lo propio".
const _soloPropios = <String, ({String texto, String nota})>{
  'finanzas.cierres': (
    texto: 'Solo los suyos',
    nota: 'Únicamente los cierres de su propia caja y los cobros que él hizo',
  ),
};

/// Los niveles que admite una pantalla. Con [heredable] empieza por "Igual que
/// su rol" (valor ''), que solo tiene sentido al configurar a una persona.
List<NivelAlcance> opcionesAlcance(String submodulo, {bool heredable = false}) {
  final propio = _soloPropios[submodulo];
  final niveles = propio == null
      ? nivelesAlcance
      : [
          for (final n in nivelesAlcance)
            if (n.valor == 'propios')
              NivelAlcance(n.valor, propio.texto, propio.nota)
            else if (n.valor != 'misclientes')
              n,
        ];
  return [
    if (heredable)
      const NivelAlcance(
        '',
        'Igual que su rol',
        'Usa el alcance que le da su rol',
      ),
    ...niveles,
  ];
}

/// Qué se restringe en esa pantalla, dicho para quien configura.
String queVe(String submodulo) => _queVe[submodulo] ?? 'Qué filas ve';
