using Backend.Models;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Interfaces;

/// <summary>Lo que se muestra de un producto sin abrir sus capas.</summary>
public record ResumenStock(decimal Stock, decimal Valorizado, decimal CostoMin, decimal CostoMax);

/// <summary>
/// Como se ha movido un producto: cuando entro por ultima vez, cuando salio, y
/// cuanto salio por venta en los ultimos dias. Lo ultimo es lo que deja decir
/// "te alcanza para 12 dias" en vez de solo cuanto queda.
/// </summary>
/// <summary>Con cuánto —y por cuánto— entra un producto a una página del kardex.</summary>
public record SaldoKardex(decimal Cantidad, decimal Valor);

/// <summary>
/// Un renglón del kardex, venga de donde venga.
///
/// Existe porque el libro ya no es solo la tabla de movimientos: también entra
/// lo que un pedido reserva, que no mueve stock pero sí compromete mercadería
/// y hay que poder verlo entre lo demás, en su fecha. Las dos fuentes se
/// proyectan a esta forma para poder ordenarlas y paginarlas juntas en la
/// base, que es lo único que mantiene el saldo bien cuando hay varias páginas.
/// </summary>
// TipoDocumento: AJUSTE, TRANSFERENCIA, etc. Vacío en una reserva: no nace de ningún documento.
public record FilaKardex(
    int Id,
    DateTime Fecha,
    string Documento,
    string TipoDocumento,
    bool Anulado,
    string Motivo,
    string Tipo,
    int ProductoId,
    string Producto,
    string UnidadBase,
    int AlmacenId,
    string Almacen,
    string? Presentacion,
    decimal CantidadPresentacion,
    decimal Cantidad,
    decimal CostoUnitario,
    decimal CostoTotal);

/// <summary>
/// Lo justo de un movimiento para seguir el saldo: sin nombres ni documento.
/// Son los movimientos reales entre la primera y la última fila de una página
/// del kardex, estén o no en la página por los filtros.
/// </summary>
public record MovimientoSaldo(
    int Id, DateTime Fecha, int ProductoId, int AlmacenId, string Tipo, decimal Cantidad, decimal CostoTotal);

/// <summary>Lo que aparta un pedido sin sacarlo del almacén.</summary>
public static class TipoKardex
{
    public const string Reserva = "RESERVA";
}

public record ActividadStock(
    DateTime? UltimaEntrada, DateTime? UltimaSalida, decimal VendidoReciente);

public interface IInventarioRepository
{
    /// <summary>
    /// Una salida toca varias tablas: descuenta capas, graba consumos y crea el
    /// movimiento. O pasa todo o no pasa nada.
    /// </summary>
    Task<IDbContextTransaction> IniciarTransaccionAsync();
    Task GuardarAsync();

    // --- Almacenes ---
    Task<IEnumerable<Almacen>> GetAlmacenesAsync();

    /// <summary>
    /// Entradas confirmadas (recepción o ajuste) desde una fecha, con
    /// producto y almacén cargados — para avisar que llegó mercadería nueva.
    /// No incluye lo que entra por anular una venta: eso no es "nuevo".
    /// </summary>
    Task<IEnumerable<MovimientoInventario>> GetEntradasRecientesAsync(DateTime desde);
    Task<Almacen?> GetAlmacenAsync(int id);
    Task<Almacen?> GetAlmacenPrincipalAsync();
    Task<bool> ExisteCodigoAlmacenAsync(string codigo, int? excepto = null);
    Task<Almacen> AddAlmacenAsync(Almacen almacen);
    Task UpdateAlmacenAsync(Almacen almacen);
    Task DeleteAlmacenAsync(Almacen almacen);
    Task<int> ContarMovimientosAlmacenAsync(int almacenId);

    // --- Motivos ---
    Task<IEnumerable<MotivoMovimiento>> GetMotivosAsync();
    Task<MotivoMovimiento?> GetMotivoAsync(int id);
    Task<bool> ExisteCodigoMotivoAsync(string codigo, int? excepto = null);
    Task<int> ContarMovimientosMotivoAsync(int motivoId);
    Task<MotivoMovimiento> AddMotivoAsync(MotivoMovimiento motivo);
    Task UpdateMotivoAsync(MotivoMovimiento motivo);
    Task DeleteMotivoAsync(MotivoMovimiento motivo);

    // --- Capas ---

    /// <summary>
    /// Capas con mercaderia, de la mas antigua a la mas nueva, BLOQUEADAS
    /// hasta el fin de la transaccion: sin eso dos ventas simultaneas podrian
    /// consumir el mismo saco.
    /// </summary>
    Task<List<CapaCosto>> GetCapasParaConsumirAsync(int productoId, int almacenId);

    Task<List<CapaCosto>> GetCapasDisponiblesAsync(int productoId, int? almacenId = null);
    Task<CapaCosto?> GetCapaAsync(int id);
    Task<CapaCosto?> GetUltimaCapaAsync(int productoId, int? almacenId = null);
    /// <summary>
    /// Las capas que creo un movimiento de entrada. Normalmente una, pero una
    /// transferencia crea una por cada capa de origen que toco, para no
    /// promediar costos distintos en una sola.
    /// </summary>
    Task<List<CapaCosto>> GetCapasDeMovimientoAsync(int movimientoId);
    Task AddCapaAsync(CapaCosto capa);

    /// <summary>Totales del stock de todo el catálogo, resueltos con agregados.</summary>
    Task<Dtos.Responses.ResumenStockResponse> ResumenStockAsync(int? almacenId);

    /// <summary>Stock y costos de varios productos, para pintar listados.</summary>
    /// <summary>
    /// Ids de los productos que de verdad entraron a ese almacén (o a alguno):
    /// los que tienen al menos una capa de costo, aunque ya se hayan agotado.
    /// </summary>
    Task<HashSet<int>> GetProductoIdsConCapasAsync(int? almacenId);

    Task<Dictionary<int, ResumenStock>> GetResumenAsync(
        IEnumerable<int> productoIds, int? almacenId = null);

    /// <summary>Ultimo movimiento y salida por venta de varios productos. Sin ids, de todos.</summary>
    Task<Dictionary<int, ActividadStock>> GetActividadAsync(
        IEnumerable<int>? productoIds, int? almacenId, int dias);

    /// <summary>Cuántos productos con saldo y cuánto vale lo que hay, por almacén: una sola consulta.</summary>
    Task<Dictionary<int, (int Productos, decimal Valorizado)>> GetTotalesPorAlmacenAsync(int? almacenId = null);

    /// <summary>Las capas con saldo de varios productos, la que sale primero adelante.</summary>
    Task<List<CapaCosto>> GetCapasDisponiblesAsync(IEnumerable<int> productoIds, int? almacenId);

    /// <summary>
    /// Cuánto hay de cada producto que controla stock: la suma de sus capas con
    /// saldo. Solo el número, sin catálogo ni costos.
    /// </summary>
    Task<Dictionary<int, decimal>> GetStockPorProductoAsync(int? almacenId);

    // --- Documentos y movimientos ---

    Task<string> SiguienteNumeroAsync(string tipo);
    Task AddDocumentoAsync(DocumentoInventario documento);
    Task<DocumentoInventario?> GetDocumentoAsync(int id);

    /// <summary>
    /// Documentos, opcionalmente de una sola familia: el propio tipo, o una
    /// anulacion que anulo un documento de esa familia. Sin esto, transferencias
    /// y prestamos apareceria mezclados en la lista de Ajustes.
    /// </summary>
    Task<IEnumerable<DocumentoInventario>> GetDocumentosAsync(string? familia = null);

    /// <summary>Una página de documentos de inventario de una familia (ajustes, transferencias...).</summary>
    Task<(List<Dtos.Responses.DocumentoInventarioResponse> Items, int Total)> ListarDocumentosAsync(
        Dtos.Requests.ConsultaTablaRequest consulta, string? familia);

    /// <summary>Cuántos documentos confirmados y anulados hay en esa familia.</summary>
    Task<(int Total, int Confirmados, int Anulados)> ResumenDocumentosAsync(string? familia);

    /// <summary>Contadores del listado completo de préstamos.</summary>
    Task<Dtos.Responses.ResumenPrestamosResponse> ResumenPrestamosAsync();

    /// <summary>Una página de préstamos.</summary>
    Task<(List<Dtos.Responses.PrestamoFilaResponse> Items, int Total)> ListarPrestamosAsync(Dtos.Requests.ConsultaTablaRequest consulta);

    Task UpdateDocumentoAsync(DocumentoInventario documento);
    Task<string?> GetNumeroAnulacionAsync(int documentoId);

    Task AddDocumentoMovimientoAsync(MovimientoInventario movimiento);
    Task<List<MovimientoInventario>> GetMovimientosDocumentoAsync(int documentoId);

    /// <summary>Kardex: movimientos de un producto, del mas antiguo al mas nuevo.</summary>
    /// <summary>
    /// Una página del kardex, con el saldo de apertura por producto y almacén:
    /// lo que dejaron los movimientos anteriores a esta página. Sin eso, la
    /// página 2 arrancaría el saldo desde cero.
    /// </summary>
    /// <remarks>
    /// El saldo es del libro entero, no de lo filtrado: por eso también vienen
    /// los movimientos reales entre la primera y la última fila (Intermedios),
    /// aunque los filtros los dejen fuera de la página.
    /// </remarks>
    Task<(List<FilaKardex> Items, int Total, Dictionary<(int Producto, int Almacen), SaldoKardex> Aperturas,
            List<MovimientoSaldo> Intermedios)>
        ListarKardexAsync(Dtos.Requests.ConsultaTablaRequest consulta, int? almacenId);

    /// <summary>Cuántas entradas y salidas hay en todo el kardex del almacén.</summary>
    Task<(int Entradas, int Salidas)> ResumenKardexAsync(int? almacenId);

    /// <summary>
    /// Con cuánto (cantidad y valor) llega cada producto de la lista a un
    /// instante: la suma de sus movimientos anteriores, por producto y almacén.
    /// </summary>
    Task<Dictionary<(int Producto, int Almacen), SaldoKardex>> GetSaldosAntesAsync(
        DateTime antes, IEnumerable<int> productoIds, int? almacenId);

    Task<List<MovimientoInventario>> GetKardexAsync(
        int? productoId, int? almacenId, DateTime? desde, DateTime? hasta);

    Task<List<ConsumoCapa>> GetConsumosAsync(int movimientoId);

    /// <summary>
    /// El movimiento de salida que generó una línea de venta.
    ///
    /// Es el punto de partida de una devolución: de sus consumos salen las
    /// capas de costo a las que hay que reponer la mercadería.
    /// </summary>
    Task<MovimientoInventario?> GetMovimientoDeVentaAsync(int notaVentaDetalleId);
    Task AddConsumoAsync(ConsumoCapa consumo);

    /// <summary>Capas con stock que además tienen fecha de vencimiento, la más próxima primero.</summary>
    Task<List<CapaCosto>> GetCapasConVencimientoAsync();

    // --- Prestamos ---

    Task AddPrestamoAsync(Prestamo prestamo);
    Task<Prestamo?> GetPrestamoAsync(int id);

    /// <summary>Una línea de préstamo con su préstamo y hermanas cargadas, para recalcular el estado al anular una devolución.</summary>
    Task<PrestamoDetalle?> GetPrestamoDetalleConPrestamoAsync(int id);
    Task<IEnumerable<Prestamo>> GetPrestamosAsync();
    Task UpdatePrestamoAsync(Prestamo prestamo);
    Task AddPrestamoDetalleAsync(PrestamoDetalle detalle);
    Task<PrestamoDetalle?> GetPrestamoDetalleAsync(int id);
}
