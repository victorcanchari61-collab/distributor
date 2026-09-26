using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// Si el negocio gana: un reporte de gestión, no tributario.
///
/// Las ventas y su costo salen de la misma base que Mis ganancias (líneas
/// vendidas con su costo real, recojos restados), para que las dos pantallas
/// digan lo mismo. Los demás ingresos y gastos salen del kardex del dinero,
/// con la clasificación de su categoría: operativo suma a la utilidad, no
/// operativo (préstamos, aportes, retiros) va aparte, solo para mirar.
///
/// Del kardex del dinero NO entran:
///   - los cobros de venta y los pagos de compra: ya están en ventas y en el
///     costo de lo vendido, y contarlos otra vez los duplicaría;
///   - lo interno (cierres de caja, transferencias, saldo inicial): mover
///     plata de una cuenta a otra no es ganar ni gastar;
///   - lo anulado y sus reversas.
/// </summary>
public class EstadoResultadosService : IEstadoResultadosService
{
    private const int MaximoDias = 366;

    private readonly IGananciaService _ganancias;
    private readonly IMovimientoDineroService _dinero;

    public EstadoResultadosService(IGananciaService ganancias, IMovimientoDineroService dinero)
    {
        _ganancias = ganancias;
        _dinero = dinero;
    }

    public async Task<EstadoResultadosResponse> CalcularAsync(DateTime? desde, DateTime? hasta)
    {
        var ultimo = (hasta ?? Zona.Hoy).Date;
        var primero = (desde ?? new DateTime(ultimo.Year, ultimo.Month, 1)).Date;

        if (primero > ultimo)
            throw new BadRequestException("El \"desde\" no puede ser después del \"hasta\".");
        if ((ultimo - primero).TotalDays >= MaximoDias)
            throw new BadRequestException($"Elige un rango de hasta {MaximoDias} días.");

        var ventas = await _ganancias.TotalesAsync(Zona.AUtc(primero), Zona.AUtc(ultimo.AddDays(1)));

        var movimientos = (await _dinero.ListarAsync(primero, ultimo, null))
            .Where(m => !m.EsReversa && !m.Anulado
                        && m.Origen != OrigenMovimiento.Interno
                        && m.DocumentoOrigen != DocumentoOrigenMovimiento.PagoVenta
                        && m.DocumentoOrigen != DocumentoOrigenMovimiento.PagoCompra)
            .ToList();

        List<LineaResultadoResponse> Renglones(string origen, string tipo) => movimientos
            .Where(m => m.Origen == origen && m.Tipo == tipo)
            .GroupBy(m => m.Categoria ?? m.Concepto)
            .Select(g => new LineaResultadoResponse
            {
                Concepto = g.Key,
                Monto = Math.Round(g.Sum(m => m.Monto), 2),
                Movimientos = g.Count(),
            })
            .OrderByDescending(l => l.Monto)
            .ToList();

        var otrosIngresos = Renglones(OrigenMovimiento.Operativo, TipoMovimientoCuenta.Ingreso);
        var gastos = Renglones(OrigenMovimiento.Operativo, TipoMovimientoCuenta.Egreso);
        var ingresosNoOp = Renglones(OrigenMovimiento.NoOperativo, TipoMovimientoCuenta.Ingreso);
        var egresosNoOp = Renglones(OrigenMovimiento.NoOperativo, TipoMovimientoCuenta.Egreso);

        var ventasNetas = Math.Round(ventas.ValorVenta, 2);
        var costo = Math.Round(ventas.Costo, 2);
        var utilidadBruta = ventasNetas - costo;
        var totalOtros = otrosIngresos.Sum(l => l.Monto);
        var totalGastos = gastos.Sum(l => l.Monto);
        var utilidadOperativa = utilidadBruta + totalOtros - totalGastos;

        return new EstadoResultadosResponse
        {
            Desde = primero,
            Hasta = ultimo,
            VentasBrutas = Math.Round(ventas.Importe, 2),
            Igv = Math.Round(ventas.Importe, 2) - ventasNetas,
            VentasNetas = ventasNetas,
            CostoVentas = costo,
            UtilidadBruta = utilidadBruta,
            MargenBruto = Margen(ventasNetas, utilidadBruta),
            OtrosIngresos = otrosIngresos,
            TotalOtrosIngresos = totalOtros,
            GastosOperativos = gastos,
            TotalGastosOperativos = totalGastos,
            UtilidadOperativa = utilidadOperativa,
            MargenOperativo = Margen(ventasNetas, utilidadOperativa),
            IngresosNoOperativos = ingresosNoOp,
            TotalIngresosNoOperativos = ingresosNoOp.Sum(l => l.Monto),
            EgresosNoOperativos = egresosNoOp,
            TotalEgresosNoOperativos = egresosNoOp.Sum(l => l.Monto),
            Ventas = ventas.Ventas,
            LineasSinCosto = ventas.LineasSinCosto,
        };
    }

    private static decimal? Margen(decimal ventas, decimal utilidad) =>
        ventas > 0 ? Math.Round(utilidad / ventas * 100, 1) : null;
}
