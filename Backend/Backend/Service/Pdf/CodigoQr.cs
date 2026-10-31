using QRCoder;

namespace Backend.Service.Pdf;

/// <summary>El código QR que lleva la representación impresa de un comprobante electrónico.</summary>
public static class CodigoQr
{
    /// <summary>El QR como imagen PNG. Nivel de corrección Q: el que pide SUNAT para estos comprobantes.</summary>
    public static byte[] Png(string texto)
    {
        using var generador = new QRCodeGenerator();
        using var datos = generador.CreateQrCode(texto, QRCodeGenerator.ECCLevel.Q);
        return new PngByteQRCode(datos).GetGraphic(10);
    }
}
