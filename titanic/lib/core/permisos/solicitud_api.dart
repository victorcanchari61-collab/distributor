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
}

final solicitudApiProvider = Provider((ref) => SolicitudApi(ref.watch(clienteApiProvider)));
