import '../../../core/red/cliente_api.dart';
import 'almacen.dart';
import 'documento_inventario.dart';
import 'kardex.dart';
import 'lote.dart';
import 'motivo.dart';
import 'prestamo.dart';
import 'stock.dart';

/// Llamadas del modulo de inventario.
class InventarioApi {
  const InventarioApi(this._api);

  final ClienteApi _api;

  // --- Almacenes ---

  /// GET /api/almacen
  Future<List<Almacen>> almacenes() async {
    final datos = await _api.get('/almacen') as List;
    return datos.map((e) => Almacen.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/almacen
  Future<Almacen> crearAlmacen(Map<String, dynamic> cuerpo) async => Almacen.desdeJson(
    await _api.post('/almacen', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/almacen/{id}
  Future<Almacen> actualizarAlmacen(int id, Map<String, dynamic> cuerpo) async =>
      Almacen.desdeJson(
        await _api.put('/almacen/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  // --- Stock ---

  /// GET /api/inventario/stock. Sin almacenId, suma todos.
  Future<List<Stock>> stock({int? almacenId}) async {
    final query = almacenId == null ? '' : '?almacenId=$almacenId';
    final datos = await _api.get('/inventario/stock$query') as List;
    return datos.map((e) => Stock.desdeJson(e as Map<String, dynamic>)).toList();
  }

  // --- Kardex ---

  /// GET /api/inventario/kardex. Sin almacenId, trae todos los movimientos.
  Future<List<MovimientoKardex>> kardex({int? almacenId}) async {
    final query = almacenId == null ? '' : '?almacenId=$almacenId';
    final datos = await _api.get('/inventario/kardex$query') as List;
    return datos
        .map((e) => MovimientoKardex.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Lotes ---

  /// GET /api/inventario/lotes
  Future<List<Lote>> lotes() async {
    final datos = await _api.get('/inventario/lotes') as List;
    return datos.map((e) => Lote.desdeJson(e as Map<String, dynamic>)).toList();
  }

  // --- Recepciones ---

  /// GET /api/inventario/recepciones
  Future<List<DocumentoInventario>> recepciones() async {
    final datos = await _api.get('/inventario/recepciones') as List;
    return datos
        .map((e) => DocumentoInventario.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/inventario/recepciones
  Future<DocumentoInventario> crearRecepcion(Map<String, dynamic> cuerpo) async =>
      DocumentoInventario.desdeJson(
        await _api.post('/inventario/recepciones', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/inventario/recepciones/{id}/anular
  Future<void> anularRecepcion(int id) async {
    await _api.patch('/inventario/recepciones/$id/anular');
  }

  // --- Ajustes ---

  /// GET /api/inventario/ajustes
  Future<List<DocumentoInventario>> ajustes() async {
    final datos = await _api.get('/inventario/ajustes') as List;
    return datos
        .map((e) => DocumentoInventario.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/inventario/ajustes
  Future<DocumentoInventario> crearAjuste(Map<String, dynamic> cuerpo) async =>
      DocumentoInventario.desdeJson(
        await _api.post('/inventario/ajustes', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/inventario/ajustes/{id}/anular. Tambien anula transferencias:
  /// es el mismo endpoint generico para cualquier documento de inventario.
  Future<void> anularAjuste(int id) async {
    await _api.patch('/inventario/ajustes/$id/anular');
  }

  // --- Motivos ---

  /// GET /api/motivo
  Future<List<Motivo>> motivos() async {
    final datos = await _api.get('/motivo') as List;
    return datos.map((e) => Motivo.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/motivo
  Future<Motivo> crearMotivo(Map<String, dynamic> cuerpo) async => Motivo.desdeJson(
    await _api.post('/motivo', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/motivo/{id}
  Future<Motivo> actualizarMotivo(int id, Map<String, dynamic> cuerpo) async =>
      Motivo.desdeJson(
        await _api.put('/motivo/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// DELETE /api/motivo/{id}
  Future<void> eliminarMotivo(int id) async {
    await _api.delete('/motivo/$id');
  }

  // --- Transferencias ---

  /// GET /api/inventario/transferencias
  Future<List<DocumentoInventario>> transferencias() async {
    final datos = await _api.get('/inventario/transferencias') as List;
    return datos
        .map((e) => DocumentoInventario.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/inventario/transferencias
  Future<DocumentoInventario> crearTransferencia(Map<String, dynamic> cuerpo) async =>
      DocumentoInventario.desdeJson(
        await _api.post('/inventario/transferencias', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  // --- Prestamos ---

  /// GET /api/inventario/prestamos
  Future<List<Prestamo>> prestamos() async {
    final datos = await _api.get('/inventario/prestamos') as List;
    return datos.map((e) => Prestamo.desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/inventario/prestamos
  Future<Prestamo> crearPrestamo(Map<String, dynamic> cuerpo) async => Prestamo.desdeJson(
    await _api.post('/inventario/prestamos', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// POST /api/inventario/prestamos/{id}/devolucion
  Future<Prestamo> registrarDevolucion(int id, Map<String, dynamic> cuerpo) async =>
      Prestamo.desdeJson(
        await _api.post('/inventario/prestamos/$id/devolucion', cuerpo: cuerpo)
            as Map<String, dynamic>,
      );
}
