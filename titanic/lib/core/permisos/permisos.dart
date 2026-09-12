import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/estado/auth_controlador.dart';
import '../red/cliente_api.dart';

/// Lo que se puede hacer sobre un submódulo.
///
/// Son los mismos nombres que usa el backend: si aquí se escribieran distintos,
/// el permiso concedido en Accesos no coincidiría con el que la pantalla
/// consulta, y el botón seguiría escondido sin que nadie entendiera por qué.
class Accion {
  const Accion._();

  static const ver = 'ver';
  static const crear = 'crear';
  static const editar = 'editar';
  static const anular = 'anular';
  static const eliminar = 'eliminar';
  static const exportar = 'exportar';
  static const importar = 'importar';
  static const confirmar = 'confirmar';
  static const cobrar = 'cobrar';
}

/// Un submódulo del catálogo y las acciones que admite.
class SubmoduloCatalogo {
  const SubmoduloCatalogo({
    required this.submodulo,
    required this.modulo,
    required this.acciones,
  });

  final String submodulo;
  final String modulo;
  final List<String> acciones;

  factory SubmoduloCatalogo.desdeJson(Map<String, dynamic> json) => SubmoduloCatalogo(
    submodulo: json['submodulo'] as String? ?? '',
    modulo: json['modulo'] as String? ?? '',
    acciones: ((json['acciones'] as List?) ?? const []).map((e) => e as String).toList(),
  );
}

/// Llamadas de permisos.
class PermisoApi {
  const PermisoApi(this._api);

  final ClienteApi _api;

  /// GET /api/permiso/mios — claves "submodulo:accion".
  Future<Set<String>> mios() async {
    final datos = await _api.get('/permiso/mios') as List;
    return datos.map((e) => e as String).toSet();
  }

  /// GET /api/permiso/catalogo
  Future<List<SubmoduloCatalogo>> catalogo() async {
    final datos = await _api.get('/permiso/catalogo') as List;
    return datos
        .map((e) => SubmoduloCatalogo.desdeJson(e as Map<String, dynamic>))
        .toList();
  }
}

final permisoApiProvider = Provider((ref) => PermisoApi(ref.watch(clienteApiProvider)));

/// Lo que esta persona puede hacer.
///
/// Se pide al servidor y NO se saca del token: un permiso recién concedido
/// tiene que servir sin que la persona vuelva a entrar, que es justo el caso
/// que resuelve el circuito de solicitar y aprobar.
///
/// Se ata a la sesión: al cambiar de usuario se vuelve a pedir, porque si no
/// quien entrara después heredaría los permisos del anterior.
final misPermisosProvider = FutureProvider<Set<String>>((ref) async {
  final usuario = ref.watch(authProvider).usuario;
  if (usuario == null) return const <String>{};

  return ref.watch(permisoApiProvider).mios();
});

/// Si se puede hacer una acción concreta.
///
/// Esconder un botón es comodidad, no seguridad: el backend rechaza igual a
/// quien llame al endpoint. Aquí solo se evita ofrecer algo que va a terminar
/// en un error.
///
/// Mientras los permisos cargan devuelve false: es preferible un botón que
/// aparece un instante después a uno que se ofrece y luego falla.
bool puede(WidgetRef ref, String submodulo, String accion) =>
    ref.watch(misPermisosProvider).valueOrNull?.contains('$submodulo:$accion') ?? false;

/// Si la pantalla se puede abrir siquiera.
bool puedeVer(WidgetRef ref, String submodulo) => puede(ref, submodulo, Accion.ver);

/// La versión para leer sin suscribirse, dentro de un callback.
bool puedeLeer(Ref ref, String submodulo, String accion) =>
    ref.read(misPermisosProvider).valueOrNull?.contains('$submodulo:$accion') ?? false;
