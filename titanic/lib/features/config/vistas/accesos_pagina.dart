import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_pestanas.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';
import 'excepciones_tab.dart';
import 'matriz_permisos.dart';
import 'solicitudes_tab.dart';
import '../../../compartido/widgets/app_aviso.dart';

/// Quien puede hacer que, por pantalla y accion.
///
/// Un permiso es una accion sobre un submodulo y la fila existe o no existe:
/// nada de banderas por modulo. Las acciones de cada pantalla salen del
/// catalogo del backend, no de una lista escrita aqui — si estuviera
/// duplicada, un submodulo nuevo quedaria invisible en esta pantalla aunque el
/// servidor ya lo estuviera exigiendo.
///
/// La matriz es [MatrizPermisos], la misma de "Por persona": un bloque
/// plegable por modulo y, dentro, una fila por pantalla con sus acciones y,
/// en las que lo admiten, "Qué ve" (todos, solo sus rutas, solo lo suyo). Todo
/// se guarda con el mismo Guardar.
class AccesosPagina extends ConsumerStatefulWidget {
  const AccesosPagina({super.key});

  static const ruta = '/config/accesos';

  @override
  ConsumerState<AccesosPagina> createState() => _AccesosPaginaState();
}

class _AccesosPaginaState extends ConsumerState<AccesosPagina>
    with SingleTickerProviderStateMixin {
  /*
   * Tres pestañas porque son tres preguntas distintas.
   *
   * "Qué hace este rol" se configura una vez y vale para todos; "qué le falta
   * a esta persona" se resuelve caso por caso; y la bandeja es lo que otros
   * están esperando. Todo junto en una sola pantalla obligaba a pasar por la
   * matriz entera —41 pantallas— para soltar un permiso puntual, y la bandeja
   * ni siquiera existía aquí: había que ir a una computadora a aprobar.
   */
  late final _tabs = TabController(length: 3, vsync: this);

  int? _rolId;

  /// El rol cuya matriz esta cargada en [_marcas]. Los roles llegan del API
  /// despues del primer build, asi que la siembra no puede ir en initState.
  int? _rolCargado;

  /// Lo concedido, como claves "submodulo:accion" — igual que lo guarda el
  /// backend.
  Set<String> _marcas = {};

  /// Qué filas ve el rol en cada pantalla que lo admite. Sin fila = todos: el
  /// backend no guarda lo que no limita.
  Map<String, String> _alcances = {};

  /// Lo guardado, para Restablecer y para no reenviarlo si no cambió.
  Map<String, String> _alcancesBase = {};

  bool _sucio = false;
  bool _guardando = false;
  String? _error;

  Set<String> _marcasDe(Rol rol) => {for (final p in rol.permisos) p.clave};

  void _cambiarRol(int id) {
    setState(() {
      _rolId = id;
      _rolCargado = null;
    });
  }

  /// Los alcances viven aparte de la matriz: se leen al elegir el rol. Si no
  /// llegan, se queda en "todos", que es lo que no restringe nada.
  Future<void> _cargarAlcances(int rolId) async {
    Map<String, String> leidos;
    try {
      leidos = await ref.read(configApiProvider).alcancesDeRol(rolId);
    } catch (_) {
      leidos = {};
    }
    // Una respuesta que llega tarde, de un rol que ya no se mira, no pisa nada.
    if (!mounted || _rolCargado != rolId) return;
    setState(() {
      _alcances = Map.of(leidos);
      _alcancesBase = leidos;
    });
  }

  void _cambiarAlcance(String submodulo, String nivel) {
    setState(() {
      _sucio = true;
      _alcances = {..._alcances, submodulo: nivel};
    });
  }

  /// Solo lo que limita algo: "todos" es no restringir y el backend ni lo
  /// guarda.
  static Map<String, String> _restringidos(Map<String, String> alcances) => {
    for (final e in alcances.entries)
      if (e.value.isNotEmpty && e.value != 'todos') e.key: e.value,
  };

  static bool _iguales(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  void _alternar(String submodulo, String accion, List<String> acciones) {
    setState(() {
      _sucio = true;
      final puesta = _marcas.contains(clavePermiso(submodulo, accion));

      if (accion == 'ver') {
        // Quitar Ver retira la pantalla entera: sin ella el resto de permisos
        // quedarian concedidos pero inalcanzables.
        if (puesta) {
          _marcas.removeAll([
            for (final a in acciones) clavePermiso(submodulo, a),
          ]);
        } else {
          _marcas.add(clavePermiso(submodulo, 'ver'));
        }
        return;
      }

      if (puesta) {
        _marcas.remove(clavePermiso(submodulo, accion));
      } else {
        _marcas.add(clavePermiso(submodulo, accion));
        // Cualquier accion implica poder entrar a la pantalla.
        _marcas.add(clavePermiso(submodulo, 'ver'));
      }
    });
  }

  void _marcarSubmodulo(String submodulo, List<String> acciones, bool marcar) {
    setState(() {
      _sucio = true;
      final claves = [for (final a in acciones) clavePermiso(submodulo, a)];
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
        final claves = [
          for (final a in s.acciones) clavePermiso(s.submodulo, a),
        ];
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

    final mensajero = Aviso.de(context);
    try {
      await ref.read(rolesProvider.notifier).guardarPermisos(rol.id, [
        for (final clave in _marcas)
          RolPermiso(
            submodulo: clave.substring(0, clave.lastIndexOf(':')),
            accion: clave.substring(clave.lastIndexOf(':') + 1),
          ),
      ]);
      final restringidos = _restringidos(_alcances);
      if (!_iguales(restringidos, _restringidos(_alcancesBase))) {
        await ref
            .read(configApiProvider)
            .guardarAlcancesRol(rol.id, restringidos);
      }
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _sucio = false;
        // La matriz se vuelve a sembrar con lo que respondio el backend.
        _rolCargado = null;
      });
      mensajero.mostrar('Accesos de ${rol.nombre} guardados');
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
      _alcances = {};
      _alcancesBase = {};
      final id = rol.id;
      Future.microtask(() => _cargarAlcances(id));
    }
    final pantallasAlcance =
        ref.watch(pantallasAlcanceProvider).valueOrNull ?? const <String>[];

    // Cuántas esperan respuesta, para el número de la pestaña: sin él, quien
    // no entra a la bandeja no se entera de que alguien está esperando.
    final pendientes = (ref.watch(solicitudesProvider).valueOrNull ?? const [])
        .where((s) => s.pendiente)
        .length;

    return AppShell(
      titulo: 'Accesos',
      subtitulo: resolverRuta(AccesosPagina.ruta).grupo?.titulo,
      acentado: color,
      rutaActual: AccesosPagina.ruta,
      child: Column(
        children: [
          // Las mismas pestañas del resto de la app: en el rectángulo gris, la
          // activa con el color del módulo. Se deslizan de lado si no caben.
          PestanasHoja(
            controlador: _tabs,
            pestanas: [
              const Pestana(0, 'Por rol'),
              const Pestana(1, 'Por persona'),
              Pestana(
                2,
                'Solicitudes',
                contador: pendientes > 0 ? pendientes : null,
              ),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                switch ((rol, catalogo)) {
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
                    pantallasAlcance,
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
                const ExcepcionesTab(),
                const SolicitudesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo(
    Rol rol,
    List<SubmoduloCatalogo> catalogo,
    Color color,
    List<Rol> roles,
    List<String> pantallasAlcance,
  ) {
    final habilitadas = catalogo
        .where((s) => _marcas.contains(clavePermiso(s.submodulo, 'ver')))
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

              MatrizPermisos(
                catalogo: catalogo,
                marcadas: _marcas,
                onAlternar: _alternar,
                onMarcarSubmodulo: _marcarSubmodulo,
                onMarcarModulo: _marcarModulo,
                // Qué FILAS ve, no qué botones tiene: el permiso dice si entra
                // a Pedidos; esto dice de qué clientes. "Solo mis rutas" limita
                // a los clientes de las rutas que la persona tiene a cargo (se
                // asigna en Usuarios); sin ruta no ve ninguno.
                alcance: AlcanceEnMatriz(
                  pantallas: pantallasAlcance,
                  valores: _alcances,
                  onCambio: _cambiarAlcance,
                  // El Administrador ve siempre todo.
                  deshabilitado: rol.protegido,
                ),
              ),

              const SizedBox(height: Dimen.espacio1),
              const Text(
                'Quitar Ver retira la pantalla por completo. Conceder cualquier '
                'otra acción activa Ver automáticamente. Cada pantalla ofrece '
                'solo las acciones que admite: el kardex no se anula, la '
                'auditoría no se crea. Qué ve dice de qué clientes y ventas: '
                'todos, solo los de sus rutas o solo lo que registró.',
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
                          _alcances = Map.of(_alcancesBase);
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
