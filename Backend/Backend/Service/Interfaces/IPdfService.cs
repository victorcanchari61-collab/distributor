using Backend.Dtos.Requests;

namespace Backend.Service.Interfaces;

/// <summary>En qué papel se va a imprimir.</summary>
public enum FormatoPdf
{
    /// <summary>Hoja completa, impresora de oficina.</summary>
    A4,

    /// <summary>Rollo térmico de 80 mm, el del reparto.</summary>
    Ticket,

    /// <summary>
    /// Hoja apaisada con las dos copias, original y copia, para cortar por el
    /// medio. Solo aplica a los pedidos: es el papel que se entrega y que hay
    /// que reponer cuando el repartidor lo pierde.
    /// </summary>
    Copias,
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

    /// <summary>Los pedidos de un despacho, listos para dárselos al repartidor.</summary>
    Task<(byte[] Contenido, string Nombre)> DespachoAsync(int id);

    /// <summary>
    /// Detalle por cliente del camión: a quién se entrega y cuánto se cobra,
    /// en el orden en que se recorre la ruta.
    /// </summary>
    Task<(byte[] Contenido, string Nombre)> DetalleClientesDespachoAsync(int id);

    /// <summary>Qué productos hay que subir al camión, sumados de todos sus pedidos.</summary>
    /// <param name="mercados">Ids de mercado; vacío es todos. 0 es "sin mercado".</param>
    /// <param name="unidades">Códigos de unidad de medida (BOL, SAC); vacío es todas.</param>
    /// <param name="porMercado">Un bloque por mercado en vez de todo sumado.</param>
    /// <param name="corte">
    /// 1, 2 o 3 para sacar un corte de horario (base, primer aumento, segundo
    /// aumento); vacío es todo el camión.
    /// </param>
    Task<(byte[] Contenido, string Nombre)> CargaDespachoAsync(
        int id, IReadOnlyCollection<int>? mercados, IReadOnlyCollection<string>? unidades, bool porMercado,
        int? corte = null);

    /// <summary>
    /// Las novedades de entrega —lo que no llegó al cliente y por qué—, con los
    /// mismos filtros y el mismo orden que ve la pantalla.
    /// </summary>
    Task<(byte[] Contenido, string Nombre)> NovedadesAsync(ConsultaTablaRequest consulta);

    Task<(byte[] Contenido, string Nombre)> AjusteAsync(int id, FormatoPdf formato);
    Task<(byte[] Contenido, string Nombre)> TransferenciaAsync(int id, FormatoPdf formato);
    Task<(byte[] Contenido, string Nombre)> RecepcionAsync(int id, FormatoPdf formato);
    Task<(byte[] Contenido, string Nombre)> PrestamoAsync(int id, FormatoPdf formato);
}
