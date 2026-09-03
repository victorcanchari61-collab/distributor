import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_shell.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../estado/config_controlador.dart';

/// Matriz de accesos: que puede ver, crear, editar y eliminar cada rol, modulo
/// por modulo. Desmarcar Ver limpia toda la fila; marcar Crear, Editar o
/// Eliminar fuerza Ver, porque no tiene sentido crear algo que no se puede ver.
class AccesosPagina extends ConsumerStatefulWidget {
  const AccesosPagina({super.key});

  static const ruta = '/config/accesos';

  @override
  ConsumerState<AccesosPagina> createState() => _AccesosPaginaState();
}

class _AccesosPaginaState extends ConsumerState<AccesosPagina> {
  int? _rolId;
  List<RolPermiso>? _permisos;
  bool _guardando = false;
  String? _error;

  List<RolPermiso> _matrizDesde(Rol rol) {
    return [
      for (final grupo in menuGrupos)
        _buscar(rol.permisos, grupo.id) ?? RolPermiso(modulo: grupo.id, ver: false, crear: false, editar: false, eliminar: false),
    ];
  }

  RolPermiso? _buscar(List<RolPermiso> permisos, String modulo) {
    for (final p in permisos) {
      if (p.modulo == modulo) return p;
    }
    return null;
  }

  bool _difiereDe(Rol rol) {
    final permisos = _permisos;
    if (permisos == null) return false;
    for (final grupo in menuGrupos) {
      final actual = _buscar(permisos, grupo.id);
      final original = _buscar(rol.permisos, grupo.id) ??
          RolPermiso(modulo: grupo.id, ver: false, crear: false, editar: false, eliminar: false);
      if (actual == null) continue;
      if (actual.ver != original.ver ||
          actual.crear != original.crear ||
          actual.editar != original.editar ||
          actual.eliminar != original.eliminar) {
        return true;
      }
    }
    return false;
  }

  void _toggle(String modulo, {bool? ver, bool? crear, bool? editar, bool? eliminar}) {
    setState(() {
      _permisos = [
        for (final p in _permisos!)
          if (p.modulo == modulo)
            _aplicarToggle(p, ver: ver, crear: crear, editar: editar, eliminar: eliminar)
          else
            p,
      ];
    });
  }

  RolPermiso _aplicarToggle(
    RolPermiso p, {
    bool? ver,
    bool? crear,
    bool? editar,
    bool? eliminar,
  }) {
    if (ver == false) {
      // Sin ver, ninguno de los demas tiene sentido.
      return p.copiar(ver: false, crear: false, editar: false, eliminar: false);
    }
    final nuevoCrear = crear ?? p.crear;
    final nuevoEditar = editar ?? p.editar;
    final nuevoEliminar = eliminar ?? p.eliminar;
    // Crear, editar o eliminar sin ver no tiene sentido: lo fuerza.
    final forzarVer = nuevoCrear || nuevoEditar || nuevoEliminar;
    return p.copiar(
      ver: ver ?? (forzarVer ? true : p.ver),
      crear: nuevoCrear,
      editar: nuevoEditar,
      eliminar: nuevoEliminar,
    );
  }

  void _marcarTodo(String modulo, bool marcar) {
    setState(() {
      _permisos = [
        for (final p in _permisos!)
          if (p.modulo == modulo)
            p.copiar(ver: marcar, crear: marcar, editar: marcar, eliminar: marcar)
          else
            p,
      ];
    });
  }

  Future<void> _guardar(Rol rol) async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(rolesProvider.notifier).guardarPermisos(rol.id, _permisos!);
      if (mounted) setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text('Accesos de ${rol.nombre} guardados')));
    } on ApiExcepcion catch (e) {
      setState(() {
        _guardando = false;
        _error = e.texto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = resolverRuta(AccesosPagina.ruta).grupo?.color ?? Colores.marca;
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <Rol>[];

    if (roles.isNotEmpty && (_rolId == null || !roles.any((r) => r.id == _rolId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _rolId = roles.first.id;
          _permisos = _matrizDesde(roles.first);
        });
      });
    }

    Rol? rol;
    for (final r in roles) {
      if (r.id == _rolId) rol = r;
    }

    final dirty = rol != null && _difiereDe(rol);

    return AppShell(
      titulo: 'Accesos',
      subtitulo: resolverRuta(AccesosPagina.ruta).grupo?.titulo,
      acentado: color,
      rutaActual: AccesosPagina.ruta,
      child: roles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(Dimen.espacio4),
                    itemCount: roles.length,
                    separatorBuilder: (context, i) => const SizedBox(width: Dimen.espacio2),
                    itemBuilder: (context, i) {
                      final r = roles[i];
                      final activo = r.id == _rolId;
                      return ChoiceChip(
                        label: Text(r.nombre),
                        selected: activo,
                        onSelected: (_) => setState(() {
                          _rolId = r.id;
                          _permisos = _matrizDesde(r);
                        }),
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
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimen.espacio4),
                    child: AppAlerta(_error!),
                  ),
                Expanded(
                  child: rol == null || _permisos == null
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            Dimen.espacio4,
                            Dimen.espacio2,
                            Dimen.espacio4,
                            Dimen.espacio4,
                          ),
                          itemCount: menuGrupos.length,
                          separatorBuilder: (context, i) => const SizedBox(height: Dimen.espacio2),
                          itemBuilder: (context, i) {
                            final grupo = menuGrupos[i];
                            final permiso = _buscar(_permisos!, grupo.id)!;
                            return _FilaPermiso(
                              titulo: grupo.titulo,
                              icono: grupo.icono,
                              color: grupo.color,
                              permiso: permiso,
                              onToggle: (ver, crear, editar, eliminar) => _toggle(
                                grupo.id,
                                ver: ver,
                                crear: crear,
                                editar: editar,
                                eliminar: eliminar,
                              ),
                              onMarcarTodo: (marcar) => _marcarTodo(grupo.id, marcar),
                            );
                          },
                        ),
                ),
                if (rol != null)
                  Padding(
                    padding: const EdgeInsets.all(Dimen.espacio4),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppBoton(
                            texto: 'Restablecer',
                            variante: BotonVariante.secundario,
                            onPressed: !dirty || _guardando
                                ? null
                                : () => setState(() => _permisos = _matrizDesde(rol!)),
                          ),
                        ),
                        const SizedBox(width: Dimen.espacio3),
                        Expanded(
                          child: AppBoton(
                            texto: 'Guardar',
                            cargando: _guardando,
                            onPressed: !dirty ? null : () => _guardar(rol!),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _FilaPermiso extends StatelessWidget {
  const _FilaPermiso({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.permiso,
    required this.onToggle,
    required this.onMarcarTodo,
  });

  final String titulo;
  final IconData icono;
  final Color color;
  final RolPermiso permiso;
  final void Function(bool? ver, bool? crear, bool? editar, bool? eliminar) onToggle;
  final ValueChanged<bool> onMarcarTodo;

  bool get _todoMarcado => permiso.ver && permiso.crear && permiso.editar && permiso.eliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimen.espacio3),
      decoration: BoxDecoration(
        color: Colores.superficie,
        border: Border.all(color: Colores.linea),
        borderRadius: BorderRadius.circular(Dimen.radioCampo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 17, color: color),
              const SizedBox(width: Dimen.espacio2),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colores.tinta),
                ),
              ),
              TextButton(
                onPressed: () => onMarcarTodo(!_todoMarcado),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(
                  _todoMarcado ? 'Quitar todo' : 'Marcar todo',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: Dimen.espacio1,
            children: [
              _Casilla(etiqueta: 'Ver', valor: permiso.ver, onCambio: (v) => onToggle(v, null, null, null)),
              _Casilla(
                etiqueta: 'Crear',
                valor: permiso.crear,
                onCambio: (v) => onToggle(null, v, null, null),
              ),
              _Casilla(
                etiqueta: 'Editar',
                valor: permiso.editar,
                onCambio: (v) => onToggle(null, null, v, null),
              ),
              _Casilla(
                etiqueta: 'Eliminar',
                valor: permiso.eliminar,
                onCambio: (v) => onToggle(null, null, null, v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.etiqueta, required this.valor, required this.onCambio});

  final String etiqueta;
  final bool valor;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: CheckboxListTile(
        value: valor,
        onChanged: (v) => onCambio(v ?? false),
        title: Text(etiqueta, style: const TextStyle(fontSize: 12.5)),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
