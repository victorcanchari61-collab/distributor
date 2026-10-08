using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

public class FeriadoService : IFeriadoService
{
    private readonly IFeriadoRepository _repository;
    private readonly IValidator<FeriadoRequest> _validator;
    private readonly INotificador _notificador;
    private readonly IPlanillaService _planillas;

    public FeriadoService(
        IFeriadoRepository repository,
        IValidator<FeriadoRequest> validator,
        INotificador notificador,
        IPlanillaService planillas)
    {
        _repository = repository;
        _validator = validator;
        _notificador = notificador;
        _planillas = planillas;
    }

    public async Task<IEnumerable<FeriadoResponse>> GetAllAsync()
    {
        var feriados = await _repository.GetAllAsync();
        return feriados.OrderBy(f => f.Fecha).Select(Map);
    }

    public async Task<FeriadoResponse> CreateAsync(FeriadoRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        var fecha = request.Fecha.Date;
        if (await _repository.ExistsByFechaAsync(fecha))
        {
            throw new ConflictException("Ya hay un feriado registrado ese día");
        }

        // Un feriado cambia lo que se paga esa semana: si ya está pagada no se agrega, y si está
        // en borrador se recalcula.
        var feriado = await _planillas.CambiarDiasAsync([fecha], async () =>
        {
            var nuevo = new Feriado { Fecha = fecha, Nombre = request.Nombre.Trim() };
            await _repository.AddAsync(nuevo);
            return nuevo;
        });
        var response = Map(feriado);
        await _notificador.AvisarAsync("feriados", "creado", response);
        return response;
    }

    public async Task<FeriadoResponse> UpdateAsync(int id, FeriadoRequest request)
    {
        await _validator.ValidateAndThrowAsync(request);

        var feriado = await GetOrThrowAsync(id);

        var fecha = request.Fecha.Date;
        if (await _repository.ExistsByFechaAsync(fecha, id))
        {
            throw new ConflictException("Ya hay un feriado registrado ese día");
        }

        // Toca dos semanas si se mueve de fecha: la que deja y la que recibe.
        await _planillas.CambiarDiasAsync([feriado.Fecha, fecha], async () =>
        {
            feriado.Fecha = fecha;
            feriado.Nombre = request.Nombre.Trim();
            await _repository.UpdateAsync(feriado);
            return feriado;
        });
        var response = Map(feriado);
        await _notificador.AvisarAsync("feriados", "actualizado", response);
        return response;
    }

    public async Task DeleteAsync(int id)
    {
        var feriado = await GetOrThrowAsync(id);
        await _planillas.CambiarDiasAsync([feriado.Fecha], async () =>
        {
            await _repository.DeleteAsync(feriado);
            return feriado;
        });
        await _notificador.AvisarAsync("feriados", "eliminado", new { id });
    }

    private static FeriadoResponse Map(Feriado f) => new()
    {
        Id = f.Id,
        Fecha = f.Fecha,
        Nombre = f.Nombre,
    };

    private async Task<Feriado> GetOrThrowAsync(int id) =>
        await _repository.GetByIdAsync(id) ?? throw new NotFoundException($"No existe el feriado {id}");
}
