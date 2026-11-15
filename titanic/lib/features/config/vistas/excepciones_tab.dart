import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/widgets/app_alerta.dart';
import '../../../compartido/widgets/app_aviso.dart';
import '../../../compartido/widgets/app_boton.dart';
import '../../../compartido/widgets/app_botones_formulario.dart';
import '../../../compartido/widgets/app_campo.dart';
import '../../../compartido/widgets/app_confirmacion.dart';
import '../../../compartido/widgets/app_etiqueta.dart';
import '../../../compartido/widgets/app_hoja.dart';
import '../../../compartido/widgets/app_selector.dart';
import '../../../compartido/widgets/app_vacio.dart';
import '../../../core/navegacion/menu.dart';
import '../../../core/red/excepciones.dart';
import '../../../core/tema/colores.dart';
import '../../../core/tema/dimensiones.dart';
import '../datos/config_modelos.dart';
import '../datos/permiso_modelos.dart';
import '../estado/config_controlador.dart';
import 'matriz_permisos.dart';

const _acciones = {
  'ver': 'Entrar',
  'crear': 'Crear',
  'editar': 'Editar',
  'anular': 'Anular',
  'eliminar': 'Eliminar',
  'exportar': 'Exportar',
  'importar': 'Importar',
  'confirmar': 'Confirmar',
  'cobrar': 'Cobrar',
  'ingreso': 'Ingreso',
  'egreso': 'Egreso',
  'transferir': 'Mover plata',
};

/// Permisos que tiene una persona y su rol no le da.
///
/// El rol resuelve el caso general —todos los vendedores hacen lo mismo— pero
/// no el particular: uno concreto tiene que corregir hoy un pedido suyo. Sin
/// esto la única salida era subirlo de rol, que le daba de golpe todo lo que
/// ese rol puede hacer y ya no se lo quitaba nadie.
///
/// Aquí se consulta, se retira y se da: "Dar permisos" abre la misma matriz de
/// los roles, con lo que ya tiene marcado en gris, y ahí mismo se cambia qué
/// clientes y ventas ve. Lo que la persona pidió se aprueba en la pestaña de
/// al lado.
class ExcepcionesTab extends ConsumerWidget {
  const ExcepcionesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarios =
        ref.watch(usuariosProvider).valueOrNull ?? const <Usuario>[];
    final elegido = ref.watch(usuarioExcepcionesProvider);
    Usuario? usuario;
    for (final u in usuarios) {
      if (u.id == elegido) usuario = u;
    }

    // El primero de la lista mientras nadie elija: una pantalla que arranca
    // vacía parece rota, y aquí siempre hay a quién mirar.
    if (elegido == null && usuarios.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(usuarioExcepcionesProvider) == null) {
          ref.read(usuarioExcepcionesProvider.notifier).state =
              usuarios.first.id;
        }
      });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            Dimen.espacio3,
            Dimen.espacio4,
            0,
          ),
          child: AppSelector<int>(
            valor: elegido,
            etiqueta: 'Persona',
            icono: Icons.person_outline,
            opciones: [
              for (final u in usuarios) Opcion(u.id, '${u.nombre} · ${u.rol}'),
            ],
            onCambio: (v) =>
                ref.read(usuarioExcepcionesProvider.notifier).state = v,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimen.espacio4,
            Dimen.espacio2,
            Dimen.espacio4,
            0,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Lo que se da aquí se suma a lo del rol, nunca lo quita. '
                  'Qué clientes y ventas ve también se cambia ahí.',
                  style: TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
                ),
              ),
              const SizedBox(width: Dimen.espacio3),
              AppBoton(
                texto: 'Dar permisos',
                icono: Icons.add,
                tam: BotonTam.sm,
                expandido: false,
                onPressed: usuario == null
                    ? null
                    : () => abrirHoja<void>(
                        context,
                        (_) => _HojaDarPermisos(usuario: usuario!),
                      ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ref
              .watch(excepcionesProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(Dimen.espacio4),
                  child: AppAlerta(
                    e is ApiExcepcion
                        ? e.texto
                        : 'No pudimos cargar los permisos.',
                  ),
                ),
                data: (permisos) => permisos.isEmpty
                    ? const AppVacio(
                        icono: Icons.key_off_outlined,
                        titulo: 'Sin permisos sueltos',
                        detalle:
                            'Esta persona solo puede lo que le da su rol. Lo que '
                            'pida y se le apruebe aparecerá aquí.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(Dimen.espacio4),
                        itemCount: permisos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Dimen.espacio3),
                        itemBuilder: (context, i) =>
                            _Tarjeta(permiso: permisos[i]),
                      ),
              ),
        ),
      ],
    );
  }
}

class _Tarjeta extends ConsumerWidget {
  const _Tarjeta({required this.permiso});

  final UsuarioPermiso permiso;

  Future<void> _revocar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Retirar el permiso',
      mensaje:
          'Dejará de poder ${(_acciones[permiso.accion] ?? permiso.accion).toLowerCase()} '
          'en ${vistaPorId(permiso.submodulo)?.titulo ?? permiso.submodulo}.',
      textoConfirmar: 'Retirar',
      tono: ConfirmTono.peligro,
    );
    if (!ok || !context.mounted) return;

    final mensajero = Aviso.de(context);
    try {
      await ref.read(configApiProvider).revocarPermiso(permiso.id);
      ref.invalidate(excepcionesProvider);
      mensajero.mostrar('Permiso retirado');
    } on ApiExcepcion catch (e) {
      mensajero.error(e.texto);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantalla = vistaPorId(permiso.submodulo)?.titulo ?? permiso.submodulo;

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
              Expanded(
                child: Text(
                  '${_acciones[permiso.accion] ?? permiso.accion} en $pantalla',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colores.tinta,
                  ),
                ),
              ),

              // Lo gastado o vencido se queda a la vista: es el historial de
              // lo que se concedió, y borrarlo esconde a quién se le dio qué.
              AppEtiqueta(
                permiso.vigente ? 'Vigente' : 'Terminado',
                tono: permiso.vigente
                    ? EtiquetaTono.exito
                    : EtiquetaTono.neutral,
              ),
            ],
          ),
          const SizedBox(height: 2),

          Text(
            _detalle,
            style: const TextStyle(fontSize: 12.5, color: Colores.tintaSuave),
          ),

          if (permiso.motivo != null && permiso.motivo!.trim().isNotEmpty) ...[
            const SizedBox(height: Dimen.espacio2),
            Text(
              permiso.motivo!,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colores.tintaSuave,
              ),
            ),
          ],

          if (permiso.vigente) ...[
            const SizedBox(height: Dimen.espacio2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _revocar(context, ref),
                icon: const Icon(Icons.block, size: 16, color: Colores.peligro),
                label: const Text(
                  'Retirar',
                  style: TextStyle(fontSize: 13, color: Colores.peligro),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Hasta cuándo vale, dicho como se entiende y no como se guarda.
  String get _detalle {
    if (permiso.revocado) return 'Retirado a mano';

    return switch (permiso.alcance) {
      Alcance.unaVez =>
        permiso.usos > 0
            ? 'De una sola vez · ya se usó'
            : 'De una sola vez · sin usar',
      Alcance.temporal =>
        permiso.expiraEn == null
            ? 'Por un tiempo'
            : 'Vence el ${permiso.expiraEn!.day.toString().padLeft(2, '0')}/'
                  '${permiso.expiraEn!.month.toString().padLeft(2, '0')}/'
                  '${permiso.expiraEn!.year}',
      _ => 'Para siempre',
    };
  }
}

/// Elegir qué se le da, hasta cuándo y por qué.
///
/// Lo que se le da se busca como en el menú —módulo, pantalla, acción— con la
/// misma matriz de los roles, en vez de elegir la pantalla y la acción de dos
/// listas. Lo que su rol ya le da sale marcado en gris, y se pueden dar varias
/// cosas de una vez. En la misma matriz se cambia qué ve.
class _HojaDarPermisos extends ConsumerStatefulWidget {
  const _HojaDarPermisos({required this.usuario});

  final Usuario usuario;

  @override
  ConsumerState<_HojaDarPermisos> createState() => _HojaDarPermisosState();
}

class _HojaDarPermisosState extends ConsumerState<_HojaDarPermisos> {
  final Set<String> _marcadas = {};
  final _buscar = TextEditingController();
  final _motivo = TextEditingController();
  int _alcance = Alcance.unaVez;
  DateTime? _expira;
  bool _guardando = false;
  String? _error;

  /*
   * Qué clientes y ventas ve. No es un permiso que se gaste ni venza: manda
   * sobre lo de su rol hasta que se cambie (el supervisor del rol Vendedor que
   * debe verlo todo, o el dueño que solo atiende su ruta). Sin fila = igual
   * que su rol.
   */
  Map<String, String> _queVe = {};
  Map<String, String> _queVeBase = {};
  Map<String, String> _delRol = {};

  Usuario get _usuario => widget.usuario;

  List<int> get _rolIds =>
      _usuario.rolIds.isEmpty ? [_usuario.rolId] : _usuario.rolIds;

  @override
  void initState() {
    super.initState();
    _cargarAlcances();
  }

  /// Lo que ve hoy y lo que ve su rol. Si no llega, se queda en "igual que su
  /// rol", que es no tocar nada.
  Future<void> _cargarAlcances() async {
    final api = ref.read(configApiProvider);
    var propios = <String, String>{};
    var delRol = <String, String>{};
    try {
      propios = await api.alcancesDeUsuario(_usuario.id);
    } catch (_) {}
    try {
      delRol = await api.alcancesDeRol(_usuario.rolId);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _queVe = Map.of(propios);
      _queVeBase = propios;
      _delRol = delRol;
    });
  }

  @override
  void dispose() {
    _buscar.dispose();
    _motivo.dispose();
    super.dispose();
  }

  /// "Igual que su rol" no viaja: sin fila la persona sigue a su rol.
  Map<String, String> get _queVePropio => {
    for (final e in _queVe.entries)
      if (e.value.isNotEmpty) e.key: e.value,
  };

  bool get _cambioQueVe {
    final propio = _queVePropio;
    return propio.length != _queVeBase.length ||
        propio.entries.any((e) => _queVeBase[e.key] != e.value);
  }

  /// Lo que ya tiene y no se vuelve a dar: lo de sus roles y lo concedido
  /// antes que sigue vigente.
  Map<String, String> _fijas(
    List<Rol> roles,
    List<SubmoduloCatalogo> catalogo,
    List<UsuarioPermiso> vigentes,
  ) {
    final m = <String, String>{};
    final suyos = roles.where((r) => _rolIds.contains(r.id)).toList();
    // El Administrador lo tiene todo aunque la matriz de su rol no lo diga.
    if (suyos.any((r) => r.protegido)) {
      for (final s in catalogo) {
        for (final a in s.acciones) {
          m[clavePermiso(s.submodulo, a)] = 'Ya lo tiene: es Administrador';
        }
      }
      return m;
    }
    for (final r in suyos) {
      for (final p in r.permisos) {
        m[p.clave] = 'Ya lo tiene por su rol (${r.nombre})';
      }
    }
    for (final p in vigentes) {
      m.putIfAbsent(
        clavePermiso(p.submodulo, p.accion),
        () => 'Ya se le concedió y sigue vigente',
      );
    }
    return m;
  }

  void _alternar(
    String submodulo,
    String accion,
    List<String> acciones,
    Map<String, String> fijas,
  ) {
    setState(() {
      final k = clavePermiso(submodulo, accion);
      if (_marcadas.remove(k)) {
        // Sin Ver lo demás de esa pantalla quedaría dado pero inalcanzable.
        if (accion == 'ver') {
          _marcadas.removeAll([
            for (final a in acciones) clavePermiso(submodulo, a),
          ]);
        }
      } else {
        _marcadas.add(k);
        // Cualquier acción necesita poder entrar a la pantalla.
        final ver = clavePermiso(submodulo, 'ver');
        if (!fijas.containsKey(ver)) _marcadas.add(ver);
      }
    });
  }

  /// Lo elegido dicho en palabras ("Boletas: crear, ver"), para leerlo antes
  /// de confirmar. En el orden del catálogo, para que no salte al marcar.
  List<String> _resumen(List<SubmoduloCatalogo> catalogo) {
    final lineas = <String>[];
    for (final s in catalogo) {
      final acciones = [
        for (final a in accionesPermiso.keys)
          if (_marcadas.contains(clavePermiso(s.submodulo, a)))
            accionesPermiso[a]!.toLowerCase(),
      ];
      if (acciones.isNotEmpty) {
        lineas.add(
          '${vistaPermiso(s.submodulo).titulo}: ${acciones.join(', ')}',
        );
      }
    }
    return lineas;
  }

  Future<void> _guardar() async {
    if (_marcadas.isNotEmpty &&
        _alcance == Alcance.temporal &&
        _expira == null) {
      setState(() => _error = 'Elige hasta cuándo vale.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final api = ref.read(configApiProvider);
    final navegador = Navigator.of(context);
    final mensajero = Aviso.de(context);
    final total = _marcadas.length;
    final motivo = _motivo.text.trim();
    final cambioQueVe = _cambioQueVe;

    // Uno por uno: si alguno falla se para ahí y se dice cuántos se dieron.
    // Los que ya se dieron salen de lo marcado, para no darlos dos veces al
    // reintentar.
    var dados = 0;
    try {
      for (final k in [..._marcadas]) {
        final corte = k.lastIndexOf(':');
        await api.concederPermiso(
          usuarioId: _usuario.id,
          submodulo: k.substring(0, corte),
          accion: k.substring(corte + 1),
          alcance: _alcance,
          expiraEn: _alcance == Alcance.temporal ? _expira : null,
          motivo: motivo.isEmpty ? null : motivo,
        );
        _marcadas.remove(k);
        dados++;
      }
      if (cambioQueVe) {
        await api.guardarAlcancesUsuario(_usuario.id, _queVePropio);
      }
      ref.invalidate(excepcionesProvider);
      navegador.pop();
      mensajero.mostrar(
        [
          if (dados == 1) 'Permiso concedido',
          if (dados > 1) '$dados permisos concedidos',
          if (cambioQueVe) 'Qué ve guardado',
        ].join(' · '),
      );
    } on ApiExcepcion catch (e) {
      if (dados > 0) ref.invalidate(excepcionesProvider);
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = dados > 0 ? 'Se dieron $dados de $total. ${e.texto}' : e.texto;
      });
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _expira ?? hoy.add(const Duration(days: 7)),
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
    );
    if (elegida == null) return;
    // Hasta el final de ese día: elegir "el 20" y que caduque a las 00:00 del
    // 20 no deja ningún día útil.
    setState(
      () =>
          _expira = DateTime(elegida.year, elegida.month, elegida.day, 23, 59),
    );
  }

  static String _dia(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final catalogo =
        ref.watch(catalogoPermisosProvider).valueOrNull ??
        const <SubmoduloCatalogo>[];
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <Rol>[];
    final vigentes = [
      for (final p
          in ref.watch(excepcionesProvider).valueOrNull ??
              const <UsuarioPermiso>[])
        if (p.vigente) p,
    ];
    final pantallas =
        ref.watch(pantallasAlcanceProvider).valueOrNull ?? const <String>[];

    final fijas = _fijas(roles, catalogo, vigentes);
    final esAdmin = roles.any((r) => r.protegido && _rolIds.contains(r.id));
    final resumen = _resumen(catalogo);
    final cambioQueVe = _cambioQueVe;
    final hayMarcadas = _marcadas.isNotEmpty;
    final listo = hayMarcadas
        ? _alcance != Alcance.temporal || _expira != null
        : cambioQueVe;

    final estado = [
      if (hayMarcadas)
        '${_marcadas.length} ${_marcadas.length == 1 ? 'permiso' : 'permisos'}'
            ' · ${Alcance.etiqueta(_alcance).toLowerCase()}',
      if (cambioQueVe) 'Qué ve cambiado',
    ].join(' · ');

    return HojaBase(
      titulo: 'Dar permisos a ${_usuario.nombre}',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlerta(_error!),
            const SizedBox(height: Dimen.espacio3),
          ],
          const Text(
            '¿Qué necesita hacer? Lo que ya tiene sale marcado en gris.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colores.tinta,
            ),
          ),
          const SizedBox(height: Dimen.espacio2),
          TextField(
            controller: _buscar,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Buscar pantalla: boletas, caja…',
              isDense: true,
            ),
          ),
          const SizedBox(height: Dimen.espacio3),
          MatrizPermisos(
            catalogo: catalogo,
            marcadas: _marcadas,
            fijas: fijas,
            filtro: _buscar.text,
            nuevas: true,
            onAlternar: (s, a, acciones) => _alternar(s, a, acciones, fijas),
            alcance: AlcanceEnMatriz(
              pantallas: pantallas,
              valores: _queVe,
              heredado: _delRol,
              // El Administrador ve siempre todo.
              deshabilitado: esAdmin || _guardando,
              onCambio: (sub, nivel) =>
                  setState(() => _queVe = {..._queVe, sub: nivel}),
            ),
          ),
          Text(
            'Qué ve dice de qué clientes y ventas: no se gasta ni vence, '
            'queda hasta que lo cambies.'
            '${_usuario.rutaIds.isEmpty ? ' Esta persona no tiene ruta asignada (se asigna en Usuarios): con "Solo mis rutas" no verá ningún cliente.' : ''}',
            style: const TextStyle(fontSize: 11.5, color: Colores.tintaSuave),
          ),

          if (resumen.isNotEmpty) ...[
            const SizedBox(height: Dimen.espacio2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimen.espacio3,
                vertical: Dimen.espacio2,
              ),
              decoration: BoxDecoration(
                color: Colores.exitoSuave,
                borderRadius: BorderRadius.circular(Dimen.radioCampo),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in resumen)
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Podrá',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' · $r'),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF065F46),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Hasta cuándo y por qué son de los permisos marcados: sin ninguno no
          // hay nada que preguntar.
          if (hayMarcadas) ...[
            const SizedBox(height: Dimen.espacio4),
            AppSelector<int>(
              valor: _alcance,
              etiqueta: '¿Hasta cuándo?',
              icono: Icons.timelapse_outlined,
              habilitado: !_guardando,
              opciones: [
                for (final a in Alcance.todos) Opcion(a, Alcance.etiqueta(a)),
              ],
              onCambio: (v) => setState(() => _alcance = v ?? Alcance.unaVez),
            ),
            const SizedBox(height: Dimen.espacio1),
            Text(
              _alcance == Alcance.permanente
                  ? 'No vence. Si varias personas lo necesitan, es mejor '
                        'ponerlo en el rol.'
                  : Alcance.explicacion(_alcance),
              style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
            ),
            if (_alcance == Alcance.temporal) ...[
              const SizedBox(height: Dimen.espacio3),
              InkWell(
                onTap: _guardando ? null : _elegirFecha,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Vence el',
                    constraints: BoxConstraints(minHeight: Dimen.campoLg),
                  ),
                  child: Text(
                    _expira == null ? 'Elige la fecha' : _dia(_expira!),
                    style: TextStyle(
                      fontSize: 14,
                      color: _expira == null
                          ? Colores.tintaSuave
                          : Colores.tinta,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: Dimen.espacio3),
            AppCampo(
              controlador: _motivo,
              etiqueta: 'Motivo',
              pista: 'Boleta de la NV-0042 que pidió el cliente',
              opcional: true,
              habilitado: !_guardando,
              maxLargo: 300,
            ),
          ],
        ],
      ),
      pie: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            estado.isEmpty ? 'Marca lo que necesita.' : estado,
            style: const TextStyle(fontSize: 12, color: Colores.tintaSuave),
          ),
          const SizedBox(height: Dimen.espacio2),
          AppBotonesFormulario(
            onCancelar: () => Navigator.of(context).pop(),
            textoGuardar: hayMarcadas ? 'Conceder' : 'Guardar',
            cargando: _guardando,
            onGuardar: listo ? _guardar : null,
          ),
        ],
      ),
    );
  }
}
