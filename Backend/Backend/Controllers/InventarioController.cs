using System.Security.Claims;
using Backend.Dtos.Requests;
using Backend.Filters;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AlmacenController : ControllerBase
{
    private readonly IInventarioService _inventario;

    public AlmacenController(IInventarioService inventario)
    {
        _inventario = inventario;
    }

    [HttpGet]
    [Permiso("inv.almacenes", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _inventario.GetAlmacenesAsync());

    /// <summary>
    /// Los almacenes activos, solo para elegir uno.
    ///
    /// Los usa quien vende y quien compra —de dónde sale el pedido, a dónde
    /// entra la compra— sin tener acceso a la pantalla de Almacenes. Por eso va
    /// sin lo que esa pantalla muestra: ni el valorizado ni cuántos productos
    /// tiene cada uno, que es plata y no hace falta para elegir.
    /// </summary>
    [HttpGet("opciones")]
    [PermisoAlguno(
        "inv.almacenes:ver", "inv.stock:ver", "inv.kardex:ver",
        "fact.pedidos:ver", "fact.notaventa:ver",
        "compras.compras:ver", "compras.ordenes:ver", "compras.recepciones:ver")]
    public async Task<IActionResult> Opciones() =>
        Ok((await _inventario.GetAlmacenesAsync())
            .Where(a => a.Activo)
            .Select(a => new { a.Id, a.Codigo, a.Nombre, a.EsPrincipal, a.Activo }));

    [HttpGet("{id:int}")]
    [Permiso("inv.almacenes", Accion.Ver)]
    public async Task<IActionResult> GetById(int id) => Ok(await _inventario.GetAlmacenAsync(id));

    [HttpPost]
    [Permiso("inv.almacenes", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateAlmacenRequest request)
    {
        var response = await _inventario.CreateAlmacenAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = response.Id }, response);
    }

    [HttpPut("{id:int}")]
    [Permiso("inv.almacenes", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateAlmacenRequest request) =>
        Ok(await _inventario.UpdateAlmacenAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("inv.almacenes", Accion.Eliminar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _inventario.DeleteAlmacenAsync(id);
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MotivoController : ControllerBase
{
    private readonly IInventarioService _inventario;

    public MotivoController(IInventarioService inventario)
    {
        _inventario = inventario;
    }

    /// <summary>
    /// Todos los motivos. Los del sistema vienen marcados: la pantalla no los
    /// ofrece al hacer un ajuste.
    /// </summary>
    [HttpGet]
    [Permiso("inv.ajustes", Accion.Ver)]
    public async Task<IActionResult> GetAll() => Ok(await _inventario.GetMotivosAsync());

    [HttpPost]
    [Permiso("inv.ajustes", Accion.Crear)]
    public async Task<IActionResult> Create([FromBody] CreateMotivoRequest request) =>
        Ok(await _inventario.CreateMotivoAsync(request));

    [HttpPut("{id:int}")]
    [Permiso("inv.ajustes", Accion.Editar)]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateMotivoRequest request) =>
        Ok(await _inventario.UpdateMotivoAsync(id, request));

    [HttpDelete("{id:int}")]
    [Permiso("inv.ajustes", Accion.Editar)]
    public async Task<IActionResult> Delete(int id)
    {
        await _inventario.DeleteMotivoAsync(id);
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class InventarioController : ControllerBase
{
    private readonly IInventarioService _inventario;
    private readonly IPermisoService _permisos;

    public InventarioController(IInventarioService inventario, IPermisoService permisos)
    {
        _inventario = inventario;
        _permisos = permisos;
    }

    /// <summary>Quién registra el documento, tomado del token.</summary>
    private int? UsuarioId =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier)
                     ?? User.FindFirstValue("sub"), out var id)
            ? id
            : null;

    /// <summary>Stock de todos los productos. Sin almacén, suma todos.</summary>
    [HttpGet("stock")]
    [Permiso("inv.stock", Accion.Ver)]
    public async Task<IActionResult> Stock([FromQuery] int? almacenId) =>
        Ok(await _inventario.GetStockAsync(almacenId));

    /// <summary>
    /// Cuánto se puede prometer de cada producto: el stock menos lo reservado.
    ///
    /// Es lo único que necesita quien toma un pedido o arma una compra, y se lo
    /// daba <c>/stock</c>, que además trae costos y valorizado. Detrás de
    /// <c>inv.stock</c> un vendedor sin Inventario recibía un 403 que nadie
    /// mostraba, y veía todos los productos con stock 0. Aquí va solo el número,
    /// sin plata, y lo puede leer cualquiera que venda o compre.
    /// </summary>
    [HttpGet("disponible")]
    [PermisoAlguno(
        "inv.stock:ver",
        "fact.pedidos:ver", "fact.notaventa:ver",
        "compras.compras:ver", "compras.ordenes:ver",
        "inv.ajustes:ver", "inv.transferencias:ver", "inv.prestamos:ver")]
    public async Task<IActionResult> Disponible([FromQuery] int? almacenId) =>
        Ok(await _inventario.GetDisponibleAsync(almacenId));

    /// <summary>Stock y capas de costo de un producto.</summary>
    [HttpGet("stock/{productoId:int}")]
    [Permiso("inv.stock", Accion.Ver)]
    public async Task<IActionResult> StockProducto(int productoId, [FromQuery] int? almacenId) =>
        Ok(await _inventario.GetStockProductoAsync(productoId, almacenId));

    /// <summary>Todo lo que tiene fecha de vencimiento y todavía tiene stock, lo más próximo primero.</summary>
    [HttpGet("lotes")]
    [Permiso("inv.lotes", Accion.Ver)]
    public async Task<IActionResult> Lotes() => Ok(await _inventario.GetLotesAsync());

    /// <summary>Una página del stock, con búsqueda, filtros y orden en la base.</summary>
    [HttpPost("stock/listar")]
    [Permiso("inv.stock", Accion.Ver)]
    public async Task<IActionResult> ListarStock(
        [FromBody] ConsultaTablaRequest consulta, [FromQuery] int? almacenId) =>
        Ok(await _inventario.ListarStockAsync(consulta, almacenId));

    /// <summary>Totales del stock de todo el catálogo.</summary>
    [HttpGet("stock/resumen")]
    [Permiso("inv.stock", Accion.Ver)]
    public async Task<IActionResult> ResumenStock([FromQuery] int? almacenId) =>
        Ok(await _inventario.GetResumenStockAsync(almacenId));

    /// <summary>Una página de documentos de una familia (ajustes, transferencias, recepciones).</summary>
    // El permiso depende de la familia: Recepciones no es Ajustes. Antes todo
    // pedía inv.ajustes, así que quien solo recibía mercadería no veía la lista.
    [HttpPost("documentos/listar")]
    [PermisoAlguno("inv.ajustes:ver", "inv.transferencias:ver", "compras.recepciones:ver")]
    public async Task<IActionResult> ListarDocumentos(
        [FromBody] ConsultaTablaRequest consulta, [FromQuery] string? familia) =>
        await PuedeVerFamiliaAsync(familia)
            ? Ok(await _inventario.ListarDocumentosAsync(consulta, familia))
            : Forbid();

    /// <summary>Contadores del listado completo de esa familia.</summary>
    [HttpGet("documentos/resumen")]
    [PermisoAlguno("inv.ajustes:ver", "inv.transferencias:ver", "compras.recepciones:ver")]
    public async Task<IActionResult> ResumenDocumentos([FromQuery] string? familia) =>
        await PuedeVerFamiliaAsync(familia)
            ? Ok(await _inventario.GetResumenDocumentosAsync(familia))
            : Forbid();

    /// <summary>El submódulo que da permiso para ver esa familia de documentos.</summary>
    private async Task<bool> PuedeVerFamiliaAsync(string? familia)
    {
        var submodulo = familia switch
        {
            TipoDocumentoInventario.Recepcion => "compras.recepciones",
            TipoDocumentoInventario.Transferencia => "inv.transferencias",
            _ => "inv.ajustes",
        };
        return UsuarioId is int id && await _permisos.PuedeAsync(id, submodulo, Accion.Ver);
    }

    /// <summary>Contadores del listado completo de préstamos.</summary>
    [HttpGet("prestamos/resumen")]
    [Permiso("inv.prestamos", Accion.Ver)]
    public async Task<IActionResult> ResumenPrestamos() => Ok(await _inventario.GetResumenPrestamosAsync());

    /// <summary>Una página del listado de préstamos.</summary>
    [HttpPost("prestamos/listar")]
    [Permiso("inv.prestamos", Accion.Ver)]
    public async Task<IActionResult> ListarPrestamos([FromBody] ConsultaTablaRequest consulta) =>
        Ok(await _inventario.ListarPrestamosAsync(consulta));

    /// <summary>Una página del kardex, con búsqueda, filtros y orden resueltos en la base.</summary>
    [HttpPost("kardex/listar")]
    [Permiso("inv.kardex", Accion.Ver)]
    public async Task<IActionResult> ListarKardex(
        [FromBody] ConsultaTablaRequest consulta, [FromQuery] int? almacenId) =>
        Ok(await _inventario.ListarKardexAsync(consulta, almacenId));

    /// <summary>Contadores del kardex completo del almacén.</summary>
    [HttpGet("kardex/resumen")]
    [Permiso("inv.kardex", Accion.Ver)]
    public async Task<IActionResult> ResumenKardex([FromQuery] int? almacenId) =>
        Ok(await _inventario.GetResumenKardexAsync(almacenId));

    /// <summary>Kardex: todo lo que entró y salió, con el saldo que dejó.</summary>
    [HttpGet("kardex")]
    [Permiso("inv.kardex", Accion.Ver)]
    public async Task<IActionResult> Kardex(
        [FromQuery] int? productoId,
        [FromQuery] int? almacenId,
        [FromQuery] DateTime? desde,
        [FromQuery] DateTime? hasta) =>
        Ok(await _inventario.GetKardexAsync(productoId, almacenId, desde, hasta));

    // --- Ajustes ---

    [HttpGet("ajustes")]
    [Permiso("inv.ajustes", Accion.Ver)]
    public async Task<IActionResult> Ajustes() =>
        Ok(await _inventario.GetDocumentosAsync(TipoDocumentoInventario.Ajuste));

    [HttpGet("ajustes/{id:int}")]
    [Permiso("inv.ajustes", Accion.Ver)]
    public async Task<IActionResult> Ajuste(int id) => Ok(await _inventario.GetDocumentoAsync(id));

    /// <summary>Registra el ajuste y mueve el stock. Todo o nada.</summary>
    [HttpPost("ajustes")]
    [Permiso("inv.ajustes", Accion.Crear)]
    public async Task<IActionResult> CrearAjuste([FromBody] CrearAjusteRequest request) =>
        Ok(await _inventario.CrearAjusteAsync(request, UsuarioId));

    /// <summary>
    /// Crea el documento espejo que deshace otro (ajuste o transferencia). No
    /// borra nada: el historial queda entero.
    /// </summary>
    [HttpPatch("ajustes/{id:int}/anular")]
    [Permiso("inv.ajustes", Accion.Anular)]
    public async Task<IActionResult> Anular(int id) =>
        Ok(await _inventario.AnularAsync(id, UsuarioId));

    // --- Transferencias ---

    [HttpGet("transferencias")]
    [Permiso("inv.transferencias", Accion.Ver)]
    public async Task<IActionResult> Transferencias() =>
        Ok(await _inventario.GetDocumentosAsync(TipoDocumentoInventario.Transferencia));

    [HttpGet("transferencias/{id:int}")]
    [Permiso("inv.transferencias", Accion.Ver)]
    public async Task<IActionResult> Transferencia(int id) =>
        Ok(await _inventario.GetDocumentoAsync(id));

    /// <summary>Mueve mercadería entre dos almacenes propios. El costo viaja con ella.</summary>
    [HttpPost("transferencias")]
    [Permiso("inv.transferencias", Accion.Crear)]
    public async Task<IActionResult> CrearTransferencia([FromBody] CrearTransferenciaRequest request) =>
        Ok(await _inventario.CrearTransferenciaAsync(request, UsuarioId));

    // --- Prestamos ---

    [HttpGet("prestamos")]
    [Permiso("inv.prestamos", Accion.Ver)]
    public async Task<IActionResult> Prestamos() => Ok(await _inventario.GetPrestamosAsync());

    [HttpGet("prestamos/{id:int}")]
    [Permiso("inv.prestamos", Accion.Ver)]
    public async Task<IActionResult> Prestamo(int id) => Ok(await _inventario.GetPrestamoAsync(id));

    /// <summary>Registra el préstamo: sale mercadería propia o entra la de un tercero.</summary>
    [HttpPost("prestamos")]
    [Permiso("inv.prestamos", Accion.Crear)]
    public async Task<IActionResult> CrearPrestamo([FromBody] CrearPrestamoRequest request) =>
        Ok(await _inventario.CrearPrestamoAsync(request, UsuarioId));

    /// <summary>Registra una devolución, total o parcial, de un préstamo.</summary>
    [HttpPost("prestamos/{id:int}/devolucion")]
    [Permiso("inv.prestamos", Accion.Confirmar)]
    public async Task<IActionResult> DevolverPrestamo(
        int id, [FromBody] DevolverPrestamoRequest request) =>
        Ok(await _inventario.DevolverPrestamoAsync(id, request, UsuarioId));

    /// <summary>
    /// Anula una devolución registrada por error (cantidad equivocada, por
    /// ejemplo): revierte el stock y la línea del préstamo vuelve a quedar
    /// pendiente por esa cantidad. El id es el del documento de la devolución,
    /// no el del préstamo.
    /// </summary>
    [HttpPatch("prestamos/devoluciones/{id:int}/anular")]
    [Permiso("inv.prestamos", Accion.Anular)]
    public async Task<IActionResult> AnularDevolucionPrestamo(int id) =>
        Ok(await _inventario.AnularAsync(id, UsuarioId));

    /// <summary>
    /// Anula el préstamo completo: revierte el stock que movió al registrarse
    /// y lo marca Anulado. Se bloquea si ya tiene alguna devolución registrada.
    /// </summary>
    [HttpPatch("prestamos/{id:int}/anular")]
    [Permiso("inv.prestamos", Accion.Anular)]
    public async Task<IActionResult> AnularPrestamo(int id) =>
        Ok(await _inventario.AnularPrestamoAsync(id, UsuarioId));

    // --- Recepciones ---

    [HttpGet("recepciones")]
    [Permiso("compras.recepciones", Accion.Ver)]
    public async Task<IActionResult> Recepciones() =>
        Ok(await _inventario.GetDocumentosAsync(TipoDocumentoInventario.Recepcion));

    [HttpGet("recepciones/{id:int}")]
    [Permiso("compras.recepciones", Accion.Ver)]
    public async Task<IActionResult> Recepcion(int id) => Ok(await _inventario.GetDocumentoAsync(id));

    /// <summary>Registra que llegó mercadería de una compra, total o parcialmente.</summary>
    [HttpPost("recepciones")]
    [Permiso("compras.recepciones", Accion.Crear)]
    public async Task<IActionResult> CrearRecepcion([FromBody] CrearRecepcionRequest request) =>
        Ok(await _inventario.CrearRecepcionAsync(request, UsuarioId));

    /// <summary>Reutiliza el mismo endpoint genérico que Ajustes/Transferencias.</summary>
    [HttpPatch("recepciones/{id:int}/anular")]
    [Permiso("compras.recepciones", Accion.Anular)]
    public async Task<IActionResult> AnularRecepcion(int id) =>
        Ok(await _inventario.AnularAsync(id, UsuarioId));
}
