import '../../../core/red/cliente_api.dart';
import 'comprobante.dart';

/// Llamadas de los comprobantes electrónicos.
class ComprobantesApi {
  const ComprobantesApi(this._api);

  final ClienteApi _api;

  /// GET /api/comprobante?tipo=01. Pide el permiso `ver` de ese tipo.
  Future<List<Comprobante>> listar(String tipo) async {
    final datos = await _api.get('/comprobante?tipo=$tipo') as List;
    return datos
        .map((e) => Comprobante.desdeJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/comprobante/emitir. Factura (01) o boleta (03) de una nota de venta: la firma, la manda a SUNAT y devuelve
  /// lo que respondió.
  Future<Comprobante> emitir(int notaVentaId, String tipo) async =>
      Comprobante.desdeJson(
        await _api.post(
              '/comprobante/emitir',
              cuerpo: {'notaVentaId': notaVentaId, 'tipo': tipo},
            )
            as Map<String, dynamic>,
      );

  /// POST /api/comprobante/emitir-directo. Factura (01) o boleta (03) directa: registra la venta (que no sale en Notas de
  /// venta), descuenta el stock y emite el comprobante en un solo paso. [venta] es el cuerpo de una venta directa y no
  /// lleva recojos: el servidor los rechaza.
  Future<Comprobante> emitirDirecto(
    Map<String, dynamic> venta,
    String tipo,
  ) async => Comprobante.desdeJson(
    await _api.post(
          '/comprobante/emitir-directo',
          cuerpo: {...venta, 'tipo': tipo},
        )
        as Map<String, dynamic>,
  );

  /// POST /api/comprobante/{id}/baja. Comunicación de baja de una factura (motivo de 3 a 100 caracteres). Si SUNAT la acepta,
  /// la venta también se anula.
  Future<Comprobante> darDeBaja(int id, String motivo) async =>
      Comprobante.desdeJson(
        await _api.post('/comprobante/$id/baja', cuerpo: {'motivo': motivo})
            as Map<String, dynamic>,
      );

  /// POST /api/comprobante/{id}/baja/consultar. Pregunta a SUNAT por una baja que quedó pendiente.
  Future<Comprobante> consultarBaja(int id) async => Comprobante.desdeJson(
    await _api.post('/comprobante/$id/baja/consultar') as Map<String, dynamic>,
  );

  /// POST /api/comprobante/{id}/reenviar. Vuelve a mandar a SUNAT un comprobante que quedo sin respuesta.
  Future<Comprobante> reenviar(int id) async => Comprobante.desdeJson(
    await _api.post('/comprobante/$id/reenviar') as Map<String, dynamic>,
  );

  /// POST /api/comprobante/{id}/nota. Nota de credito (07) o debito (08) sobre un comprobante aceptado.
  Future<Comprobante> emitirNota(
    int id, {
    required String tipo,
    required String codMotivo,
    required String desMotivo,
    required List<Map<String, dynamic>> lineas,
  }) async => Comprobante.desdeJson(
    await _api.post(
          '/comprobante/$id/nota',
          cuerpo: {
            'tipo': tipo,
            'codMotivo': codMotivo,
            'desMotivo': desMotivo,
            'lineas': lineas,
          },
        )
        as Map<String, dynamic>,
  );

  /// POST /api/comprobante/{id}/whatsapp. Sin teléfono usa el del cliente.
  Future<Comprobante> enviarWhatsApp(int id, {String? telefono}) async =>
      Comprobante.desdeJson(
        await _api.post(
              '/comprobante/$id/whatsapp',
              cuerpo: {'telefono': telefono},
            )
            as Map<String, dynamic>,
      );
}
