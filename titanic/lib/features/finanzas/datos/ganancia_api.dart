import '../../../compartido/consulta_tabla.dart';
import '../../../core/red/cliente_api.dart';
import 'ganancia.dart';

/// Llamadas de "Mis ganancias".
class GananciaApi {
  const GananciaApi(this._api);

  final ClienteApi _api;

  /// POST /api/ganancia/listar. Una página de productos con su ganancia, ya
  /// filtrada y ordenada en el servidor, más los totales de TODO lo filtrado y
  /// lo que hay para elegir en los filtros.
  ///
  /// Lo que se ve lo recorta el alcance de quien pregunta: quien solo vende ve
  /// lo suyo, y eso lo aplica el servidor, no la app.
  Future<GananciaPagina> listar(ConsultaTabla consulta) async =>
      GananciaPagina.desdeJson(
        await _api.post('/ganancia/listar', cuerpo: consulta.aJson())
            as Map<String, dynamic>,
      );
}
