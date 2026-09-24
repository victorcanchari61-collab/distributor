using System.Text.Json;
using Backend.Dtos.Requests;
using Backend.Exceptions;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

/// <summary>
/// Los documentos en PDF.
///
/// Están juntos en un controlador y no repartidos por Pedido, NotaVenta,
/// OrdenCompra y Compra porque son la misma operación cuatro veces; las rutas
/// sí quedan donde se esperan (<c>api/pedido/3/pdf</c>), que es lo que mira
/// quien consume la API.
///
/// Cada uno pide la acción <c>exportar</c> de su submódulo: sacar el documento
/// en papel es llevarse los datos fuera del sistema, igual que descargar el
/// listado, y ya existe esa acción en el catálogo.
/// </summary>
[ApiController]
[Authorize]
public class PdfController(IPdfService pdf) : ControllerBase
{
    [HttpGet("api/pedido/{id:int}/pdf")]
    [Permiso("fact.pedidos", Accion.Exportar)]
    public async Task<IActionResult> Pedido(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.PedidoAsync(id, Formato(formato)));

    [HttpGet("api/notaventa/{id:int}/pdf")]
    [Permiso("fact.notaventa", Accion.Exportar)]
    public async Task<IActionResult> NotaVenta(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.NotaVentaAsync(id, Formato(formato)));

    [HttpGet("api/ordencompra/{id:int}/pdf")]
    [Permiso("compras.ordenes", Accion.Exportar)]
    public async Task<IActionResult> OrdenCompra(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.OrdenCompraAsync(id, Formato(formato)));

    [HttpGet("api/compra/{id:int}/pdf")]
    [Permiso("compras.compras", Accion.Exportar)]
    public async Task<IActionResult> Compra(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.CompraAsync(id, Formato(formato)));

    /// <summary>Los pedidos de un despacho: los papeles que se lleva el repartidor.</summary>
    [HttpGet("api/despacho/{id:int}/pdf")]
    [Permiso("tms.despachos", Accion.Exportar)]
    public async Task<IActionResult> Despacho(int id) => Archivo(await pdf.DespachoAsync(id));

    /// <summary>Detalle por cliente del camión, en el orden de la ruta.</summary>
    [HttpGet("api/despacho/{id:int}/pdf/clientes")]
    [Permiso("tms.despachos", Accion.Exportar)]
    public async Task<IActionResult> DetalleClientesDespacho(int id) =>
        Archivo(await pdf.DetalleClientesDespachoAsync(id));

    /// <summary>Qué productos hay que subir al camión.</summary>
    [HttpGet("api/despacho/{id:int}/pdf/carga")]
    [Permiso("tms.despachos", Accion.Exportar)]
    public async Task<IActionResult> CargaDespacho(
        int id,
        [FromQuery] string? mercados,
        [FromQuery] string? unidades,
        [FromQuery] bool porMercado = false,
        [FromQuery] int? corte = null) =>
        Archivo(await pdf.CargaDespachoAsync(
            id,
            // "1,7,11": lo que manda el modal de filtros.
            mercados?.Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(x => int.TryParse(x, out var n) ? n : -1).Where(n => n >= 0).ToList(),
            unidades?.Split(',', StringSplitOptions.RemoveEmptyEntries).ToList(),
            porMercado,
            corte));

    /// <summary>
    /// Las novedades de entrega, con los mismos filtros de la pantalla.
    ///
    /// Los filtros viajan como el JSON de la consulta de la tabla en un solo
    /// parámetro: son una lista de columna, operador y valor, y armar un
    /// parámetro por columna sería tener que enseñarle al servidor cada uno.
    /// </summary>
    [HttpGet("api/novedad/pdf")]
    [Permiso("tms.novedades", Accion.Exportar)]
    public async Task<IActionResult> Novedades([FromQuery] string? consulta) =>
        Archivo(await pdf.NovedadesAsync(ConsultaDe(consulta)));

    private static ConsultaTablaRequest ConsultaDe(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new ConsultaTablaRequest();

        try
        {
            return JsonSerializer.Deserialize<ConsultaTablaRequest>(
                       json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                   ?? new ConsultaTablaRequest();
        }
        catch (JsonException)
        {
            throw new BadRequestException("Los filtros del reporte no se entienden.");
        }
    }

    /*
     * Los cuatro documentos de inventario viven en la misma tabla y comparten
     * numeración de id, pero cada uno pide el permiso de SU submódulo. Por eso
     * hay una ruta por tipo en vez de una sola con el id: con una ruta única no
     * habría forma de saber qué permiso exigir antes de leer el documento, y el
     * servicio comprueba además que el id sea del tipo que la ruta promete.
     */

    [HttpGet("api/inventario/ajustes/{id:int}/pdf")]
    [Permiso("inv.ajustes", Accion.Exportar)]
    public async Task<IActionResult> Ajuste(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.AjusteAsync(id, Formato(formato)));

    [HttpGet("api/inventario/transferencias/{id:int}/pdf")]
    [Permiso("inv.transferencias", Accion.Exportar)]
    public async Task<IActionResult> Transferencia(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.TransferenciaAsync(id, Formato(formato)));

    [HttpGet("api/inventario/recepciones/{id:int}/pdf")]
    [Permiso("compras.recepciones", Accion.Exportar)]
    public async Task<IActionResult> Recepcion(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.RecepcionAsync(id, Formato(formato)));

    [HttpGet("api/inventario/prestamos/{id:int}/pdf")]
    [Permiso("inv.prestamos", Accion.Exportar)]
    public async Task<IActionResult> Prestamo(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.PrestamoAsync(id, Formato(formato)));

    [HttpGet("api/inventario/prestamos/devoluciones/{id:int}/pdf")]
    [Permiso("inv.prestamos", Accion.Exportar)]
    public async Task<IActionResult> DevolucionPrestamo(int id, [FromQuery] string? formato) =>
        Archivo(await pdf.DevolucionPrestamoAsync(id, Formato(formato)));

    /// <summary>
    /// <c>?formato=ticket</c> para el rollo de 80 mm; cualquier otra cosa, A4.
    ///
    /// Un formato mal escrito da la hoja completa en vez de un error: es un
    /// documento para leer, y negarse a imprimirlo por una letra ayudaría poco
    /// a quien está despachando.
    /// </summary>
    private static FormatoPdf Formato(string? formato) => formato?.ToLowerInvariant() switch
    {
        "ticket" => FormatoPdf.Ticket,
        "copias" => FormatoPdf.Copias,
        _ => FormatoPdf.A4,
    };

    private IActionResult Archivo((byte[] Contenido, string Nombre) archivo) =>
        File(archivo.Contenido, "application/pdf", archivo.Nombre);
}
