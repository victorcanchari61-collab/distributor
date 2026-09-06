import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/estado/auth_controlador.dart';
import '../../core/red/ubigeo_api.dart';

/// Ubigeo oficial del Perú, compartido por cualquier feature que necesite un
/// distrito (Cliente hoy). Son ~1900 distritos pero pesan poco como JSON: se
/// cargan enteros una sola vez y el formulario filtra en el cliente para
/// encadenar Departamento → Provincia → Distrito sin ida y vuelta al server.
final ubigeoApiProvider = Provider((ref) => UbigeoApi(ref.watch(clienteApiProvider)));

// Sin autoDispose: es catalogo fijo (INEI/RENIEC), no cambia en la sesion, asi
// que no tiene sentido volver a pedirlo cada vez que se abre el formulario.
final departamentosProvider = FutureProvider<List<Departamento>>(
  (ref) => ref.watch(ubigeoApiProvider).departamentos(),
);

final provinciasProvider = FutureProvider<List<Provincia>>(
  (ref) => ref.watch(ubigeoApiProvider).provincias(),
);

final distritosProvider = FutureProvider<List<Distrito>>(
  (ref) => ref.watch(ubigeoApiProvider).distritos(),
);
