import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titanic/compartido/widgets/app_selector.dart';
import 'package:titanic/core/almacenamiento/sesion_almacen.dart';
import 'package:titanic/core/red/cliente_api.dart';
import 'package:titanic/core/tema/tema.dart';
import 'package:titanic/features/auth/estado/auth_controlador.dart';
import 'package:titanic/features/config/datos/config_api.dart';
import 'package:titanic/features/config/datos/config_modelos.dart';
import 'package:titanic/features/config/estado/config_controlador.dart';
import 'package:titanic/features/config/vistas/usuario_formulario.dart';
import 'package:titanic/features/maestros/datos/empleado.dart';
import 'package:titanic/features/maestros/datos/maestros_api.dart';
import 'package:titanic/features/maestros/estado/maestros_controlador.dart';

/// Sesion iniciada, para poder pintar pantallas internas.
class _AlmacenConSesion extends SesionAlmacen {
  const _AlmacenConSesion();

  @override
  Future<String?> token() async => 'token';

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

/// La ficha completa tal como la devuelve el API.
Map<String, dynamic> _empleadoJson() => {
  'id': 7,
  'documento': '45871203',
  'tipoDoc': 'DNI',
  'nombres': 'Juan Carlos',
  'apellidos': 'Quispe Mamani',
  'nombreCompleto': 'Juan Carlos Quispe Mamani',
  'telefono': '987654321',
  'email': 'juan@distributor.com',
  'direccion': 'AV. LOS OLIVOS 123',
  'cargo': 'Repartidor',
  'area': 'Reparto',
  'fechaIngreso': '2024-03-05T00:00:00',
  'fechaCese': null,
  'observacion': 'Tiene brevete A-IIb',
  'activo': true,
  'fechaCreacion': '2024-03-05T14:20:00',
  'usuarioId': 3,
  'usuario': 'juan',
};

/// El usuario que se edita en la prueba del selector: ya tiene ficha enlazada.
Map<String, dynamic> _usuarioJson() => {
  'id': 3,
  'nombre': 'Juan Quispe',
  'email': 'juan@distributor.com',
  'dni': '45871203',
  'rolId': 2,
  'rol': 'Vendedor',
  'empleadoId': 7,
  'empleado': 'Juan Carlos Quispe Mamani',
  'activo': true,
};

/// API de configuracion de mentira: no toca la red.
class _ConfigFalso extends ConfigApi {
  _ConfigFalso() : super(ClienteApi());

  /// Lo que se envio en la ultima edicion, para comprobar el formulario.
  Map<String, dynamic>? ultimoActualizado;

  @override
  Future<List<Usuario>> usuarios() async => [Usuario.desdeJson(_usuarioJson())];

  @override
  Future<List<Rol>> roles() async => [
    Rol.desdeJson({
      'id': 2,
      'nombre': 'Vendedor',
      'activo': true,
      'delSistema': false,
      'protegido': false,
      'usuarios': 1,
    }),
  ];

  @override
  Future<Usuario> actualizarUsuario(int id, Map<String, dynamic> cuerpo) async {
    ultimoActualizado = cuerpo;
    return Usuario.desdeJson(_usuarioJson());
  }
}

/// API de maestros de mentira: solo hace falta el padron de empleados.
class _MaestrosFalso extends MaestrosApi {
  _MaestrosFalso() : super(ClienteApi());

  @override
  Future<List<EmpleadoOpcion>> opcionesEmpleado() async => [
    // El que ya tiene la cuenta que se edita: tiene que poder seguir elegido.
    EmpleadoOpcion.desdeJson({
      'id': 7,
      'documento': '45871203',
      'nombreCompleto': 'Juan Carlos Quispe Mamani',
      'cargo': 'Repartidor',
      'usuarioId': 3,
    }),
    // Ocupado por OTRA cuenta: sale en la lista pero no se puede elegir.
    EmpleadoOpcion.desdeJson({
      'id': 8,
      'documento': '10203040',
      'nombreCompleto': 'Rosa Huaman',
      'cargo': 'Almacenera',
      'usuarioId': 9,
    }),
    EmpleadoOpcion.desdeJson({
      'id': 9,
      'documento': '50607080',
      'nombreCompleto': 'Luis Ccahuana',
      'cargo': null,
      'usuarioId': null,
    }),
  ];
}

/// Espera a que el aviso de "guardado" se retire solo.
///
/// Se queda tres segundos en pantalla con su propio temporizador, y el test
/// falla si el arbol se desmonta con uno pendiente.
Future<void> _dejarPasarElAviso(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  group('modelo', () {
    test('lee la ficha completa que manda el API', () {
      final empleado = Empleado.desdeJson(_empleadoJson());

      expect(empleado.id, 7);
      expect(empleado.documento, '45871203');
      expect(empleado.tipoDoc, 'DNI');
      expect(empleado.nombreCompleto, 'Juan Carlos Quispe Mamani');
      expect(empleado.cargo, 'Repartidor');
      expect(empleado.area, 'Reparto');
      expect(empleado.fechaIngreso, DateTime(2024, 3, 5));
      expect(empleado.fechaCese, isNull);
      expect(empleado.usuarioId, 3);
      expect(empleado.usuario, 'juan');
      expect(empleado.activo, isTrue);
    });

    test('ida y vuelta: lo que se envia se vuelve a leer igual', () {
      final original = Empleado.desdeJson(_empleadoJson());
      // Al releer falta lo que el cuerpo no manda —el id, el estado— porque el
      // servidor no los toma del cuerpo: se reponen del original.
      final vuelta = Empleado.desdeJson({
        ...original.aJson(),
        'id': original.id,
        'activo': original.activo,
      });

      expect(vuelta.documento, original.documento);
      expect(vuelta.tipoDoc, original.tipoDoc);
      expect(vuelta.nombres, original.nombres);
      expect(vuelta.apellidos, original.apellidos);
      expect(vuelta.telefono, original.telefono);
      expect(vuelta.email, original.email);
      expect(vuelta.direccion, original.direccion);
      expect(vuelta.cargo, original.cargo);
      expect(vuelta.area, original.area);
      expect(vuelta.fechaIngreso, original.fechaIngreso);
      expect(vuelta.observacion, original.observacion);
    });

    /*
     * Los campos sin llenar tienen que seguir vacios al otro lado.
     *
     * Una cadena vacia en vez de null no es lo mismo para el servidor: una
     * fecha de cese en "" lo hace fallar, y un empleado en activo quedaria
     * sin poder guardarse solo por no haber dejado de trabajar.
     */
    test('los campos vacios viajan como null y vuelven como null', () {
      final minimo = Empleado.desdeJson({
        'id': 1,
        'documento': 'EXT-001',
        'tipoDoc': 'CODIGO',
        'nombres': 'Marta',
        'apellidos': 'Silva',
        'activo': true,
      });

      final cuerpo = minimo.aJson();
      expect(cuerpo['telefono'], isNull);
      expect(cuerpo['email'], isNull);
      expect(cuerpo['direccion'], isNull);
      expect(cuerpo['cargo'], isNull);
      expect(cuerpo['area'], isNull);
      expect(cuerpo['fechaIngreso'], isNull);
      expect(cuerpo['fechaCese'], isNull);
      expect(cuerpo['observacion'], isNull);

      final vuelta = Empleado.desdeJson({...cuerpo, 'id': 1, 'activo': true});
      expect(vuelta.nombreCompleto, 'Marta Silva');
      expect(vuelta.fechaIngreso, isNull);
      expect(vuelta.fechaCese, isNull);
      expect(vuelta.usuarioId, isNull);
    });

    test('la opcion del selector arma su etiqueta con el cargo', () {
      final conCargo = EmpleadoOpcion.desdeJson({
        'id': 1,
        'documento': '45871203',
        'nombreCompleto': 'Juan Quispe',
        'cargo': 'Repartidor',
        'usuarioId': null,
      });
      final sinCargo = EmpleadoOpcion.desdeJson({
        'id': 2,
        'documento': '10203040',
        'nombreCompleto': 'Rosa Huaman',
        'cargo': null,
        'usuarioId': 4,
      });

      expect(conCargo.etiqueta, 'Juan Quispe — Repartidor');
      expect(sinCargo.etiqueta, 'Rosa Huaman');
      expect(sinCargo.usuarioId, 4);
    });
  });

  group('selector de empleado en el formulario de usuario', () {
    Future<_ConfigFalso> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final config = _ConfigFalso();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sesionAlmacenProvider.overrideWithValue(const _AlmacenConSesion()),
            configApiProvider.overrideWithValue(config),
            maestrosApiProvider.overrideWithValue(_MaestrosFalso()),
          ],
          child: MaterialApp(
            theme: Tema.claro(),
            home: UsuarioFormulario(
              usuario: Usuario.desdeJson(_usuarioJson()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return config;
    }

    /*
     * Editar sin tocar el selector no puede desenlazar la ficha.
     *
     * El PUT de usuario REEMPLAZA el registro: si `empleadoId` no viaja, el
     * servidor lo toma como null y alguien que solo corrigio un nombre se
     * queda sin su empleado, sin aviso y sin manera de notarlo.
     */
    testWidgets('al editar reenvia el empleadoId que ya tenia', (tester) async {
      final config = await montar(tester);

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await _dejarPasarElAviso(tester);

      expect(config.ultimoActualizado?['empleadoId'], 7);
    });

    testWidgets('el que ya tiene otra cuenta sale ocupado y el propio no', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.byType(AppSelector<int?>).last);
      await tester.pumpAndSettle();

      // El de otra cuenta lo dice; el del usuario que se edita, no.
      expect(
        find.text('Rosa Huaman — Almacenera (ya tiene usuario)'),
        findsOneWidget,
      );
      expect(
        find.text('Juan Carlos Quispe Mamani — Repartidor (ya tiene usuario)'),
        findsNothing,
      );
      expect(find.text('Sin empleado'), findsOneWidget);
    });

    testWidgets('se puede desenlazar eligiendo "Sin empleado"', (tester) async {
      final config = await montar(tester);

      await tester.tap(find.byType(AppSelector<int?>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin empleado').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await _dejarPasarElAviso(tester);

      expect(config.ultimoActualizado?['empleadoId'], isNull);
    });
  });
}
