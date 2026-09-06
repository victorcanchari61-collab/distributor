using Backend.Models;
using Microsoft.EntityFrameworkCore.Storage;

namespace Backend.Repository.Interfaces;

/// <summary>Lo que se muestra de un producto sin abrir sus capas.</summary>
public record ResumenStock(decimal Stock, decimal Valorizado, decimal CostoMin, decimal CostoMax);

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

    /// <summary>Stock y costos de varios productos, para pintar listados.</summary>
    Task<Dictionary<int, ResumenStock>> GetResumenAsync(
        IEnumerable<int> productoIds, int? almacenId = null);

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
    Task<(List<DocumentoInventario> Items, int Total)> ListarDocumentosAsync(
        Dtos.Requests.ConsultaTablaRequest consulta, string? familia);

    /// <summary>Cuántos documentos confirmados y anulados hay en esa familia.</summary>
    Task<(int Total, int Confirmados, int Anulados)> ResumenDocumentosAsync(string? familia);

    /// <summary>Contadores del listado completo de préstamos.</summary>
    Task<Dtos.Responses.ResumenPrestamosResponse> ResumenPrestamosAsync();

    /// <summary>Una página de préstamos.</summary>
    Task<(List<Prestamo> Items, int Total)> ListarPrestamosAsync(Dtos.Requests.ConsultaTablaRequest consulta);

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
    Task<(List<MovimientoInventario> Items, int Total, Dictionary<(int Producto, int Almacen), decimal> Aperturas)>
        ListarKardexAsync(Dtos.Requests.ConsultaTablaRequest consulta, int? almacenId);

    /// <summary>Cuántas entradas y salidas hay en todo el kardex del almacén.</summary>
    Task<(int Entradas, int Salidas)> ResumenKardexAsync(int? almacenId);

    Task<List<MovimientoInventario>> GetKardexAsync(
        int? productoId, int? almacenId, DateTime? desde, DateTime? hasta);

    Task<List<ConsumoCapa>> GetConsumosAsync(int movimientoId);
    Task AddConsumoAsync(ConsumoCapa consumo);

    /// <summary>Capas con stock que además tienen fecha de vencimiento, la más próxima primero.</summary>
    Task<List<CapaCosto>> GetCapasConVencimientoAsync();

    // --- Prestamos ---

    Task AddPrestamoAsync(Prestamo prestamo);
    Task<Prestamo?> GetPrestamoAsync(int id);
    Task<IEnumerable<Prestamo>> GetPrestamosAsync();
    Task UpdatePrestamoAsync(Prestamo prestamo);
    Task AddPrestamoDetalleAsync(PrestamoDetalle detalle);
    Task<PrestamoDetalle?> GetPrestamoDetalleAsync(int id);
}
