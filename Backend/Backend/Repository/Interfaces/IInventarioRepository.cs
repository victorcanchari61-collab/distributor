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
    Task<CapaCosto?> GetCapaDeMovimientoAsync(int movimientoId);
    Task AddCapaAsync(CapaCosto capa);

    /// <summary>Stock y costos de varios productos, para pintar listados.</summary>
    Task<Dictionary<int, ResumenStock>> GetResumenAsync(
        IEnumerable<int> productoIds, int? almacenId = null);

    // --- Documentos y movimientos ---

    Task<string> SiguienteNumeroAsync(string tipo);
    Task AddDocumentoAsync(DocumentoInventario documento);
    Task<DocumentoInventario?> GetDocumentoAsync(int id);
    Task<IEnumerable<DocumentoInventario>> GetDocumentosAsync();
    Task UpdateDocumentoAsync(DocumentoInventario documento);
    Task<string?> GetNumeroAnulacionAsync(int documentoId);

    Task AddDocumentoMovimientoAsync(MovimientoInventario movimiento);
    Task<List<MovimientoInventario>> GetMovimientosDocumentoAsync(int documentoId);

    /// <summary>Kardex: movimientos de un producto, del mas antiguo al mas nuevo.</summary>
    Task<List<MovimientoInventario>> GetKardexAsync(
        int? productoId, int? almacenId, DateTime? desde, DateTime? hasta);

    Task<List<ConsumoCapa>> GetConsumosAsync(int movimientoId);
    Task AddConsumoAsync(ConsumoCapa consumo);
}
