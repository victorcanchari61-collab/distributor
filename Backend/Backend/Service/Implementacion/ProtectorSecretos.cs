using System.Security.Cryptography;
using System.Text;

namespace Backend.Service.Implementacion;

/// <summary>
/// Cifra lo que no debe quedar legible en la base: hoy, el certificado digital (.pem) de la empresa, que lleva la
/// clave privada con la que se firman los comprobantes.
///
/// AES-256-GCM: cada valor lleva su propio nonce y una etiqueta que detecta si lo tocaron. La llave sale de
/// Facturacion:ClaveCifrado (o, si no está, de Jwt:Key). Si esa llave cambia, lo cifrado antes ya no se puede leer y
/// hay que volver a subir el certificado.
/// </summary>
public interface IProtectorSecretos
{
    string Proteger(string texto);

    /// <summary>El texto original, o nulo si no se puede leer (llave distinta, dato alterado).</summary>
    string? Desproteger(string protegido);
}

public class ProtectorSecretos : IProtectorSecretos
{
    private const string Prefijo = "v1:";
    private readonly byte[] _llave;

    public ProtectorSecretos(IConfiguration configuracion)
    {
        var semilla = configuracion["Facturacion:ClaveCifrado"];
        if (string.IsNullOrWhiteSpace(semilla)) semilla = configuracion["Jwt:Key"];
        if (string.IsNullOrWhiteSpace(semilla))
            throw new InvalidOperationException("Falta Facturacion:ClaveCifrado (o Jwt:Key) para cifrar los certificados");

        _llave = SHA256.HashData(Encoding.UTF8.GetBytes("certificados|" + semilla));
    }

    public string Proteger(string texto)
    {
        var datos = Encoding.UTF8.GetBytes(texto);
        var nonce = RandomNumberGenerator.GetBytes(AesGcm.NonceByteSizes.MaxSize);
        var cifrado = new byte[datos.Length];
        var etiqueta = new byte[AesGcm.TagByteSizes.MaxSize];

        using var aes = new AesGcm(_llave, etiqueta.Length);
        aes.Encrypt(nonce, datos, cifrado, etiqueta);

        return Prefijo + Convert.ToBase64String([.. nonce, .. etiqueta, .. cifrado]);
    }

    public string? Desproteger(string protegido)
    {
        if (!protegido.StartsWith(Prefijo, StringComparison.Ordinal)) return null;

        try
        {
            var todo = Convert.FromBase64String(protegido[Prefijo.Length..]);
            var nonceLargo = AesGcm.NonceByteSizes.MaxSize;
            var etiquetaLarga = AesGcm.TagByteSizes.MaxSize;

            var nonce = todo[..nonceLargo];
            var etiqueta = todo[nonceLargo..(nonceLargo + etiquetaLarga)];
            var cifrado = todo[(nonceLargo + etiquetaLarga)..];
            var datos = new byte[cifrado.Length];

            using var aes = new AesGcm(_llave, etiqueta.Length);
            aes.Decrypt(nonce, cifrado, etiqueta, datos);
            return Encoding.UTF8.GetString(datos);
        }
        catch (Exception e) when (e is CryptographicException or FormatException or ArgumentException)
        {
            return null;
        }
    }
}
