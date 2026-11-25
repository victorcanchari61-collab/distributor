import '../../../core/red/cliente_api.dart';
import 'compra.dart';
import 'devolucion_proveedor.dart';
import 'orden_compra.dart';
import 'solicitud_compra.dart';

/// Llamadas del modulo de compras.
class ComprasApi {
  const ComprasApi(this._api);

  final ClienteApi _api;

  // --- Solicitudes de compra ---

  /// GET /api/solicitudcompra. Sin las lineas: se piden al abrir una.
  Future<List<SolicitudCompra>> solicitudesCompra() async {
    final datos = await _api.get('/solicitudcompra') as List;
    return datos
        .map((e) => SolicitudCompra.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/solicitudcompra/{id}. Con sus lineas.
  Future<SolicitudCompra> solicitudCompra(int id) async =>
      SolicitudCompra.desdeJson(
        await _api.get('/solicitudcompra/$id') as Map<String, dynamic>,
      );

  /// GET /api/solicitudcompra/sugerencias. Lo que esta bajo el minimo en el almacen.
  Future<List<SugerenciaSolicitud>> sugerenciasSolicitud(int almacenId) async {
    final datos =
        await _api.get('/solicitudcompra/sugerencias?almacenId=$almacenId')
            as List;
    return datos
        .map((e) => SugerenciaSolicitud.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/solicitudcompra
  Future<SolicitudCompra> crearSolicitudCompra(
    Map<String, dynamic> cuerpo,
  ) async => SolicitudCompra.desdeJson(
    await _api.post('/solicitudcompra', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PUT /api/solicitudcompra/{id}. Solo mientras esta Pendiente.
  Future<SolicitudCompra> actualizarSolicitudCompra(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => SolicitudCompra.desdeJson(
    await _api.put('/solicitudcompra/$id', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  /// POST /api/solicitudcompra/{id}/enviar. Del borrador al administrador.
  Future<SolicitudCompra> enviarSolicitudCompra(int id) async =>
      SolicitudCompra.desdeJson(
        await _api.post('/solicitudcompra/$id/enviar') as Map<String, dynamic>,
      );

  /// DELETE /api/solicitudcompra/{id}. Quien la pidio la retira: borrador o Pendiente.
  Future<void> anularSolicitudCompra(int id) async {
    await _api.delete('/solicitudcompra/$id');
  }

  // --- Ordenes de compra ---

  /// GET /api/ordencompra
  Future<List<OrdenCompra>> ordenesCompra() async {
    final datos = await _api.get('/ordencompra') as List;
    return datos
        .map((e) => OrdenCompra.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/ordencompra
  Future<OrdenCompra> crearOrdenCompra(Map<String, dynamic> cuerpo) async =>
      OrdenCompra.desdeJson(
        await _api.post('/ordencompra', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/ordencompra/{id}. Solo mientras esta Pendiente.
  Future<OrdenCompra> actualizarOrdenCompra(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => OrdenCompra.desdeJson(
    await _api.put('/ordencompra/$id', cuerpo: cuerpo) as Map<String, dynamic>,
  );

  /// PATCH /api/ordencompra/{id}/confirmar. Cierra la orden y crea la Compra.
  Future<OrdenCompra> confirmarOrdenCompra(int id) async =>
      OrdenCompra.desdeJson(
        await _api.patch('/ordencompra/$id/confirmar') as Map<String, dynamic>,
      );

  /// POST /api/ordencompra/{id}/convertir. Como un pedido a venta: cierra la
  /// orden y crea su compra con lo revisado (cantidades, costos, comprobante
  /// y pagos).
  Future<Compra> convertirOrdenCompra(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Compra.desdeJson(
    await _api.post('/ordencompra/$id/convertir', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  /// PATCH /api/ordencompra/{id}/anular
  Future<void> anularOrdenCompra(int id) async {
    await _api.patch('/ordencompra/$id/anular');
  }

  // --- Compras ---

  /// GET /api/compra
  Future<List<Compra>> compras() async {
    final datos = await _api.get('/compra') as List;
    return datos
        .map((e) => Compra.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/compra. Directa, sin orden previa: al contado, en el momento.
  Future<Compra> crearCompra(Map<String, dynamic> cuerpo) async =>
      Compra.desdeJson(
        await _api.post('/compra', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PUT /api/compra/{id}. Solo mientras esta Pendiente: sin nada recibido.
  Future<Compra> actualizarCompra(int id, Map<String, dynamic> cuerpo) async =>
      Compra.desdeJson(
        await _api.put('/compra/$id', cuerpo: cuerpo) as Map<String, dynamic>,
      );

  /// PATCH /api/compra/{id}/anular. Solo si nada se ha recibido.
  Future<void> anularCompra(int id) async {
    await _api.patch('/compra/$id/anular');
  }

  // --- Cuentas por pagar / pagos ---

  /// GET /api/compra/cuentasporpagar
  Future<List<Compra>> cuentasPorPagar() async {
    final datos = await _api.get('/compra/cuentasporpagar') as List;
    return datos
        .map((e) => Compra.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/compra/{id}/pagos
  Future<Compra> registrarPagoCompra(
    int id,
    Map<String, dynamic> cuerpo,
  ) async => Compra.desdeJson(
    await _api.post('/compra/$id/pagos', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  /// PUT /api/compra/{id}/pagos/{pagoId}
  Future<Compra> actualizarPagoCompra(
    int id,
    int pagoId,
    Map<String, dynamic> cuerpo,
  ) async => Compra.desdeJson(
    await _api.put('/compra/$id/pagos/$pagoId', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  /// DELETE /api/compra/{id}/pagos/{pagoId} — anula, no borra.
  Future<Compra> anularPagoCompra(int id, int pagoId) async => Compra.desdeJson(
    await _api.delete('/compra/$id/pagos/$pagoId') as Map<String, dynamic>,
  );

  /// POST /api/compra/{id}/saldo-favor — paga con el saldo a favor que se
  /// tiene con el proveedor: no mueve plata.
  Future<Compra> aplicarSaldoFavor(int id, double monto) async =>
      Compra.desdeJson(
        await _api.post('/compra/$id/saldo-favor', cuerpo: {'monto': monto})
            as Map<String, dynamic>,
      );

  // --- Devoluciones a proveedor ---

  /// GET /api/devolucion-proveedor — las mas nuevas primero.
  Future<List<DevolucionProveedor>> devolucionesProveedor() async {
    final datos = await _api.get('/devolucion-proveedor') as List;
    return datos
        .map((e) => DevolucionProveedor.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/devolucion-proveedor
  Future<DevolucionProveedor> crearDevolucionProveedor(
    Map<String, dynamic> cuerpo,
  ) async => DevolucionProveedor.desdeJson(
    await _api.post('/devolucion-proveedor', cuerpo: cuerpo)
        as Map<String, dynamic>,
  );

  /// PATCH /api/devolucion-proveedor/{id}/anular
  Future<void> anularDevolucionProveedor(int id) async {
    await _api.patch('/devolucion-proveedor/$id/anular');
  }

  /// GET /api/devolucion-proveedor/saldos — los proveedores que deben plata.
  Future<List<SaldoFavorProveedor>> saldosFavor() async {
    final datos = await _api.get('/devolucion-proveedor/saldos') as List;
    return datos
        .map((e) => SaldoFavorProveedor.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/devolucion-proveedor/saldos/{proveedorId}
  Future<double> saldoFavor(int proveedorId) async {
    final datos =
        await _api.get('/devolucion-proveedor/saldos/$proveedorId')
            as Map<String, dynamic>;
    return (datos['saldo'] as num?)?.toDouble() ?? 0;
  }
}
