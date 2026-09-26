using Backend.Data;
using Backend.Dtos.Responses;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class MovimientoDineroService : IMovimientoDineroService
{
    private readonly AppDbContext _context;

    public MovimientoDineroService(AppDbContext context)
    {
        _context = context;
    }

    /// <summary>La categoría del sistema que clasifica lo que se registra solo en cada módulo.</summary>
    private static readonly Dictionary<string, int> CategoriaDeDocumento = new()
    {
        [DocumentoOrigenMovimiento.PagoVenta] = CategoriaSistema.Ventas,
        [DocumentoOrigenMovimiento.SobranteCaja] = CategoriaSistema.SobranteCaja,
        [DocumentoOrigenMovimiento.FaltanteCaja] = CategoriaSistema.FaltanteCaja,
        [DocumentoOrigenMovimiento.RecuperoFaltante] = CategoriaSistema.RecuperoFaltante,
        [DocumentoOrigenMovimiento.Financiamiento] = CategoriaSistema.PrestamoRecibido,
        [DocumentoOrigenMovimiento.PagoFinanciamiento] = CategoriaSistema.PagoPrestamo,
    };

    public async Task<IEnumerable<MovimientoDineroResponse>> ListarAsync(DateTime desde, DateTime hasta, int? cuentaId)
    {
        // Nunca más de un año de una vez: el kardex del dinero crece todos los días.
        var (inicio, fin) = Zona.RangoUtc(desde, hasta);

        var query = _context.MovimientosCuenta
            .AsNoTracking()
            .Include(m => m.CuentaFinanciera)
            .Include(m => m.Usuario)
            .Where(m => m.Fecha >= inicio && m.Fecha < fin);
        if (cuentaId is int id) query = query.Where(m => m.CuentaFinancieraId == id);

        var movimientos = await query
            .OrderByDescending(m => m.Fecha).ThenByDescending(m => m.Id)
            .ToListAsync();

        // Una anulación se explica con lo que anuló, aunque eso haya caído
        // fuera del rango consultado.
        var revertidos = movimientos
            .Where(m => m.DocumentoOrigen == DocumentoOrigenMovimiento.Reversion && m.MovimientoOrigenId is not null)
            .Select(m => m.MovimientoOrigenId!.Value)
            .ToHashSet();
        var fueraDeRango = revertidos.Except(movimientos.Select(m => m.Id)).ToList();
        var originales = fueraDeRango.Count == 0
            ? []
            : await _context.MovimientosCuenta.AsNoTracking().Where(m => fueraDeRango.Contains(m.Id)).ToListAsync();

        var docs = await CargarDocumentosAsync(movimientos.Concat(originales).ToList());
        var porId = movimientos.Concat(originales).ToDictionary(m => m.Id);

        // Cuáles quedaron anulados: los que tienen una reversa, esté o no en el rango.
        var ids = movimientos.Select(m => m.Id).ToList();
        var anulados = (await _context.MovimientosCuenta
                .AsNoTracking()
                .Where(m => m.DocumentoOrigen == DocumentoOrigenMovimiento.Reversion
                            && m.MovimientoOrigenId != null && ids.Contains(m.MovimientoOrigenId.Value))
                .Select(m => m.MovimientoOrigenId!.Value)
                .ToListAsync())
            .ToHashSet();

        return movimientos.Select(m =>
        {
            var esReversa = m.DocumentoOrigen == DocumentoOrigenMovimiento.Reversion;
            var explicado = esReversa && m.MovimientoOrigenId is int original && porId.TryGetValue(original, out var o)
                ? o
                : m;
            var c = Clasificar(explicado, docs);

            return new MovimientoDineroResponse
            {
                Id = m.Id,
                Fecha = m.Fecha,
                CuentaFinancieraId = m.CuentaFinancieraId,
                Cuenta = m.CuentaFinanciera?.Nombre ?? string.Empty,
                Naturaleza = m.CuentaFinanciera?.Naturaleza ?? string.Empty,
                Tipo = m.Tipo,
                Monto = m.Monto,
                SaldoResultante = m.SaldoResultante,
                DocumentoOrigen = m.DocumentoOrigen,
                Concepto = esReversa ? $"Anulación: {c.Concepto}" : c.Concepto,
                Categoria = c.Categoria,
                Origen = c.Origen,
                Observacion = m.Observacion,
                Usuario = m.Usuario?.Nombre,
                Anulado = anulados.Contains(m.Id),
                EsReversa = esReversa,
                MovimientoOperativoId = esReversa ? null : c.MovimientoOperativoId,
                Anulable = !esReversa && c.Anulable,
            };
        }).ToList();
    }

    public async Task<IEnumerable<CuentaDestinoResponse>> CuentasAsync() =>
        await _context.CuentasFinancieras
            .AsNoTracking()
            .Where(c => c.Activo)
            .OrderBy(c => c.Naturaleza).ThenBy(c => c.Nombre)
            .Select(c => new CuentaDestinoResponse { Id = c.Id, Nombre = c.Nombre, Naturaleza = c.Naturaleza })
            .ToListAsync();

    // ---------------------------------------------------------- Auxiliares

    private sealed record Clasificacion(
        string Concepto, string? Categoria, string Origen, int? MovimientoOperativoId = null, bool Anulable = false);

    /// <summary>Los documentos detrás de los movimientos, de a un viaje por tipo.</summary>
    private sealed class Documentos
    {
        public Dictionary<int, PagoVenta> Cobros { get; init; } = [];
        public Dictionary<int, MovimientoOperativo> Manuales { get; init; } = [];
        public Dictionary<int, Financiamiento> Prestamos { get; init; } = [];
        public Dictionary<int, PagoFinanciamiento> PagosPrestamo { get; init; } = [];
        public Dictionary<int, CierreCaja> Cierres { get; init; } = [];
        public Dictionary<int, PlanillaDetalle> Planillas { get; init; } = [];
        public Dictionary<int, MotivoGasto> Categorias { get; init; } = [];
    }

    private async Task<Documentos> CargarDocumentosAsync(List<MovimientoCuenta> movimientos)
    {
        List<int> De(string documento) => movimientos
            .Where(m => m.DocumentoOrigen == documento && m.OrigenId is not null)
            .Select(m => m.OrigenId!.Value)
            .Distinct()
            .ToList();

        var cobros = De(DocumentoOrigenMovimiento.PagoVenta);
        var manuales = De(DocumentoOrigenMovimiento.MovimientoOperativo);
        var prestamos = De(DocumentoOrigenMovimiento.Financiamiento);
        var pagosPrestamo = De(DocumentoOrigenMovimiento.PagoFinanciamiento);
        var cierres = De(DocumentoOrigenMovimiento.CierreCaja)
            .Concat(De(DocumentoOrigenMovimiento.FaltanteCaja))
            .Concat(De(DocumentoOrigenMovimiento.SobranteCaja))
            .Distinct().ToList();
        var planillas = De(DocumentoOrigenMovimiento.RecuperoFaltante);

        return new Documentos
        {
            Cobros = await _context.PagosVenta.AsNoTracking()
                .Include(p => p.NotaVenta).ThenInclude(n => n!.Cliente)
                .Where(p => cobros.Contains(p.Id)).ToDictionaryAsync(p => p.Id),
            Manuales = await _context.MovimientosOperativos.AsNoTracking()
                .Include(m => m.MotivoGasto)
                .Where(m => manuales.Contains(m.Id)).ToDictionaryAsync(m => m.Id),
            Prestamos = await _context.Financiamientos.AsNoTracking()
                .Where(f => prestamos.Contains(f.Id)).ToDictionaryAsync(f => f.Id),
            PagosPrestamo = await _context.PagosFinanciamiento.AsNoTracking()
                .Include(p => p.Financiamiento)
                .Where(p => pagosPrestamo.Contains(p.Id)).ToDictionaryAsync(p => p.Id),
            Cierres = await _context.CierresCaja.AsNoTracking()
                .Include(c => c.Usuario)
                .Where(c => cierres.Contains(c.Id)).ToDictionaryAsync(c => c.Id),
            Planillas = await _context.PlanillaDetalles.AsNoTracking()
                .Include(d => d.Empleado)
                .Where(d => planillas.Contains(d.Id)).ToDictionaryAsync(d => d.Id),
            Categorias = await _context.MotivosGasto.AsNoTracking()
                .Where(c => c.EsSistema).ToDictionaryAsync(c => c.Id),
        };
    }

    private static Clasificacion Clasificar(MovimientoCuenta m, Documentos d)
    {
        T? Doc<T>(Dictionary<int, T> mapa) where T : class =>
            m.OrigenId is int id && mapa.TryGetValue(id, out var doc) ? doc : null;

        // Lo que registra solo cada módulo: su categoría del sistema dice el origen.
        Clasificacion DelSistema(string concepto)
        {
            var categoria = CategoriaDeDocumento.TryGetValue(m.DocumentoOrigen, out var cid)
                && d.Categorias.TryGetValue(cid, out var c) ? c : null;
            return new Clasificacion(concepto, categoria?.Nombre, categoria?.Origen ?? OrigenMovimiento.Operativo);
        }

        string DelCierre(string texto) =>
            Doc(d.Cierres)?.Usuario?.Nombre is string quien ? $"{texto} de {quien}" : texto;

        switch (m.DocumentoOrigen)
        {
            case DocumentoOrigenMovimiento.PagoVenta:
            {
                var nota = Doc(d.Cobros)?.NotaVenta;
                return DelSistema(nota is null ? "Cobro de venta" : $"Cobro {nota.Numero} — {nota.Cliente?.Nombre}");
            }
            case DocumentoOrigenMovimiento.MovimientoOperativo:
            {
                var manual = Doc(d.Manuales);
                if (manual?.MotivoGasto is not MotivoGasto categoria)
                    return new Clasificacion("Ingreso o egreso", null, OrigenMovimiento.Operativo);

                var concepto = string.IsNullOrWhiteSpace(manual.Descripcion)
                    ? categoria.Nombre
                    : $"{categoria.Nombre} — {manual.Descripcion}";
                return new Clasificacion(concepto, categoria.Nombre, categoria.Origen, manual.Id,
                    Anulable: !manual.Anulado && !categoria.EsSistema);
            }
            case DocumentoOrigenMovimiento.Financiamiento:
                return DelSistema(Doc(d.Prestamos) is { } f ? $"Préstamo de {f.Acreedor}" : "Préstamo recibido");
            case DocumentoOrigenMovimiento.PagoFinanciamiento:
                return DelSistema(Doc(d.PagosPrestamo)?.Financiamiento is { } pf
                    ? $"Pago de préstamo a {pf.Acreedor}"
                    : "Pago de préstamo");
            case DocumentoOrigenMovimiento.FaltanteCaja:
                return DelSistema(DelCierre("Faltante en el cierre"));
            case DocumentoOrigenMovimiento.SobranteCaja:
                return DelSistema(DelCierre("Sobrante en el cierre"));
            case DocumentoOrigenMovimiento.RecuperoFaltante:
                return DelSistema(Doc(d.Planillas)?.Empleado is { } e
                    ? $"Faltante descontado a {e.NombreCompleto} en planilla"
                    : "Recupero de faltante");
            case DocumentoOrigenMovimiento.CierreCaja:
                return new Clasificacion(DelCierre("Cierre de caja"), null, OrigenMovimiento.Interno);
            case DocumentoOrigenMovimiento.TransferenciaInterna:
                return new Clasificacion("Transferencia entre cuentas", null, OrigenMovimiento.Interno);
            case DocumentoOrigenMovimiento.SaldoInicial:
                return new Clasificacion("Saldo inicial", null, OrigenMovimiento.Interno);
            default:
                return new Clasificacion(m.DocumentoOrigen, null, OrigenMovimiento.Interno);
        }
    }
}
