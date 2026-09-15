import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/estado/auth_controlador.dart';
import '../red/cliente_api.dart';

/// Pedir un permiso con el que uno se topó bloqueado.
///
/// Existe aparte del resto de llamadas porque no pertenece a ningún módulo:
/// cualquiera puede topar con una acción bloqueada, en cualquier pantalla.
class SolicitudApi {
  const SolicitudApi(this._api);

  final ClienteApi _api;

  /// POST /api/permiso/solicitar
  ///
  /// Pedir dos veces lo mismo no duplica nada: el backend devuelve la
  /// solicitud que ya estuviera abierta.
  Future<void> solicitar({
    required String submodulo,
    required String accion,
    String? motivo,
    String? referencia,
  }) => _api.post(
    '/permiso/solicitar',
    cuerpo: {
      'submodulo': submodulo,
      'accion': accion,
      'motivo': motivo,
      'referencia': referencia,
    },
  );

  /// GET /api/permiso/solicitudes/mias — solo las que siguen sin respuesta,
  /// como claves "submodulo:accion".
  ///
  /// Se filtra aquí y no en la pantalla porque lo resuelto no sirve de nada:
  /// una solicitud aprobada ya se ve como permiso concedido, y una rechazada
  /// se puede volver a pedir.
  Future<Set<String>> misPendientes() async {
    final datos = await _api.get('/permiso/solicitudes/mias') as List;

    return {
      for (final e in datos.cast<Map<String, dynamic>>())
        // 0 es pendiente en el backend.
        if ((e['estado'] as int? ?? 0) == 0) '${e['submodulo']}:${e['accion']}',
    };
  }
}

final solicitudApiProvider = Provider((ref) => SolicitudApi(ref.watch(clienteApiProvider)));
