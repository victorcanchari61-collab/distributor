import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/estado/auth_controlador.dart';
import '../datos/perfil_api.dart';

final perfilApiProvider = Provider(
  (ref) => PerfilApi(ref.watch(clienteApiProvider)),
);
