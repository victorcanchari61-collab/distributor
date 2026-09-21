using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// El recorrido semanal de cada vehículo: qué rutas hace cada día.
///
/// Se guarda entero cada vez, no fila por fila: la pantalla es una grilla de lunes a domingo y quien la
/// edita piensa en "la semana del camión", no en filas sueltas.
/// </summary>
public class RecorridoService : IRecorridoService
{
    private readonly AppDbContext _context;
    private readonly INotificador _notificador;

    public RecorridoService(AppDbContext context, INotificador notificador)
    {
        _context = context;
        _notificador = notificador;
    }

    public async Task<RecorridoResponse> GetAsync(int vehiculoId)
    {
        if (!await _context.Vehiculos.AnyAsync(v => v.Id == vehiculoId))
            throw new NotFoundException($"No existe el vehículo {vehiculoId}");

        var filas = await _context.RecorridosVehiculo
            .AsNoTracking()
            .Where(r => r.VehiculoId == vehiculoId)
            .OrderBy(r => r.RutaId)
            .ToListAsync();

        return Armar(vehiculoId, filas);
    }

    public async Task<RecorridoResponse> GuardarAsync(int vehiculoId, RecorridoRequest request)
    {
        if (!await _context.Vehiculos.AnyAsync(v => v.Id == vehiculoId))
            throw new NotFoundException($"No existe el vehículo {vehiculoId}");

        // Los días llegan como los escribe la pantalla; se uniforman y se rechaza lo que no es un día.
        var dias = new Dictionary<string, List<int>>();
        foreach (var (clave, rutas) in request.Dias)
        {
            var dia = DiaSemana.Normalizar(clave);
            if (dia is null || !DiaSemana.EsValido(dia))
                throw new BadRequestException($"'{clave}' no es un día de la semana");

            var limpias = rutas.Where(id => id > 0).Distinct().ToList();
            if (limpias.Count > 0) dias[dia] = limpias;
        }

        var pedidas = dias.Values.SelectMany(r => r).Distinct().ToList();
        var existentes = await _context.Rutas.CountAsync(r => pedidas.Contains(r.Id));
        if (existentes != pedidas.Count)
            throw new BadRequestException("Alguna de las rutas elegidas no existe");

        _context.RecorridosVehiculo.RemoveRange(
            await _context.RecorridosVehiculo.Where(r => r.VehiculoId == vehiculoId).ToListAsync());

        foreach (var (dia, rutas) in dias)
        {
            foreach (var rutaId in rutas)
            {
                _context.RecorridosVehiculo.Add(new RecorridoVehiculo { VehiculoId = vehiculoId, Dia = dia, RutaId = rutaId });
            }
        }

        await _context.SaveChangesAsync();

        var respuesta = await GetAsync(vehiculoId);
        await _notificador.AvisarAsync("recorridos", "actualizado", respuesta);
        return respuesta;
    }

    private static RecorridoResponse Armar(int vehiculoId, List<RecorridoVehiculo> filas) => new()
    {
        VehiculoId = vehiculoId,
        Dias = filas
            .GroupBy(f => f.Dia)
            .OrderBy(g => Array.IndexOf(DiaSemana.Todos, g.Key))
            .ToDictionary(g => g.Key, g => g.Select(f => f.RutaId).ToList()),
    };
}
