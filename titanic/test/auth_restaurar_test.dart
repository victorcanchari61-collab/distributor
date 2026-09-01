import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';

/// Almacen que revienta al leer, como paso en el dispositivo real.
class _AlmacenRoto extends SesionAlmacen {
  const _AlmacenRoto();

  @override
  Future<String?> token() async => throw Exception('almacén no disponible');

  @override
  Future<Map<String, dynamic>?> usuario() async => throw Exception('almacén no disponible');
}

/// Almacen que nunca responde: prueba el limite de tiempo.
class _AlmacenColgado extends SesionAlmacen {
  const _AlmacenColgado();

  @override
  Future<String?> token() => Future.delayed(const Duration(minutes: 1), () => null);

  @override
  Future<Map<String, dynamic>?> usuario() =>
      Future.delayed(const Duration(minutes: 1), () => null);
}

/// Almacen vacio: no hay sesion guardada.
class _AlmacenVacio extends SesionAlmacen {
  const _AlmacenVacio();

  @override
  Future<String?> token() async => null;

  @override
  Future<Map<String, dynamic>?> usuario() async => null;
}

/// Almacen con una sesion valida.
class _AlmacenConSesion extends SesionAlmacen {
  const _AlmacenConSesion();

  @override
  Future<String?> token() async => 'token-de-prueba';

  @override
  Future<Map<String, dynamic>?> usuario() async => {
        'id': 1,
        'nombre': 'Admin',
        'email': 'admin@distributor.com',
        'rolId': 1,
        'rol': 'Administrador',
        'activo': true,
      };
}

ProviderContainer _contenedor(SesionAlmacen almacen) {
  final c = ProviderContainer(
    overrides: [sesionAlmacenProvider.overrideWithValue(almacen)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('restaurar sesion', () {
    test('si el almacen falla, deja pasar al login en vez de colgarse', () async {
      final c = _contenedor(const _AlmacenRoto());

      await c.read(authProvider.notifier).restaurar();

      expect(c.read(authProvider).estado, EstadoSesion.invitado);
    });

    test('si el almacen no responde, corta y deja pasar al login', () async {
      final c = _contenedor(const _AlmacenColgado());

      await c.read(authProvider.notifier).restaurar();

      expect(c.read(authProvider).estado, EstadoSesion.invitado);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('sin sesion guardada queda como invitado', () async {
      final c = _contenedor(const _AlmacenVacio());

      await c.read(authProvider.notifier).restaurar();

      expect(c.read(authProvider).estado, EstadoSesion.invitado);
      expect(c.read(authProvider).usuario, isNull);
    });

    test('con sesion guardada entra directo', () async {
      final c = _contenedor(const _AlmacenConSesion());

      await c.read(authProvider.notifier).restaurar();

      final estado = c.read(authProvider);
      expect(estado.estado, EstadoSesion.autenticado);
      expect(estado.usuario?.nombre, 'Admin');
      expect(estado.usuario?.rol, 'Administrador');
    });
  });
}
