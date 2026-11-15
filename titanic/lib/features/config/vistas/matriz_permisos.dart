import 'package:flutter/material.dart';

import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/alcance_datos.dart';
import '../datos/config_modelos.dart';

/// Como se nombra cada accion en pantalla, y en que orden se lee.
///
/// Es solo la presentacion: que acciones existen de verdad en cada pantalla lo
/// dice el catalogo del backend. Este mapa fija el orden para que la misma
/// accion caiga siempre en el mismo sitio de submodulo a submodulo.
const accionesPermiso = <String, String>{
  'ver': 'Ver',
  'crear': 'Crear',
  'editar': 'Editar',
  'confirmar': 'Confirmar',
  'cobrar': 'Cobrar',
  'anular': 'Anular',
  'eliminar': 'Eliminar',
  'exportar': 'Exportar',
  'importar': 'Importar',
  'ingreso': 'Ingreso',
  'egreso': 'Egreso',
  'transferir': 'Mover plata',
};

/// Un permiso como lo guarda el backend: "submodulo:accion".
String clavePermiso(String submodulo, String accion) => '$submodulo:$accion';

/// Nombre de la pantalla en el menu. Hay submodulos que el menu del telefono no
/// muestra (series, parametros) y ahi se cae a la clave: siguen siendo
/// configurables aunque no tengan vista propia.
({String titulo, IconData? icono}) vistaPermiso(String submodulo) {
  final item = vistaPorId(submodulo);
  return (titulo: item?.titulo ?? submodulo, icono: item?.icono);
}

/// Qué filas ve en cada pantalla que lo admite (todas, solo su ruta, solo lo
/// suyo). Va en la misma fila de la pantalla, para configurarla entera en un
/// solo sitio.
class AlcanceEnMatriz {
  const AlcanceEnMatriz({
    required this.pantallas,
    required this.valores,
    required this.onCambio,
    this.deshabilitado = false,
    this.heredado,
  });

  /// Las pantallas donde se puede limitar.
  final List<String> pantallas;
  final Map<String, String> valores;
  final void Function(String submodulo, String nivel) onCambio;
  final bool deshabilitado;

  /// Para una persona: ofrece "Igual que su rol" (valor ''), que es lo que
  /// tiene mientras no se le cambie. Trae lo que su rol ve en cada pantalla,
  /// para decirlo en esa opción.
  final Map<String, String>? heredado;
}

/// Los permisos ordenados como el menú: un bloque plegable por módulo y,
/// dentro, una fila por pantalla que se abre para mostrar sus acciones y qué
/// ve.
///
/// La usan las dos preguntas de Accesos: qué hace un rol y qué le falta a una
/// persona. Así se busca igual en las dos —por donde está en el menú— en vez de
/// adivinar el nombre interno de la pantalla. Es el `MatrizPermisos` del panel
/// web; en el teléfono no cabe su tabla, así que cada pantalla se abre en el
/// sitio y cada acción lleva su texto completo en vez de depender de una
/// cabecera de columna que quedaría fuera de la vista.
class MatrizPermisos extends StatefulWidget {
  const MatrizPermisos({
    super.key,
    required this.catalogo,
    required this.marcadas,
    required this.onAlternar,
    this.fijas,
    this.onMarcarSubmodulo,
    this.onMarcarModulo,
    this.filtro = '',
    this.nuevas = false,
    this.alcance,
  });

  final List<SubmoduloCatalogo> catalogo;

  /// Lo marcado y editable.
  final Set<String> marcadas;
  final void Function(String submodulo, String accion, List<String> acciones)
  onAlternar;

  /// Lo que ya tiene y aquí no se puede tocar (por su rol, o concedido antes),
  /// con el porqué. Se ve marcado y en gris.
  final Map<String, String>? fijas;

  /// "Marcar / Quitar" por pantalla y por módulo. Sin ellos no se muestran.
  final void Function(String submodulo, List<String> acciones, bool marcar)?
  onMarcarSubmodulo;
  final void Function(List<SubmoduloCatalogo> submodulos, bool marcar)?
  onMarcarModulo;

  /// Deja solo las pantallas cuyo nombre lo contiene, con todo abierto.
  final String filtro;

  /// Cuenta lo marcado ("2 nuevos") en vez de las pantallas que ve.
  final bool nuevas;

  final AlcanceEnMatriz? alcance;

  @override
  State<MatrizPermisos> createState() => _MatrizPermisosState();
}

class _MatrizPermisosState extends State<MatrizPermisos> {
  /// Modulos desplegados. Varios a la vez: comparar dos modulos es justo lo
  /// que se viene a hacer aqui.
  final Set<String> _abiertos = {};

  /// Pantallas desplegadas, por clave de submodulo.
  final Set<String> _detalles = {};

  @override
  Widget build(BuildContext context) {
    final buscado = widget.filtro.trim().toLowerCase();

    // Los modulos en el orden del menu, y solo los que el catalogo declara.
    final modulos = <({MenuGrupo grupo, List<SubmoduloCatalogo> submodulos})>[];
    for (final grupo in menuGrupos) {
      final suyos = [
        for (final s in widget.catalogo)
          if (s.modulo == grupo.id &&
              (buscado.isEmpty ||
                  vistaPermiso(
                    s.submodulo,
                  ).titulo.toLowerCase().contains(buscado)))
            s,
      ];
      if (suyos.isNotEmpty) modulos.add((grupo: grupo, submodulos: suyos));
    }

    if (modulos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Dimen.espacio5),
        child: Text(
          'Ninguna pantalla se llama así.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colores.tintaSuave),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in modulos) ...[
          _BloqueModulo(
            grupo: m.grupo,
            submodulos: m.submodulos,
            matriz: widget,
            // Al buscar se abre todo lo que coincide: si no, habría que abrir
            // cada módulo y cada pantalla para ver el resultado.
            abierto: buscado.isNotEmpty || _abiertos.contains(m.grupo.id),
            detalleAbierto: (s) => buscado.isNotEmpty || _detalles.contains(s),
            onAbrir: () => setState(() {
              if (!_abiertos.remove(m.grupo.id)) _abiertos.add(m.grupo.id);
            }),
            onAbrirDetalle: (s) => setState(() {
              if (!_detalles.remove(s)) _detalles.add(s);
            }),
          ),
          const SizedBox(height: Dimen.espacio2),
        ],
      ],
    );
  }
}

/// Un modulo plegado, con sus pantallas dentro.
class _BloqueModulo extends StatelessWidget {
  const _BloqueModulo({
    required this.grupo,
    required this.submodulos,
    required this.matriz,
    required this.abierto,
    required this.detalleAbierto,
    required this.onAbrir,
    required this.onAbrirDetalle,
  });

  final MenuGrupo grupo;
  final List<SubmoduloCatalogo> submodulos;
  final MatrizPermisos matriz;
  final bool abierto;
  final bool Function(String submodulo) detalleAbierto;
  final VoidCallback onAbrir;
  final ValueChanged<String> onAbrirDetalle;

  bool _tiene(String k) =>
      matriz.marcadas.contains(k) || (matriz.fijas?.containsKey(k) ?? false);

  @override
  Widget build(BuildContext context) {
    final marcadas = matriz.marcadas;
    final visibles = submodulos
        .where((s) => _tiene(clavePermiso(s.submodulo, 'ver')))
        .length;
    final marcadasAqui = submodulos.fold<int>(
      0,
      (n, s) =>
          n +
          s.acciones
              .where((a) => marcadas.contains(clavePermiso(s.submodulo, a)))
              .length,
    );
    final completo = submodulos.every(
      (s) => s.acciones.every(
        (a) => marcadas.contains(clavePermiso(s.submodulo, a)),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onAbrir,
            borderRadius: BorderRadius.circular(Dimen.radioCampo),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimen.espacio3,
                Dimen.espacio2,
                Dimen.espacio2,
                Dimen.espacio2,
              ),
              child: Row(
                children: [
                  Icon(
                    abierto ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colores.tintaSuave,
                  ),
                  const SizedBox(width: Dimen.espacio2),
                  Icon(grupo.icono, size: 17, color: grupo.color),
                  const SizedBox(width: Dimen.espacio2),
                  Expanded(
                    child: Text(
                      grupo.titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colores.tinta,
                      ),
                    ),
                  ),
                  if (matriz.nuevas)
                    if (marcadasAqui > 0)
                      AppEtiqueta(
                        '$marcadasAqui ${marcadasAqui == 1 ? 'nuevo' : 'nuevos'}',
                        tono: EtiquetaTono.exito,
                      )
                    else
                      const SizedBox.shrink()
                  else if (visibles == 0)
                    const AppEtiqueta('sin acceso')
                  else
                    Text(
                      '$visibles de ${submodulos.length}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colores.tintaSuave,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (abierto) ...[
            const Divider(height: 1, color: Colores.linea),
            if (matriz.onMarcarModulo != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      matriz.onMarcarModulo!(submodulos, !completo),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    completo
                        ? 'Quitar todo el módulo'
                        : 'Marcar todo el módulo',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            for (final s in submodulos)
              _FilaPantalla(
                submodulo: s,
                matriz: matriz,
                color: grupo.color,
                abierta: detalleAbierto(s.submodulo),
                onAbrir: () => onAbrirDetalle(s.submodulo),
              ),
            const SizedBox(height: Dimen.espacio2),
          ],
        ],
      ),
    );
  }
}

/// Una pantalla del modulo: se abre para ver sus acciones y qué ve.
class _FilaPantalla extends StatelessWidget {
  const _FilaPantalla({
    required this.submodulo,
    required this.matriz,
    required this.color,
    required this.abierta,
    required this.onAbrir,
  });

  final SubmoduloCatalogo submodulo;
  final MatrizPermisos matriz;
  final Color color;
  final bool abierta;
  final VoidCallback onAbrir;

  String _k(String accion) => clavePermiso(submodulo.submodulo, accion);

  @override
  Widget build(BuildContext context) {
    final sub = submodulo.submodulo;
    final vista = vistaPermiso(sub);
    final marcadas = matriz.marcadas;
    final fijas = matriz.fijas ?? const <String, String>{};

    bool tiene(String a) =>
        marcadas.contains(_k(a)) || fijas.containsKey(_k(a));

    final concedidas = submodulo.acciones.where(tiene).length;
    final nuevas = submodulo.acciones
        .where((a) => marcadas.contains(_k(a)))
        .length;
    final lleno = submodulo.acciones.every((a) => marcadas.contains(_k(a)));

    // Las acciones en el orden fijo de la pantalla, pero solo las que este
    // submodulo admite: las demas no se pintan apagadas porque no estan
    // prohibidas, es que no existen aqui.
    final acciones = [
      for (final a in accionesPermiso.keys)
        if (submodulo.acciones.contains(a)) a,
    ];

    // Por qué ya tiene lo que tiene, agrupado: "Ver, Crear: por su rol".
    final porques = <String, List<String>>{};
    for (final a in acciones) {
      final porque = fijas[_k(a)];
      if (porque != null) (porques[porque] ??= []).add(accionesPermiso[a]!);
    }

    final alcance = matriz.alcance;
    final conAlcance = alcance != null && alcance.pantallas.contains(sub);
    final nivel = conAlcance
        ? alcance.valores[sub] ?? (alcance.heredado != null ? '' : 'todos')
        : null;
    final opciones = conAlcance
        ? opcionesAlcance(sub, heredable: alcance.heredado != null)
        : const <NivelAlcance>[];

    String textoNivel(NivelAlcance n) {
      if (n.valor != '' || alcance?.heredado == null) return n.texto;
      // "Igual que su rol" dice cuál es, para no tener que ir a mirarlo al rol.
      final delRol = alcance!.heredado![sub];
      final valorRol = delRol == null || delRol.isEmpty ? 'todos' : delRol;
      final nombre = [
        for (final o in opcionesAlcance(sub))
          if (o.valor == valorRol) o.texto,
      ].firstOrNull;
      return 'Igual que su rol${nombre == null ? '' : ' ($nombre)'}';
    }

    NivelAlcance? elegido;
    for (final o in opciones) {
      if (o.valor == nivel) elegido = o;
    }

    // Sin Ver no entra a la pantalla: qué filas vería da igual.
    final sinVer = !tiene('ver');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onAbrir,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimen.espacio3,
              vertical: Dimen.espacio2,
            ),
            child: Row(
              children: [
                if (vista.icono != null) ...[
                  Icon(vista.icono, size: 15, color: Colores.tintaSuave),
                  const SizedBox(width: Dimen.espacio2),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vista.titulo,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colores.tinta,
                        ),
                      ),
                      // Lo que ve, sin abrir la fila: es lo segundo que se
                      // viene a mirar después de los botones.
                      if (elegido != null && !sinVer)
                        Text(
                          'Qué ve: ${textoNivel(elegido)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colores.tintaSuave,
                          ),
                        ),
                    ],
                  ),
                ),
                // El resumen evita tener que abrir cada pantalla para saber si
                // tiene algo concedido.
                if (matriz.nuevas && nuevas > 0)
                  AppEtiqueta(
                    '$nuevas ${nuevas == 1 ? 'nuevo' : 'nuevos'}',
                    tono: EtiquetaTono.exito,
                  )
                else if (concedidas == 0)
                  const Text(
                    'sin acceso',
                    style: TextStyle(fontSize: 11, color: Colores.tintaSuave),
                  )
                else
                  AppEtiqueta(
                    '$concedidas de ${submodulo.acciones.length}',
                    tono: EtiquetaTono.modulo,
                    color: color,
                  ),
                Icon(
                  abierta ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colores.tintaSuave,
                ),
              ],
            ),
          ),
        ),

        if (abierta)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimen.espacio3,
              0,
              Dimen.espacio3,
              Dimen.espacio2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Dimen.espacio2,
                  runSpacing: Dimen.espacio1,
                  children: [
                    for (final a in acciones)
                      _ChipAccion(
                        texto: accionesPermiso[a]!,
                        marcada: marcadas.contains(_k(a)),
                        porque: fijas[_k(a)],
                        color: color,
                        onTap: () =>
                            matriz.onAlternar(sub, a, submodulo.acciones),
                      ),
                  ],
                ),
                for (final e in porques.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: Dimen.espacio1),
                    child: Text(
                      '${e.value.join(', ')}: ${e.key.substring(0, 1).toLowerCase()}${e.key.substring(1)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colores.tintaSuave,
                      ),
                    ),
                  ),

                if (conAlcance) ...[
                  const SizedBox(height: Dimen.espacio3),
                  AppSelector<String>(
                    valor: nivel,
                    etiqueta: 'Qué ve',
                    icono: Icons.filter_alt_outlined,
                    habilitado: !alcance.deshabilitado && !sinVer,
                    opciones: [
                      for (final o in opciones) Opcion(o.valor, textoNivel(o)),
                    ],
                    onCambio: (v) {
                      if (v != null) alcance.onCambio(sub, v);
                    },
                  ),
                  const SizedBox(height: Dimen.espacio1),
                  Text(
                    sinVer
                        ? 'Sin Ver no entra a la pantalla: qué ve da igual.'
                        : [
                            queVe(sub),
                            if (elegido != null && elegido.valor != '')
                              elegido.nota,
                          ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colores.tintaSuave,
                    ),
                  ),
                ],

                if (matriz.onMarcarSubmodulo != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => matriz.onMarcarSubmodulo!(
                        sub,
                        submodulo.acciones,
                        !lleno,
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        lleno ? 'Quitar todo' : 'Marcar todo',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1, indent: Dimen.espacio3, color: Colores.linea),
      ],
    );
  }
}

/// Una acción de la pantalla. Lo que ya tiene sale marcado y apagado, con el
/// porqué al mantenerlo apretado.
class _ChipAccion extends StatelessWidget {
  const _ChipAccion({
    required this.texto,
    required this.marcada,
    required this.porque,
    required this.color,
    required this.onTap,
  });

  final String texto;
  final bool marcada;
  final String? porque;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (porque != null) {
      return Tooltip(
        message: porque!,
        child: FilterChip(
          label: Text(texto),
          selected: true,
          onSelected: null,
          showCheckmark: false,
          avatar: const Icon(Icons.check, size: 16, color: Colores.tintaTenue),
          visualDensity: VisualDensity.compact,
          labelStyle: const TextStyle(
            fontSize: 12.5,
            color: Colores.tintaTenue,
          ),
          disabledColor: Colores.fondo,
          side: const BorderSide(color: Colores.linea),
        ),
      );
    }

    return FilterChip(
      label: Text(texto),
      selected: marcada,
      onSelected: (_) => onTap(),
      showCheckmark: true,
      visualDensity: VisualDensity.compact,
      labelStyle: const TextStyle(fontSize: 12.5),
      backgroundColor: Colores.superficie,
      selectedColor: color.withValues(alpha: 0.12),
      checkmarkColor: color,
      side: BorderSide(color: marcada ? color : Colores.linea),
    );
  }
}
