namespace Backend.Service.Interfaces;

/// <summary>En qué papel se va a imprimir.</summary>
public enum FormatoPdf
{
    /// <summary>Hoja completa, impresora de oficina.</summary>
    A4,

    /// <summary>Rollo térmico de 80 mm, el del reparto.</summary>
    Ticket,
}

/// <summary>
/// Los documentos en PDF.
///
/// Vive en el backend y no en cada pantalla a propósito: la web y el móvil
/// piden el mismo archivo al mismo sitio. Generarlo en el cliente obligaría a
/// escribir la maqueta dos veces, en TypeScript y en Dart, y el día que una
/// sume distinto de la otra habría dos papeles con el mismo número y distinto
/// total.
/// </summary>
public interface IPdfService
{
    Task<(byte[] Contenido, string Nombre)> PedidoAsync(int id, FormatoPdf formato);
    Task<(byte[] Contenido, string Nombre)> NotaVentaAsync(int id, FormatoPdf formato);
    Task<(byte[] Contenido, string Nombre)> OrdenCompraAsync(int id, FormatoPdf formato);
    Task<(byte[] Contenido, string Nombre)> CompraAsync(int id, FormatoPdf formato);
}
