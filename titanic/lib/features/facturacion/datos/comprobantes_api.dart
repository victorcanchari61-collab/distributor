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
