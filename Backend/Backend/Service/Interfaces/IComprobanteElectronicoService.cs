using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>
/// Facturación electrónica: emite facturas, boletas y notas de crédito y débito, las firma y las manda a SUNAT
/// (a través de la API de facturación), y guarda el XML y el CDR para descargarlos.
/// </summary>
public interface IComprobanteElectronicoService
{
    /// <summary>Los comprobantes, el más nuevo primero. Todos los filtros son opcionales.</summary>
    Task<List<ComprobanteResponse>> ListarAsync(
        IReadOnlyCollection<string> tipos, string? estado, DateTime? desde, DateTime? hasta, int? notaVentaId, int? afectadoId);

    /// <summary>El tipo (01, 03, 07, 08) de un comprobante: de ahí sale el permiso que se le pide a quien lo toca.</summary>
    Task<string> TipoAsync(int id);

    Task<ComprobanteResponse> GetAsync(int id);

    /// <summary>Factura o boleta de una nota de venta. La firma, la envía a SUNAT y guarda lo que respondió.</summary>
    Task<ComprobanteResponse> EmitirAsync(EmitirComprobanteRequest request);

    /// <summary>Nota de crédito o débito sobre un comprobante aceptado.</summary>
    Task<ComprobanteResponse> EmitirNotaAsync(int afectadoId, EmitirNotaRequest request);

    /// <summary>Vuelve a mandar a SUNAT un comprobante que quedó sin respuesta (Generado o Error).</summary>
    Task<ComprobanteResponse> ReenviarAsync(int id);

    /// <summary>El XML firmado, con el nombre con el que se descarga.</summary>
    Task<(byte[] Contenido, string Nombre)> DescargarXmlAsync(int id);

    /// <summary>El zip del CDR que devolvió SUNAT.</summary>
    Task<(byte[] Contenido, string Nombre)> DescargarCdrAsync(int id);
}
