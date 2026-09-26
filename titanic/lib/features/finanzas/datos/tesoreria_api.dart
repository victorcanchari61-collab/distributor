import '../../../compartido/fechas.dart';
import '../../../core/red/cliente_api.dart';
import 'mi_caja.dart';
import 'tesoreria.dart';

/// Llamadas de la tesoreria: el kardex del dinero, el estado de resultados,
/// los cierres de caja y los prestamos recibidos.
class TesoreriaApi {
  const TesoreriaApi(this._api);

  final ClienteApi _api;

  // --- Kardex del dinero ---

  /// GET /api/movimientodinero?desde&hasta
  Future<List<MovimientoDinero>> movimientos(
    DateTime desde,
    DateTime hasta,
  ) async {
    final datos =
        await _api.get(
              '/movimientodinero?desde=${diaIso(desde)}&hasta=${diaIso(hasta)}',
            )
            as List;
    return datos
        .map((e) => MovimientoDinero.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/movimientodinero/cuentas: las cajas y bancos activos.
  Future<List<CuentaDestino>> cuentasMovimiento() async {
    final datos = await _api.get('/movimientodinero/cuentas') as List;
    return datos
        .map((e) => CuentaDestino.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/gastooperativo: un ingreso o egreso registrado a mano.
  Future<void> crearMovimiento(Map<String, dynamic> cuerpo) =>
      _api.post('/gastooperativo', cuerpo: cuerpo);

  /// PATCH /api/gastooperativo/{id}/anular
  Future<void> anularMovimiento(int movimientoOperativoId) =>
      _api.patch('/gastooperativo/$movimientoOperativoId/anular');

  // --- Estado de resultados ---

  /// GET /api/estadoresultados?desde&hasta
  Future<EstadoResultados> estadoResultados(
    DateTime desde,
    DateTime hasta,
  ) async => EstadoResultados.desdeJson(
    await _api.get(
          '/estadoresultados?desde=${diaIso(desde)}&hasta=${diaIso(hasta)}',
        )
        as Map<String, dynamic>,
  );

  // --- Cierres de caja ---

  /// GET /api/cierrecaja?desde&hasta
  Future<List<CierreRegistrado>> cierres(DateTime desde, DateTime hasta) async {
    final datos =
        await _api.get(
              '/cierrecaja?desde=${diaIso(desde)}&hasta=${diaIso(hasta)}',
            )
            as List;
    return datos
        .map((e) => CierreRegistrado.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /api/cierrecaja/{id}/anular: revierte la entrega y el ajuste.
  Future<void> anularCierre(int id) => _api.patch('/cierrecaja/$id/anular');

  // --- Prestamos recibidos ---

  /// GET /api/financiamiento
  Future<List<Prestamo>> prestamos() async {
    final datos = await _api.get('/financiamiento') as List;
    return datos
        .map((e) => Prestamo.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/financiamiento/cuentas: a donde entra o de donde sale la plata.
  Future<List<CuentaDestino>> cuentasPrestamo() async {
    final datos = await _api.get('/financiamiento/cuentas') as List;
    return datos
        .map((e) => CuentaDestino.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/financiamiento
  Future<void> crearPrestamo(Map<String, dynamic> cuerpo) =>
      _api.post('/financiamiento', cuerpo: cuerpo);

  /// POST /api/financiamiento/{id}/pagos
  Future<void> pagarPrestamo(int id, Map<String, dynamic> cuerpo) =>
      _api.post('/financiamiento/$id/pagos', cuerpo: cuerpo);

  /// PATCH /api/financiamiento/{id}/pagos/{pagoId}/anular
  Future<void> anularPagoPrestamo(int id, int pagoId) =>
      _api.patch('/financiamiento/$id/pagos/$pagoId/anular');

  /// PATCH /api/financiamiento/{id}/anular: solo si no tiene pagos vigentes.
  Future<void> anularPrestamo(int id) =>
      _api.patch('/financiamiento/$id/anular');

  // --- Cajas y cuentas bancarias ---

  /// GET /api/cuentafinanciera: cajas, bancos y pasarelas.
  Future<List<CuentaFinanciera>> cuentas() async {
    final datos = await _api.get('/cuentafinanciera') as List;
    return datos
        .map((e) => CuentaFinanciera.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/cuentafinanciera
  Future<void> crearCuenta(Map<String, dynamic> cuerpo) =>
      _api.post('/cuentafinanciera', cuerpo: cuerpo);

  /// PUT /api/cuentafinanciera/{id}
  Future<void> actualizarCuenta(int id, Map<String, dynamic> cuerpo) =>
      _api.put('/cuentafinanciera/$id', cuerpo: cuerpo);

  /// GET /api/cuentafinanciera/{id}/movimientos?desde&hasta
  Future<List<MovimientoCaja>> movimientosCuenta(
    int id,
    DateTime desde,
    DateTime hasta,
  ) async {
    final datos =
        await _api.get(
              '/cuentafinanciera/$id/movimientos?desde=${diaIso(desde)}&hasta=${diaIso(hasta)}',
            )
            as List;
    return datos
        .map((e) => MovimientoCaja.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/banco
  Future<List<Banco>> bancos() async {
    final datos = await _api.get('/banco') as List;
    return datos
        .map((e) => Banco.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/banco
  Future<Banco> crearBanco(String nombre) async => Banco.desdeJson(
    await _api.post('/banco', cuerpo: {'nombre': nombre, 'activo': true})
        as Map<String, dynamic>,
  );

  // --- Ingresos y egresos ---

  /// GET /api/gastooperativo/categorias: el catalogo completo, con sus usos.
  Future<List<CategoriaFinanzas>> categorias() async {
    final datos = await _api.get('/gastooperativo/categorias') as List;
    return datos
        .map((e) => CategoriaFinanzas.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/gastooperativo/categorias
  Future<void> crearCategoria(Map<String, dynamic> cuerpo) =>
      _api.post('/gastooperativo/categorias', cuerpo: cuerpo);

  /// PUT /api/gastooperativo/categorias/{id}
  Future<void> actualizarCategoria(int id, Map<String, dynamic> cuerpo) =>
      _api.put('/gastooperativo/categorias/$id', cuerpo: cuerpo);

  /// DELETE /api/gastooperativo/categorias/{id}: solo sin usos.
  Future<void> eliminarCategoria(int id) =>
      _api.delete('/gastooperativo/categorias/$id');

  /// GET /api/gastooperativo/recurrentes
  Future<List<GastoRecurrente>> recurrentes() async {
    final datos = await _api.get('/gastooperativo/recurrentes') as List;
    return datos
        .map((e) => GastoRecurrente.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/gastooperativo/recurrentes
  Future<void> crearRecurrente(Map<String, dynamic> cuerpo) =>
      _api.post('/gastooperativo/recurrentes', cuerpo: cuerpo);

  /// PUT /api/gastooperativo/recurrentes/{id}
  Future<void> actualizarRecurrente(int id, Map<String, dynamic> cuerpo) =>
      _api.put('/gastooperativo/recurrentes/$id', cuerpo: cuerpo);

  /// DELETE /api/gastooperativo/recurrentes/{id}
  Future<void> eliminarRecurrente(int id) =>
      _api.delete('/gastooperativo/recurrentes/$id');

  /// GET /api/gastooperativo/pendientes: los recurrentes que toca pagar.
  Future<List<GastoPendiente>> pendientes() async {
    final datos = await _api.get('/gastooperativo/pendientes') as List;
    return datos
        .map((e) => GastoPendiente.desdeJson(e as Map<String, dynamic>))
        .toList();
  }
}
