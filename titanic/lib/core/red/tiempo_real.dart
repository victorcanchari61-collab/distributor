import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../almacenamiento/sesion_almacen.dart';
import '../config/entorno.dart';

/// Un cambio que ocurrió en el servidor.
///
/// El mismo evento que escucha el panel web: qué módulo cambió, qué se le hizo
/// y el dato, si lo trae.
class CambioEvento {
  const CambioEvento({
    required this.modulo,
    required this.accion,
    required this.datos,
  });

  final String modulo;
  final String accion;
  final Object? datos;

  factory CambioEvento.desdeJson(Map<String, dynamic> json) => CambioEvento(
    modulo: json['modulo'] as String? ?? '',
    accion: json['accion'] as String? ?? '',
    datos: json['datos'],
  );

  @override
  String toString() => 'CambioEvento($modulo/$accion)';
}

/// La conexión viva con el servidor.
///
/// Sirve para lo que el vendedor no puede adivinar: que le concedieron un
/// permiso, que cambió un precio, que otro ya se llevó el stock que estaba
/// por prometer. Sin esto la app solo se entera cuando pregunta, y entre
/// pregunta y pregunta toma pedidos con datos viejos.
///
/// Una sola conexión para toda la app: cada pantalla se suscribe a su módulo
/// en vez de abrir la suya. La URL sale de [Entorno.apiUrl] quitándole el
/// `/api`, porque el hub cuelga del mismo servidor pero de otra ruta.
///
/// Si la conexión no se puede abrir, la app sigue funcionando igual: solo deja
/// de actualizarse sola. Por eso el error se registra pero no se propaga — una
/// pantalla que revienta porque no hay socket sería peor que una que no se
/// refresca.
class TiempoReal {
  TiempoReal({SesionAlmacen? sesion}) : _sesion = sesion ?? SesionAlmacen();

  final SesionAlmacen _sesion;
  final _eventos = StreamController<CambioEvento>.broadcast();

  HubConnection? _conexion;
  bool _conectando = false;

  /// Todos los cambios, tal como llegan.
  Stream<CambioEvento> get eventos => _eventos.stream;

  /// Solo los de estos módulos: 'productos', 'stock', 'permisos'...
  Stream<CambioEvento> de(List<String> modulos) =>
      _eventos.stream.where((e) => modulos.contains(e.modulo));

  static String get _urlHub {
    final api = Entorno.apiUrl;
    final base = api.endsWith('/api') ? api.substring(0, api.length - 4) : api;
    return '$base/hubs/cambios';
  }

  /// Abre la conexión si no está abierta. Llamarla de más no cuesta nada.
  Future<void> conectar() async {
    if (_conexion?.state == HubConnectionState.Connected || _conectando) return;

    final token = await _sesion.token();
    if (token == null) return;

    _conectando = true;
    try {
      final conexion = HubConnectionBuilder()
          .withUrl(
            _urlHub,
            options: HttpConnectionOptions(
              // El backend lee el token de la query en las conexiones al hub:
              // el WebSocket no lleva cabeceras propias.
              accessTokenFactory: () async => (await _sesion.token()) ?? '',
              transport: HttpTransportType.WebSockets,
            ),
          )
          .withAutomaticReconnect()
          .build();

      conexion.on('cambio', (argumentos) {
        final dato = argumentos?.firstOrNull;
        if (dato is Map) {
          _eventos.add(CambioEvento.desdeJson(Map<String, dynamic>.from(dato)));
        }
      });

      await conexion.start();
      _conexion = conexion;
    } catch (e) {
      debugPrint('Tiempo real: no se pudo conectar ($e)');
    } finally {
      _conectando = false;
    }
  }

  /// Cierra la conexión: al cerrar sesión, para no seguir recibiendo lo de
  /// alguien que ya no está.
  Future<void> desconectar() async {
    await _conexion?.stop();
    _conexion = null;
  }

  /// Vuelve a levantarla si se cayó mientras la app estaba en segundo plano.
  ///
  /// Android corta los sockets de una app que no está a la vista, y
  /// `withAutomaticReconnect` no siempre alcanza a notarlo: al volver, se
  /// comprueba a mano.
  Future<void> asegurarConexion() async {
    if (_conexion?.state == HubConnectionState.Connected) return;
    await conectar();
  }

  void dispose() {
    unawaited(desconectar());
    unawaited(_eventos.close());
  }
}
