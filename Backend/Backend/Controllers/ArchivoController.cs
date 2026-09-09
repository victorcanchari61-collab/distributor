using Backend.Dtos.Responses;
using Backend.Exceptions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Subida de imágenes: la foto de un vehículo, la de un conductor.
///
/// El archivo se guarda en disco y en la base queda solo la ruta. Meter la
/// imagen dentro de la fila haría que cada listado arrastrase megabytes aunque
/// nadie mire las fotos, y las copias de la base pasarían de segundos a
/// minutos.
///
/// Es un endpoint aparte del alta: la foto se sube al elegirla, y el
/// formulario guarda después con la ruta que devuelve. Si viajaran juntos,
/// cada corrección de un dato reenviaría la imagen entera.
/// </summary>
[ApiController]
[Route("api/archivo")]
[Authorize]
public class ArchivoController : ControllerBase
{
    /// <summary>
    /// Lo que se acepta. Lista blanca y no lista negra: con una lista negra,
    /// cualquier extensión que no se nos ocurriera hoy entraría sola.
    /// </summary>
    private static readonly Dictionary<string, string> TiposPermitidos = new()
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".webp"] = "image/webp",
    };

    /// <summary>5 MB. Una foto de teléfono cabe de sobra y no llena el disco.</summary>
    private const long TamanoMaximo = 5 * 1024 * 1024;

    private readonly IWebHostEnvironment _entorno;

    public ArchivoController(IWebHostEnvironment entorno)
    {
        _entorno = entorno;
    }

    /// <summary>
    /// Sube una imagen y devuelve su ruta.
    /// </summary>
    /// <param name="carpeta">
    /// Dónde agruparla: "vehiculos", "conductores". Se valida contra una lista
    /// para que nadie pueda escribir fuera del directorio de subidas.
    /// </param>
    [HttpPost("imagen")]
    [RequestSizeLimit(TamanoMaximo)]
    public async Task<IActionResult> SubirImagen(IFormFile archivo, [FromQuery] string carpeta = "general")
    {
        if (archivo is null || archivo.Length == 0)
            throw new BadRequestException("No llegó ningún archivo");

        if (archivo.Length > TamanoMaximo)
            throw new BadRequestException("La imagen no puede pesar más de 5 MB");

        var extension = Path.GetExtension(archivo.FileName).ToLowerInvariant();
        if (!TiposPermitidos.TryGetValue(extension, out var tipoEsperado))
            throw new BadRequestException("Solo se aceptan imágenes JPG, PNG o WEBP");

        // Se comprueba tambien lo que dice el navegador: no es una garantia,
        // pero descarta el caso tonto de renombrar un .exe a .jpg.
        if (!string.Equals(archivo.ContentType, tipoEsperado, StringComparison.OrdinalIgnoreCase))
            throw new BadRequestException("El archivo no parece una imagen");

        var destino = CarpetaSegura(carpeta);

        // Nombre nuevo, nunca el del usuario: un nombre con "../" o con el de un
        // archivo que ya existe escribiria donde no debe o pisaria otra foto.
        var nombre = $"{Guid.NewGuid():N}{extension}";

        var raiz = Path.Combine(_entorno.ContentRootPath, "wwwroot", "uploads", destino);
        Directory.CreateDirectory(raiz);

        var ruta = Path.Combine(raiz, nombre);
        await using (var stream = System.IO.File.Create(ruta))
        {
            await archivo.CopyToAsync(stream);
        }

        return Ok(new ArchivoSubidoResponse { Ruta = $"/uploads/{destino}/{nombre}" });
    }

    /// <summary>Las carpetas que existen. Cualquier otra cosa va a "general".</summary>
    private static string CarpetaSegura(string carpeta) => carpeta switch
    {
        "vehiculos" => "vehiculos",
        "conductores" => "conductores",
        _ => "general",
    };
}
