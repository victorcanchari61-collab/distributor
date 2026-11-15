using Backend.Data;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Service.Interfaces;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Backend.Service.Implementacion;

/// <summary>
/// El plano de cada piso: una cuadrícula de <see cref="Plano.Columnas"/> × <see cref="Plano.Filas"/> celdas donde se
/// dibujan los lugares del piso (cocina, abarrotes...) y los pasillos y escaleras.
///
/// Cada piso es un plano. Un almacén sin pisos tiene uno solo, con sus lugares sueltos. En un mismo plano nada se
/// encima: dos cosas no ocupan la misma celda, igual que en el almacén.
/// </summary>
public class PlanoService : IPlanoService
{
    private readonly AppDbContext _context;
    private readonly IUbicacionService _ubicaciones;
    private readonly IValidator<PosicionPlanoRequest> _posicion;
    private readonly IValidator<ElementoPlanoRequest> _elemento;
    private readonly INotificador _notificador;

    public PlanoService(
        AppDbContext context,
        IUbicacionService ubicaciones,
        IValidator<PosicionPlanoRequest> posicion,
        IValidator<ElementoPlanoRequest> elemento,
        INotificador notificador)
    {
        _context = context;
        _ubicaciones = ubicaciones;
        _posicion = posicion;
        _elemento = elemento;
        _notificador = notificador;
    }

    public async Task<PlanoResponse> ObtenerAsync(int almacenId)
    {
        if (!await _context.Almacenes.AnyAsync(a => a.Id == almacenId))
            throw new NotFoundException("Almacén no encontrado");

        var elementos = await _context.ElementosPlano.AsNoTracking()
            .Where(e => e.AlmacenId == almacenId)
            .OrderBy(e => e.Id)
            .Select(e => new ElementoPlanoResponse
            {
                Id = e.Id,
                PisoId = e.PisoId,
                Tipo = e.Tipo,
                Nombre = e.Nombre,
                X = e.X,
                Y = e.Y,
                Ancho = e.Ancho,
                Alto = e.Alto,
            })
            .ToListAsync();

        return new PlanoResponse
        {
            AlmacenId = almacenId,
            Columnas = Plano.Columnas,
            Filas = Plano.Filas,
            Elementos = elementos,
        };
    }

    public async Task<UbicacionResponse> PosicionarLugarAsync(int ubicacionId, PosicionPlanoRequest request)
    {
        await _posicion.ValidateAndThrowAsync(request);

        var lugar = await _context.UbicacionesAlmacen.FirstOrDefaultAsync(u => u.Id == ubicacionId)
            ?? throw new NotFoundException("Lugar no encontrado");
        if (lugar.Tipo == TipoUbicacion.Piso)
            throw new BadRequestException("Un piso no se dibuja: cada piso es un plano.");

        if (request.X is int x && request.Y is int y && request.Ancho is int ancho && request.Alto is int alto)
        {
            await ExigirLibreAsync(lugar.AlmacenId, lugar.PadreId, x, y, ancho, alto, lugarId: lugar.Id, elementoId: null);
            (lugar.PlanoX, lugar.PlanoY, lugar.PlanoAncho, lugar.PlanoAlto) = (x, y, ancho, alto);
        }
        else
        {
            (lugar.PlanoX, lugar.PlanoY, lugar.PlanoAncho, lugar.PlanoAlto) = (null, null, null, null);
        }

        await _context.SaveChangesAsync();
        await _notificador.AvisarAsync("ubicaciones", "plano", new { almacenId = lugar.AlmacenId });

        return (await _ubicaciones.ListarAsync(lugar.AlmacenId)).First(u => u.Id == lugar.Id);
    }

    public async Task<ElementoPlanoResponse> CrearElementoAsync(int almacenId, ElementoPlanoRequest request)
    {
        await _elemento.ValidateAndThrowAsync(request);
        if (!await _context.Almacenes.AnyAsync(a => a.Id == almacenId))
            throw new NotFoundException("Almacén no encontrado");

        if (request.PisoId is int pisoId)
        {
            var piso = await _context.UbicacionesAlmacen.AsNoTracking().FirstOrDefaultAsync(u => u.Id == pisoId)
                ?? throw new BadRequestException("Ese piso no existe");
            if (piso.AlmacenId != almacenId || piso.Tipo != TipoUbicacion.Piso)
                throw new BadRequestException("Ese piso no es de este almacén");
        }
        else if (await _context.UbicacionesAlmacen.AnyAsync(
                     u => u.AlmacenId == almacenId && u.PadreId == null && u.Tipo == TipoUbicacion.Piso))
        {
            throw new BadRequestException("Este almacén usa pisos: elige en qué piso va.");
        }

        await ExigirLibreAsync(almacenId, request.PisoId, request.X, request.Y, request.Ancho, request.Alto, null, null);

        var elemento = new ElementoPlano
        {
            AlmacenId = almacenId,
            PisoId = request.PisoId,
            Tipo = request.Tipo,
            Nombre = request.Nombre.Trim(),
            X = request.X,
            Y = request.Y,
            Ancho = request.Ancho,
            Alto = request.Alto,
        };
        _context.ElementosPlano.Add(elemento);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "plano", new { almacenId });
        return Respuesta(elemento);
    }

    public async Task<ElementoPlanoResponse> ActualizarElementoAsync(int id, ElementoPlanoRequest request)
    {
        await _elemento.ValidateAndThrowAsync(request);

        var elemento = await _context.ElementosPlano.FirstOrDefaultAsync(e => e.Id == id)
            ?? throw new NotFoundException("Ese pasillo o escalera ya no existe");

        await ExigirLibreAsync(elemento.AlmacenId, elemento.PisoId, request.X, request.Y, request.Ancho, request.Alto, null, id);

        elemento.Nombre = request.Nombre.Trim();
        (elemento.X, elemento.Y, elemento.Ancho, elemento.Alto) = (request.X, request.Y, request.Ancho, request.Alto);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "plano", new { almacenId = elemento.AlmacenId });
        return Respuesta(elemento);
    }

    public async Task EliminarElementoAsync(int id)
    {
        var elemento = await _context.ElementosPlano.FirstOrDefaultAsync(e => e.Id == id)
            ?? throw new NotFoundException("Ese pasillo o escalera ya no existe");

        _context.ElementosPlano.Remove(elemento);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "plano", new { almacenId = elemento.AlmacenId });
    }

    /// <summary>
    /// Que el rectángulo quepa en la cuadrícula y no se encime con nada de su plano: los lugares de ese piso (o los
    /// sueltos, si no hay pisos) y sus pasillos y escaleras. Lo que se está moviendo no choca consigo mismo.
    /// </summary>
    private async Task ExigirLibreAsync(int almacenId, int? pisoId, int x, int y, int ancho, int alto, int? lugarId, int? elementoId)
    {
        if (ancho < 1 || alto < 1 || x < 0 || y < 0 || x + ancho > Plano.Columnas || y + alto > Plano.Filas)
            throw new BadRequestException("No cabe en el plano: queda fuera de la cuadrícula.");

        var lugares = await _context.UbicacionesAlmacen.AsNoTracking()
            .Where(u => u.AlmacenId == almacenId && u.PadreId == pisoId && u.Tipo != TipoUbicacion.Piso
                        && u.PlanoX != null && u.Id != lugarId)
            .Select(u => new { u.Codigo, u.Nombre, X = u.PlanoX!.Value, Y = u.PlanoY!.Value, Ancho = u.PlanoAncho!.Value, Alto = u.PlanoAlto!.Value })
            .ToListAsync();
        var elementos = await _context.ElementosPlano.AsNoTracking()
            .Where(e => e.AlmacenId == almacenId && e.PisoId == pisoId && e.Id != elementoId)
            .Select(e => new { e.Nombre, e.X, e.Y, e.Ancho, e.Alto })
            .ToListAsync();

        bool Choca(int ox, int oy, int oa, int oh) => x < ox + oa && ox < x + ancho && y < oy + oh && oy < y + alto;

        var lugar = lugares.FirstOrDefault(o => Choca(o.X, o.Y, o.Ancho, o.Alto));
        if (lugar is not null)
            throw new ConflictException($"Se encima con {lugar.Codigo}{(lugar.Nombre is null ? "" : $" · {lugar.Nombre}")}.");
        var otro = elementos.FirstOrDefault(o => Choca(o.X, o.Y, o.Ancho, o.Alto));
        if (otro is not null)
            throw new ConflictException($"Se encima con {otro.Nombre}.");
    }

    private static ElementoPlanoResponse Respuesta(ElementoPlano e) => new()
    {
        Id = e.Id,
        PisoId = e.PisoId,
        Tipo = e.Tipo,
        Nombre = e.Nombre,
        X = e.X,
        Y = e.Y,
        Ancho = e.Ancho,
        Alto = e.Alto,
    };
}
