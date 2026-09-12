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

    /// <summary>
    /// <c>?formato=ticket</c> para el rollo de 80 mm; cualquier otra cosa, A4.
    ///
    /// Un formato mal escrito da la hoja completa en vez de un error: es un
    /// documento para leer, y negarse a imprimirlo por una letra ayudaría poco
    /// a quien está despachando.
    /// </summary>
    private static FormatoPdf Formato(string? formato) =>
        string.Equals(formato, "ticket", StringComparison.OrdinalIgnoreCase)
            ? FormatoPdf.Ticket
            : FormatoPdf.A4;

    private IActionResult Archivo((byte[] Contenido, string Nombre) archivo) =>
        File(archivo.Contenido, "application/pdf", archivo.Nombre);
}
