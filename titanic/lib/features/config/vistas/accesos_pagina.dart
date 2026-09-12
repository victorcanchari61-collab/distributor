import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';

/// Como se nombra cada accion en pantalla, y en que orden se lee.
///
/// Es solo la presentacion: que acciones existen de verdad en cada pantalla lo
/// dice el catalogo del backend. Este mapa fija el orden para que la misma
/// accion caiga siempre en el mismo sitio de submodulo a submodulo.
const _acciones = <String, String>{
  'ver': 'Ver',
  'crear': 'Crear',
  'editar': 'Editar',
  'confirmar': 'Confirmar',
  'cobrar': 'Cobrar',
  'anular': 'Anular',
  'eliminar': 'Eliminar',
  'exportar': 'Exportar',
  'importar': 'Importar',
};

String _clave(String submodulo, String accion) => '$submodulo:$accion';

/// Nombre de la pantalla en el menu. Hay submodulos que el menu del telefono no
/// muestra (series, parametros) y ahi se cae a la clave: siguen siendo
/// configurables aunque no tengan vista propia.
({String titulo, IconData? icono}) _vista(String submodulo) {
  for (final grupo in menuGrupos) {
    for (final item in grupo.items) {
      if (item.id == submodulo) return (titulo: item.titulo, icono: item.icono);
    }
  }
  return (titulo: submodulo, icono: null);
}

/// Quien puede hacer que, por pantalla y accion.
///
/// Un permiso es una accion sobre un submodulo y la fila existe o no existe:
/// nada de banderas por modulo. Las acciones de cada pantalla salen del
/// catalogo del backend, no de una lista escrita aqui — si estuviera
/// duplicada, un submodulo nuevo quedaria invisible en esta pantalla aunque el
/// servidor ya lo estuviera exigiendo.
///
/// En el telefono no cabe la tabla del panel web (41 pantallas x 9 acciones),
/// asi que se recorre en dos niveles: un bloque plegable por modulo y, dentro,
/// una fila por pantalla que se abre para mostrar sus acciones. Solo hay
/// abierto lo que se esta tocando, y cada casilla lleva su texto completo en
/// vez de depender de una cabecera de columna que quedaria fuera de la vista.
class AccesosPagina extends ConsumerStatefulWidget {
  const AccesosPagina({super.key});

  static const ruta = '/config/accesos';

  @override
  ConsumerState<AccesosPagina> createState() => _AccesosPaginaState();
}

class _AccesosPaginaState extends ConsumerState<AccesosPagina> {
  int? _rolId;

  /// El rol cuya matriz esta cargada en [_marcas]. Los roles llegan del API
  /// despues del primer build, asi que la siembra no puede ir en initState.
  int? _rolCargado;

  /// Lo concedido, como claves "submodulo:accion" — igual que lo guarda el
  /// backend.
  Set<String> _marcas = {};

  /// Modulos desplegados. Varios a la vez: comparar dos modulos es justo lo
  /// que se viene a hacer aqui.
  final Set<String> _abiertos = {};

  /// Pantallas desplegadas, por clave de submodulo.
  final Set<String> _detalles = {};

  bool _sucio = false;
  bool _guardando = false;
  String? _error;

  Set<String> _marcasDe(Rol rol) => {for (final p in rol.permisos) p.clave};

  void _cambiarRol(int id) {
    setState(() {
      _rolId = id;
      _rolCargado = null;
      _detalles.clear();
    });
  }

  void _alternar(String submodulo, String accion, List<String> acciones) {
    setState(() {
      _sucio = true;
      final puesta = _marcas.contains(_clave(submodulo, accion));

      if (accion == 'ver') {
        // Quitar Ver retira la pantalla entera: sin ella el resto de permisos
        // quedarian concedidos pero inalcanzables.
        if (puesta) {
          _marcas.removeAll([for (final a in acciones) _clave(submodulo, a)]);
        } else {
          _marcas.add(_clave(submodulo, 'ver'));
        }
        return;
      }

      if (puesta) {
        _marcas.remove(_clave(submodulo, accion));
      } else {
        _marcas.add(_clave(submodulo, accion));
        // Cualquier accion implica poder entrar a la pantalla.
        _marcas.add(_clave(submodulo, 'ver'));
      }
    });
  }

  void _marcarSubmodulo(String submodulo, List<String> acciones, bool marcar) {
    setState(() {
      _sucio = true;
      final claves = [for (final a in acciones) _clave(submodulo, a)];
      if (marcar) {
        _marcas.addAll(claves);
      } else {
        _marcas.removeAll(claves);
      }
    });
  }

  void _marcarModulo(List<SubmoduloCatalogo> submodulos, bool marcar) {
    setState(() {
      _sucio = true;
      for (final s in submodulos) {
        final claves = [for (final a in s.acciones) _clave(s.submodulo, a)];
        if (marcar) {
          _marcas.addAll(claves);
        } else {
          _marcas.removeAll(claves);
        }
      }
    });
  }

  Future<void> _guardar(Rol rol) async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(rolesProvider.notifier).guardarPermisos(rol.id, [
        for (final clave in _marcas)
          RolPermiso(
            submodulo: clave.substring(0, clave.lastIndexOf(':')),
            accion: clave.substring(clave.lastIndexOf(':') + 1),
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _sucio = false;
        // La matriz se vuelve a sembrar con lo que respondio el backend.
        _rolCargado = null;
      });
      mensajero.showSnackBar(
        SnackBar(content: Text('Accesos de ${rol.nombre} guardados')),
      );
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        resolverRuta(AccesosPagina.ruta).grupo?.color ?? Colores.marca;
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <Rol>[];
    final catalogo = ref.watch(catalogoPermisosProvider);

    Rol? rol;
    for (final r in roles) {
      if (r.id == _rolId) rol = r;
    }
    rol ??= roles.isEmpty ? null : roles.first;

    if (rol != null && _rolCargado != rol.id) {
      _rolCargado = rol.id;
      _rolId = rol.id;
      _marcas = _marcasDe(rol);
      _sucio = false;
    }

    return AppShell(
      titulo: 'Accesos',
      subtitulo: resolverRuta(AccesosPagina.ruta).grupo?.titulo,
      acentado: color,
      rutaActual: AccesosPagina.ruta,
      child: switch ((rol, catalogo)) {
        (null, _) => const Center(child: CircularProgressIndicator()),
        (_, AsyncError(:final error)) => Padding(
          padding: const EdgeInsets.all(Dimen.espacio4),
          child: AppAlerta(
            error is ApiExcepcion
                ? error.texto
                : 'No pudimos cargar el catálogo de permisos.',
          ),
        ),
        (final Rol elegido, AsyncData(:final value)) => _cuerpo(
          elegido,
          value,
          color,
          roles,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _cuerpo(
    Rol rol,
    List<SubmoduloCatalogo> catalogo,
    Color color,
    List<Rol> roles,
  ) {
    // Los modulos en el orden del menu, y solo los que el catalogo declara.
    final modulos = <({MenuGrupo grupo, List<SubmoduloCatalogo> submodulos})>[];
    for (final grupo in menuGrupos) {
      final suyos = [
        for (final s in catalogo)
          if (s.modulo == grupo.id) s,
      ];
      if (suyos.isNotEmpty) modulos.add((grupo: grupo, submodulos: suyos));
    }

    final habilitadas = catalogo
        .where((s) => _marcas.contains(_clave(s.submodulo, 'ver')))
        .length;

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
            itemCount: roles.length,
            separatorBuilder: (context, i) =>
                const SizedBox(width: Dimen.espacio2),
            itemBuilder: (context, i) {
              final r = roles[i];
              final activo = r.id == rol.id;
              return ChoiceChip(
                label: Text(r.nombre),
                selected: activo,
                onSelected: (_) => _cambiarRol(r.id),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: activo ? color : Colores.tintaSuave,
                ),
                backgroundColor: Colores.superficie,
                selectedColor: color.withValues(alpha: 0.12),
                side: BorderSide(color: activo ? color : Colores.linea),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Dimen.espacio4,
              Dimen.espacio3,
              Dimen.espacio4,
              Dimen.espacio4,
            ),
            children: [
              if (_error != null) ...[
                AppAlerta(_error!),
                const SizedBox(height: Dimen.espacio3),
              ],

              if (rol.protegido) ...[
                const AppAlerta(
                  'El rol Administrador tiene todo concedido siempre: sin él '
                  'nadie podría volver a configurar el sistema. Lo que marques '
                  'aquí no le quita nada.',
                  tono: AlertaTono.aviso,
                ),
                const SizedBox(height: Dimen.espacio3),
              ],

              Text(
                '$habilitadas de ${catalogo.length} pantallas habilitadas',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colores.tintaSuave,
                ),
              ),
              const SizedBox(height: Dimen.espacio3),

              for (final m in modulos) ...[
                _BloqueModulo(
                  grupo: m.grupo,
                  submodulos: m.submodulos,
                  marcas: _marcas,
                  abierto: _abiertos.contains(m.grupo.id),
                  detalles: _detalles,
                  onAbrir: () => setState(() {
                    if (!_abiertos.remove(m.grupo.id)) {
                      _abiertos.add(m.grupo.id);
                    }
                  }),
                  onAbrirDetalle: (submodulo) => setState(() {
                    if (!_detalles.remove(submodulo)) _detalles.add(submodulo);
                  }),
                  onMarcarModulo: (marcar) =>
                      _marcarModulo(m.submodulos, marcar),
                  onMarcarSubmodulo: _marcarSubmodulo,
                  onAlternar: _alternar,
                ),
                const SizedBox(height: Dimen.espacio2),
              ],

              const SizedBox(height: Dimen.espacio1),
              const Text(
                'Quitar Ver retira la pantalla por completo. Conceder cualquier '
                'otra acción activa Ver automáticamente. Cada pantalla ofrece '
                'solo las acciones que admite: el kardex no se anula, la '
                'auditoría no se crea.',
                style: TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Dimen.espacio4),
          child: Row(
            children: [
              Expanded(
                child: AppBoton(
                  texto: 'Restablecer',
                  variante: BotonVariante.secundario,
                  onPressed: !_sucio || _guardando
                      ? null
                      : () => setState(() {
                          _marcas = _marcasDe(rol);
                          _sucio = false;
                        }),
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              Expanded(
                child: AppBoton(
                  texto: 'Guardar',
                  cargando: _guardando,
                  onPressed: !_sucio ? null : () => _guardar(rol),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un modulo plegado, con sus pantallas dentro.
class _BloqueModulo extends StatelessWidget {
  const _BloqueModulo({
    required this.grupo,
    required this.submodulos,
    required this.marcas,
    required this.abierto,
    required this.detalles,
    required this.onAbrir,
    required this.onAbrirDetalle,
    required this.onMarcarModulo,
    required this.onMarcarSubmodulo,
    required this.onAlternar,
  });

  final MenuGrupo grupo;
  final List<SubmoduloCatalogo> submodulos;
  final Set<String> marcas;
  final bool abierto;
  final Set<String> detalles;
  final VoidCallback onAbrir;
  final ValueChanged<String> onAbrirDetalle;
  final ValueChanged<bool> onMarcarModulo;
  final void Function(String submodulo, List<String> acciones, bool marcar)
  onMarcarSubmodulo;
  final void Function(String submodulo, String accion, List<String> acciones)
  onAlternar;

  @override
  Widget build(BuildContext context) {
    final visibles = submodulos
        .where((s) => marcas.contains(_clave(s.submodulo, 'ver')))
        .length;
    final completo = submodulos.every(
      (s) => s.acciones.every((a) => marcas.contains(_clave(s.submodulo, a))),
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
                  if (visibles == 0)
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onMarcarModulo(!completo),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  completo ? 'Quitar todo el módulo' : 'Marcar todo el módulo',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            for (final s in submodulos)
              _FilaPantalla(
                submodulo: s,
                marcas: marcas,
                color: grupo.color,
                abierta: detalles.contains(s.submodulo),
                onAbrir: () => onAbrirDetalle(s.submodulo),
                onMarcar: (marcar) =>
                    onMarcarSubmodulo(s.submodulo, s.acciones, marcar),
                onAlternar: (accion) =>
                    onAlternar(s.submodulo, accion, s.acciones),
              ),
            const SizedBox(height: Dimen.espacio2),
          ],
        ],
      ),
    );
  }
}

/// Una pantalla del modulo: se abre para ver sus acciones.
class _FilaPantalla extends StatelessWidget {
  const _FilaPantalla({
    required this.submodulo,
    required this.marcas,
    required this.color,
    required this.abierta,
    required this.onAbrir,
    required this.onMarcar,
    required this.onAlternar,
  });

  final SubmoduloCatalogo submodulo;
  final Set<String> marcas;
  final Color color;
  final bool abierta;
  final VoidCallback onAbrir;
  final ValueChanged<bool> onMarcar;
  final ValueChanged<String> onAlternar;

  @override
  Widget build(BuildContext context) {
    final vista = _vista(submodulo.submodulo);
    final concedidas = submodulo.acciones
        .where((a) => marcas.contains(_clave(submodulo.submodulo, a)))
        .toList();
    final lleno = concedidas.length == submodulo.acciones.length;

    // Las acciones en el orden fijo de la pantalla, pero solo las que este
    // submodulo admite: las demas no se pintan apagadas porque no estan
    // prohibidas, es que no existen aqui.
    final acciones = [
      for (final a in _acciones.keys)
        if (submodulo.acciones.contains(a)) a,
    ];

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
                  child: Text(
                    vista.titulo,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colores.tinta,
                    ),
                  ),
                ),
                // El resumen evita tener que abrir cada pantalla para saber si
                // tiene algo concedido.
                if (concedidas.isEmpty)
                  const Text(
                    'sin acceso',
                    style: TextStyle(fontSize: 11, color: Colores.tintaSuave),
                  )
                else
                  AppEtiqueta(
                    '${concedidas.length} de ${submodulo.acciones.length}',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Dimen.espacio2,
                  runSpacing: Dimen.espacio1,
                  children: [
                    for (final a in acciones)
                      FilterChip(
                        label: Text(_acciones[a]!),
                        selected: marcas.contains(
                          _clave(submodulo.submodulo, a),
                        ),
                        onSelected: (_) => onAlternar(a),
                        showCheckmark: true,
                        visualDensity: VisualDensity.compact,
                        labelStyle: const TextStyle(fontSize: 12.5),
                        backgroundColor: Colores.superficie,
                        selectedColor: color.withValues(alpha: 0.12),
                        checkmarkColor: color,
                        side: BorderSide(color: Colores.linea),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => onMarcar(!lleno),
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
