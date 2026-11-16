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
///
/// La escalera une pisos: va de su piso al de llegada y ocupa el mismo lugar en todos los que cruza (de P1 a P3 pasa
/// por P2). Se dibuja en cada uno, se revisa que esté libre en cada uno y se mueve en todos a la vez.
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

        var orden = await PisosEnOrdenAsync(almacenId);
        var elementos = await _context.ElementosPlano.AsNoTracking()
            .Where(e => e.AlmacenId == almacenId)
            .OrderBy(e => e.Id)
            .ToListAsync();

        return new PlanoResponse
        {
            AlmacenId = almacenId,
            Columnas = Plano.Columnas,
            Filas = Plano.Filas,
            Elementos = elementos.Select(e => Respuesta(e, orden)).ToList(),
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
            var partes = (request.Partes ?? []).Select(p => new RectPlano(p.X, p.Y, p.Ancho, p.Alto)).ToList();
            if (partes.Count > Plano.MaximoPartes)
                throw new BadRequestException($"Un lugar puede tener hasta {Plano.MaximoPartes} partes.");

            List<RectPlano> todas = [new RectPlano(x, y, ancho, alto), .. partes];
            for (var i = 0; i < todas.Count; i++)
                for (var j = i + 1; j < todas.Count; j++)
                    if (todas[i].Choca(todas[j]))
                        throw new BadRequestException("Dos partes del lugar se enciman.");
            if (!Plano.Conectadas(todas))
                throw new BadRequestException("Cada parte tiene que tocar al resto del lugar, por un lado.");

            // Doble altura: sin dato se queda como estaba; el mismo piso del lugar se la quita.
            var orden = await PisosEnOrdenAsync(lugar.AlmacenId);
            var hasta = lugar.PlanoHastaPisoId;
            if (request.HastaPisoId is int pedido)
                hasta = pedido == lugar.PadreId ? null : ExigirEncima(lugar.PadreId, pedido, orden);

            await ExigirLibreAsync(lugar.AlmacenId, PisosDe(lugar.PadreId, hasta, orden), todas, lugarId: lugar.Id, elementoId: null);
            (lugar.PlanoX, lugar.PlanoY, lugar.PlanoAncho, lugar.PlanoAlto) = (x, y, ancho, alto);
            lugar.PlanoPartes = Plano.EscribirPartes(partes);
            lugar.PlanoHastaPisoId = hasta;
        }
        else
        {
            (lugar.PlanoX, lugar.PlanoY, lugar.PlanoAncho, lugar.PlanoAlto) = (null, null, null, null);
            lugar.PlanoPartes = null;
            lugar.PlanoHastaPisoId = null;
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

        var orden = await PisosEnOrdenAsync(almacenId);
        if (request.PisoId is int pisoId)
        {
            if (!orden.Contains(pisoId))
                throw new BadRequestException("Ese piso no es de este almacén");
        }
        else if (orden.Count > 0)
        {
            throw new BadRequestException("Este almacén usa pisos: elige en qué piso va.");
        }

        // La escalera llega a otro piso; un pasillo puede estar abierto hasta un piso de arriba (doble altura).
        int? hasta = request.Tipo == TipoElementoPlano.Escalera
            ? ExigirLlegada(request.PisoId, request.HastaPisoId, orden)
            : request.HastaPisoId is int pedido && pedido != request.PisoId
                ? ExigirEncima(request.PisoId, pedido, orden)
                : null;

        var rect = new RectPlano(request.X, request.Y, request.Ancho, request.Alto);
        await ExigirLibreAsync(almacenId, PisosDe(request.PisoId, hasta, orden), [rect], null, null);

        var elemento = new ElementoPlano
        {
            AlmacenId = almacenId,
            PisoId = request.PisoId,
            HastaPisoId = hasta,
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
        return Respuesta(elemento, orden);
    }

    public async Task<ElementoPlanoResponse> ActualizarElementoAsync(int id, ElementoPlanoRequest request)
    {
        await _elemento.ValidateAndThrowAsync(request);

        var elemento = await _context.ElementosPlano.FirstOrDefaultAsync(e => e.Id == id)
            ?? throw new NotFoundException("Ese pasillo o escalera ya no existe");

        var orden = await PisosEnOrdenAsync(elemento.AlmacenId);
        // A dónde llega la escalera, o hasta dónde está abierto el pasillo: sin dato, lo de siempre. En un pasillo,
        // su mismo piso le quita la doble altura.
        var hasta = elemento.HastaPisoId;
        if (request.HastaPisoId is int pedido)
            hasta = elemento.Tipo == TipoElementoPlano.Escalera
                ? ExigirLlegada(elemento.PisoId, pedido, orden)
                : pedido == elemento.PisoId ? null : ExigirEncima(elemento.PisoId, pedido, orden);

        var rect = new RectPlano(request.X, request.Y, request.Ancho, request.Alto);
        await ExigirLibreAsync(elemento.AlmacenId, PisosDe(elemento.PisoId, hasta, orden), [rect], null, id);

        elemento.Nombre = request.Nombre.Trim();
        elemento.HastaPisoId = hasta;
        (elemento.X, elemento.Y, elemento.Ancho, elemento.Alto) = (request.X, request.Y, request.Ancho, request.Alto);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "plano", new { almacenId = elemento.AlmacenId });
        return Respuesta(elemento, orden);
    }

    public async Task EliminarElementoAsync(int id)
    {
        var elemento = await _context.ElementosPlano.FirstOrDefaultAsync(e => e.Id == id)
            ?? throw new NotFoundException("Ese pasillo o escalera ya no existe");

        _context.ElementosPlano.Remove(elemento);
        await _context.SaveChangesAsync();

        await _notificador.AvisarAsync("ubicaciones", "plano", new { almacenId = elemento.AlmacenId });
    }

    // ------------------------------------------------------------- Pisos y escaleras

    /// <summary>Los pisos del almacén de abajo hacia arriba: por el número de su código (P2 antes que P10).</summary>
    private async Task<List<int>> PisosEnOrdenAsync(int almacenId)
    {
        var pisos = await _context.UbicacionesAlmacen.AsNoTracking()
            .Where(u => u.AlmacenId == almacenId && u.PadreId == null && u.Tipo == TipoUbicacion.Piso)
            .Select(u => new { u.Id, u.Codigo })
            .ToListAsync();
        return Plano.OrdenarPisos(pisos.Select(p => (p.Id, p.Codigo)));
    }

    /// <summary>
    /// Los pisos que ocupa algo: el suyo; una escalera o una doble altura, todos desde su piso hasta el otro, de abajo
    /// hacia arriba. En un almacén sin pisos, solo su plano (nulo).
    /// </summary>
    private static List<int?> PisosDe(int? pisoId, int? hastaPisoId, List<int> orden) => Plano.PisosEntre(pisoId, hastaPisoId, orden);

    /// <summary>Una doble altura llega a un piso de arriba del suyo, de este mismo almacén.</summary>
    private static int ExigirEncima(int? pisoId, int hastaPisoId, List<int> orden)
    {
        if (pisoId is not int piso)
            throw new BadRequestException("La doble altura se usa en un almacén con pisos.");
        if (!Plano.EstaEncima(piso, hastaPisoId, orden))
            throw new BadRequestException("La doble altura llega a un piso de arriba de este.");
        return hastaPisoId;
    }

    /// <summary>Una escalera une pisos: tiene que llegar a otro piso de este mismo almacén.</summary>
    private static int ExigirLlegada(int? pisoId, int? hastaPisoId, List<int> orden)
    {
        if (pisoId is null || orden.Count < 2)
            throw new BadRequestException("La escalera une pisos: crea al menos dos pisos para ponerla.");
        if (hastaPisoId is not int hasta)
            throw new BadRequestException("Elige a qué piso llega la escalera.");
        if (!orden.Contains(hasta))
            throw new BadRequestException("Ese piso de llegada no es de este almacén.");
        if (hasta == pisoId)
            throw new BadRequestException("La escalera tiene que llegar a otro piso.");
        return hasta;
    }

    /// <summary>
    /// Que lo que se dibuja (un rectángulo, o las partes de un lugar) quepa en la cuadrícula y no se encime con nada en
    /// ninguno de los planos que ocupa: los lugares de cada piso con todas sus partes, sus pasillos y las escaleras que
    /// lo cruzan (aunque hayan nacido en otro piso). Lo que se está moviendo no choca consigo mismo.
    /// </summary>
    private async Task ExigirLibreAsync(int almacenId, IReadOnlyList<int?> pisos, IReadOnlyList<RectPlano> rects, int? lugarId, int? elementoId)
    {
        if (rects.Any(r => !r.Cabe))
            throw new BadRequestException("No cabe en el plano: queda fuera de la cuadrícula.");

        var orden = await PisosEnOrdenAsync(almacenId);
        var codigos = await _context.UbicacionesAlmacen.AsNoTracking()
            .Where(u => u.AlmacenId == almacenId && u.PadreId == null && u.Tipo == TipoUbicacion.Piso)
            .ToDictionaryAsync(u => u.Id, u => u.Codigo);

        var lugares = (await _context.UbicacionesAlmacen.AsNoTracking()
                .Where(u => u.AlmacenId == almacenId && u.Tipo != TipoUbicacion.Piso && u.PlanoX != null && u.Id != lugarId)
                .Select(u => new { u.PadreId, u.PlanoHastaPisoId, u.Codigo, u.Nombre, X = u.PlanoX!.Value, Y = u.PlanoY!.Value, Ancho = u.PlanoAncho!.Value, Alto = u.PlanoAlto!.Value, u.PlanoPartes })
                .ToListAsync())
            .Select(u => new
            {
                Pisos = (IReadOnlyList<int?>)PisosDe(u.PadreId, u.PlanoHastaPisoId, orden),
                Nombre = u.Nombre is null ? u.Codigo : $"{u.Codigo} · {u.Nombre}",
                Rects = (List<RectPlano>)[new RectPlano(u.X, u.Y, u.Ancho, u.Alto), .. Plano.LeerPartes(u.PlanoPartes)],
            });
        var elementos = (await _context.ElementosPlano.AsNoTracking()
                .Where(e => e.AlmacenId == almacenId && e.Id != elementoId)
                .ToListAsync())
            .Select(e => new
            {
                Pisos = (IReadOnlyList<int?>)PisosDe(e.PisoId, e.HastaPisoId, orden),
                e.Nombre,
                Rects = (List<RectPlano>)[new RectPlano(e.X, e.Y, e.Ancho, e.Alto)],
            });

        foreach (var otro in lugares.Concat(elementos))
        {
            var comun = otro.Pisos.FirstOrDefault(p => pisos.Contains(p));
            if (!otro.Pisos.Any(p => pisos.Contains(p))) continue;
            if (!otro.Rects.Any(a => rects.Any(r => r.Choca(a)))) continue;
            // Si el choque es en otro piso que el de siempre (una escalera que cruza), se dice en cuál.
            var enPiso = pisos.Count > 1 && comun is int c && codigos.TryGetValue(c, out var codigo) ? $" en {codigo}" : "";
            throw new ConflictException($"Se encima con {otro.Nombre}{enPiso}.");
        }
    }

    private static ElementoPlanoResponse Respuesta(ElementoPlano e, List<int> orden) => new()
    {
        Id = e.Id,
        PisoId = e.PisoId,
        HastaPisoId = e.HastaPisoId,
        Pisos = PisosDe(e.PisoId, e.HastaPisoId, orden).OfType<int>().ToList(),
        Tipo = e.Tipo,
        Nombre = e.Nombre,
        X = e.X,
        Y = e.Y,
        Ancho = e.Ancho,
        Alto = e.Alto,
    };
}
