using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

public class SerieCpeService : ISerieCpeService
{
    private const int NumeroMaximo = 99_999_999;

    private readonly AppDbContext _context;
    private readonly INotificador _notificador;

    public SerieCpeService(AppDbContext context, INotificador notificador)
    {
        _context = context;
        _notificador = notificador;
    }

    public async Task<List<SerieCpeResponse>> ListarAsync(int empresaId)
    {
        await ExigirEmpresaAsync(empresaId);

        var series = await _context.SeriesCpe.AsNoTracking()
            .Where(s => s.EmpresaId == empresaId)
            .OrderBy(s => s.Tipo).ThenBy(s => s.AplicaA).ThenBy(s => s.Serie)
            .ToListAsync();

        // Cuántos comprobantes lleva cada una: el nombre de una serie usada ya no se toca.
        var nombres = series.Select(s => s.Serie).ToList();
        var emitidos = await _context.ComprobantesElectronicos.AsNoTracking()
            .Where(c => nombres.Contains(c.Serie))
            .GroupBy(c => c.Serie)
            .Select(g => new { Serie = g.Key, Cantidad = g.Count() })
            .ToDictionaryAsync(x => x.Serie, x => x.Cantidad);

        return series.Select(s => Mapear(s, emitidos.GetValueOrDefault(s.Serie))).ToList();
    }

    public async Task<SerieCpeResponse> CrearAsync(int empresaId, GuardarSerieRequest request)
    {
        await ExigirEmpresaAsync(empresaId);
        var (tipo, serie, aplicaA) = Validar(request);
        await ExigirSerieLibreAsync(serie, null);

        var maximo = await MaximoEmitidoAsync(serie);
        if (request.UltimoNumero < maximo)
            throw new BadRequestException($"Ya hay comprobantes emitidos hasta el número {maximo} con la serie {serie}");

        var nueva = new SerieCpe
        {
            EmpresaId = empresaId, Tipo = tipo, Serie = serie, AplicaA = aplicaA,
            UltimoNumero = request.UltimoNumero, Activa = request.Activa,
        };
        _context.SeriesCpe.Add(nueva);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("empresas", "series", new { empresaId });

        return Mapear(nueva, 0);
    }

    public async Task<SerieCpeResponse> ActualizarAsync(int empresaId, int id, GuardarSerieRequest request)
    {
        var existente = await ObtenerAsync(empresaId, id);
        var emitidos = await _context.ComprobantesElectronicos.CountAsync(c => c.Serie == existente.Serie);

        var (tipo, serie, aplicaA) = Validar(request);
        if (emitidos > 0 && (tipo != existente.Tipo || serie != existente.Serie || aplicaA != existente.AplicaA))
            throw new ConflictException(
                $"La serie {existente.Serie} ya tiene comprobantes: solo se puede cambiar su numeración o desactivarla");

        if (serie != existente.Serie) await ExigirSerieLibreAsync(serie, id);

        var maximo = await MaximoEmitidoAsync(existente.Serie);
        if (request.UltimoNumero < maximo)
            throw new BadRequestException(
                $"No se puede bajar de {maximo}: ya hay comprobantes emitidos hasta ese número con la serie {existente.Serie}");

        existente.Tipo = tipo;
        existente.Serie = serie;
        existente.AplicaA = aplicaA;
        existente.UltimoNumero = request.UltimoNumero;
        existente.Activa = request.Activa;
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("empresas", "series", new { empresaId });

        return Mapear(existente, emitidos);
    }

    public async Task EliminarAsync(int empresaId, int id)
    {
        var existente = await ObtenerAsync(empresaId, id);
        if (await _context.ComprobantesElectronicos.AnyAsync(c => c.Serie == existente.Serie))
            throw new ConflictException($"La serie {existente.Serie} ya tiene comprobantes: desactívala en vez de eliminarla");

        _context.SeriesCpe.Remove(existente);
        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("empresas", "series", new { empresaId });
    }

    public async Task<List<SerieCpeResponse>> CrearEstandarAsync(int empresaId)
    {
        await ExigirEmpresaAsync(empresaId);

        // Las notas llevan la letra del comprobante que corrigen, como exige SUNAT.
        (string Tipo, string Serie, string? AplicaA)[] estandar =
        [
            (TipoCpe.Factura, "F001", null),
            (TipoCpe.Boleta, "B001", null),
            (TipoCpe.NotaCredito, "FC01", TipoCpe.Factura),
            (TipoCpe.NotaCredito, "BC01", TipoCpe.Boleta),
            (TipoCpe.NotaDebito, "FD01", TipoCpe.Factura),
            (TipoCpe.NotaDebito, "BD01", TipoCpe.Boleta),
        ];

        var yaExisten = (await _context.SeriesCpe.AsNoTracking().Select(s => s.Serie).ToListAsync()).ToHashSet();
        foreach (var (tipo, serie, aplicaA) in estandar.Where(e => !yaExisten.Contains(e.Serie)))
            _context.SeriesCpe.Add(new SerieCpe { EmpresaId = empresaId, Tipo = tipo, Serie = serie, AplicaA = aplicaA });

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("empresas", "series", new { empresaId });
        return await ListarAsync(empresaId);
    }

    // ------------------------------------------------------------------ Internos

    private async Task ExigirEmpresaAsync(int empresaId)
    {
        if (!await _context.Empresas.AnyAsync(e => e.Id == empresaId))
            throw new NotFoundException("Empresa no encontrada");
    }

    private async Task<SerieCpe> ObtenerAsync(int empresaId, int id) =>
        await _context.SeriesCpe.FirstOrDefaultAsync(s => s.Id == id && s.EmpresaId == empresaId)
        ?? throw new NotFoundException("Serie no encontrada");

    private async Task ExigirSerieLibreAsync(string serie, int? exceptoId)
    {
        if (await _context.SeriesCpe.AnyAsync(s => s.Serie == serie && s.Id != exceptoId))
            throw new ConflictException($"La serie {serie} ya existe");
    }

    private async Task<int> MaximoEmitidoAsync(string serie) =>
        await _context.ComprobantesElectronicos.Where(c => c.Serie == serie).MaxAsync(c => (int?)c.Numero) ?? 0;

    /// <summary>Normaliza y revisa lo que SUNAT exige de una serie según su tipo.</summary>
    private static (string Tipo, string Serie, string? AplicaA) Validar(GuardarSerieRequest r)
    {
        var tipo = r.Tipo?.Trim() ?? string.Empty;
        if (!TipoCpe.Todos.Contains(tipo))
            throw new BadRequestException("El tipo debe ser factura, boleta, nota de crédito o nota de débito");

        var serie = (r.Serie ?? string.Empty).Trim().ToUpperInvariant();
        if (serie.Length != 4 || !serie.All(char.IsLetterOrDigit))
            throw new BadRequestException("La serie tiene cuatro caracteres, por ejemplo F001");

        if (r.UltimoNumero < 0 || r.UltimoNumero > NumeroMaximo)
            throw new BadRequestException($"El último número va de 0 a {NumeroMaximo:N0}");

        string? aplicaA = null;
        char letra;
        if (TipoCpe.EsNota(tipo))
        {
            aplicaA = r.AplicaA?.Trim();
            if (aplicaA is not (TipoCpe.Factura or TipoCpe.Boleta))
                throw new BadRequestException("Indica si la serie corrige facturas o boletas");
            letra = aplicaA == TipoCpe.Factura ? 'F' : 'B';
        }
        else
        {
            letra = tipo == TipoCpe.Factura ? 'F' : 'B';
        }

        if (serie[0] != letra)
            throw new BadRequestException($"La serie debe empezar con {letra}: así lo exige SUNAT para este documento");

        return (tipo, serie, aplicaA);
    }

    private static SerieCpeResponse Mapear(SerieCpe s, int emitidos) => new()
    {
        Id = s.Id, Tipo = s.Tipo, Serie = s.Serie, AplicaA = s.AplicaA,
        UltimoNumero = s.UltimoNumero, Activa = s.Activa, Emitidos = emitidos,
    };
}
