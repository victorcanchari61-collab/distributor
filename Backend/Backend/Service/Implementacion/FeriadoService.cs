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

    public FeriadoService(IFeriadoRepository repository, IValidator<FeriadoRequest> validator, INotificador notificador)
    {
        _repository = repository;
        _validator = validator;
        _notificador = notificador;
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

        var feriado = new Feriado { Fecha = fecha, Nombre = request.Nombre.Trim() };
        await _repository.AddAsync(feriado);
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

        feriado.Fecha = fecha;
        feriado.Nombre = request.Nombre.Trim();

        await _repository.UpdateAsync(feriado);
        var response = Map(feriado);
        await _notificador.AvisarAsync("feriados", "actualizado", response);
        return response;
    }

    public async Task DeleteAsync(int id)
    {
        var feriado = await GetOrThrowAsync(id);
        await _repository.DeleteAsync(feriado);
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
