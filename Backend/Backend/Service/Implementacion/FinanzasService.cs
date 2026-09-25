using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Métodos de pago: catálogo compartido por compras, cuentas por cobrar,
/// cuentas por pagar, mis cobros y el arqueo diario.
///
/// El nombre no se repite, y lo que ya esta en uso no se elimina: se
/// desactiva, para no dejar documentos ya registrados apuntando a la nada.
/// </summary>
public class FinanzasService : IFinanzasService
{
    private readonly IFinanzasRepository _repository;
    private readonly ICuentaFinancieraService _cuentas;
    private readonly IValidator<CreateMetodoPagoRequest> _createMetodoPago;
    private readonly IValidator<UpdateMetodoPagoRequest> _updateMetodoPago;
    private readonly INotificador _notificador;

    public FinanzasService(
        IFinanzasRepository repository,
        ICuentaFinancieraService cuentas,
        IValidator<CreateMetodoPagoRequest> createMetodoPago,
        IValidator<UpdateMetodoPagoRequest> updateMetodoPago,
        INotificador notificador)
    {
        _repository = repository;
        _cuentas = cuentas;
        _createMetodoPago = createMetodoPago;
        _updateMetodoPago = updateMetodoPago;
        _notificador = notificador;
    }

    // ---------------------------------------------------------- Metodos de pago

    public async Task<IEnumerable<MetodoPagoResponse>> GetMetodosPagoAsync()
    {
        var metodos = await _repository.GetMetodosPagoAsync();

        var respuesta = new List<MetodoPagoResponse>();
        foreach (var metodo in metodos)
        {
            respuesta.Add(MapMetodoPago(
                metodo,
                await _repository.ContarUsosMetodoPagoAsync(metodo.Id)));
        }

        return respuesta;
    }

    public async Task<MetodoPagoResponse> GetMetodoPagoAsync(int id)
    {
        var metodo = await GetMetodoPagoOrThrowAsync(id);
        return MapMetodoPago(metodo, await _repository.ContarUsosMetodoPagoAsync(id));
    }

    public async Task<MetodoPagoResponse> CreateMetodoPagoAsync(CreateMetodoPagoRequest request)
    {
        await _createMetodoPago.ValidateAndThrowAsync(request);

        var nombre = request.Nombre.Trim();
        if (await _repository.ExisteNombreMetodoPagoAsync(nombre))
        {
            throw new ConflictException("Ya existe un método de pago con ese nombre");
        }

        // Efectivo es único: no se resuelve a una cuenta fija (depende de
        // quién cobra), así que una segunda instancia no tendría sentido.
        if (request.Tipo == TipoMetodoPago.Efectivo
            && await _repository.ExisteTipoMetodoPagoAsync(TipoMetodoPago.Efectivo))
        {
            throw new ConflictException("Ya existe el método Efectivo: no se puede crear otro");
        }

        if (request.Tipo != TipoMetodoPago.Efectivo)
        {
            await ValidarCuentaFinancieraAsync(request.CuentaFinancieraId!.Value);
        }

        var metodo = new MetodoPago { Nombre = nombre, Activo = true };
        AplicarCuentaFinanciera(metodo, request);

        await _repository.AddMetodoPagoAsync(metodo);
        var response = MapMetodoPago(metodo, 0);
        await _notificador.AvisarAsync("metodospago", "creado", response);
        return response;
    }

    public async Task<MetodoPagoResponse> UpdateMetodoPagoAsync(int id, UpdateMetodoPagoRequest request)
    {
        await _updateMetodoPago.ValidateAndThrowAsync(request);

        var metodo = await GetMetodoPagoOrThrowAsync(id);

        // Es fijo: no cambia de tipo, no se le enlaza ni desenlaza una cuenta,
        // no se desactiva. Igual que no se crea una segunda instancia.
        if (metodo.Tipo == TipoMetodoPago.Efectivo)
        {
            throw new BadRequestException("Efectivo es fijo: no se puede editar");
        }

        var nombre = request.Nombre.Trim();

        if (await _repository.ExisteNombreMetodoPagoAsync(nombre, id))
        {
            throw new ConflictException("Ya existe un método de pago con ese nombre");
        }

        if (request.Tipo != TipoMetodoPago.Efectivo)
        {
            await ValidarCuentaFinancieraAsync(request.CuentaFinancieraId!.Value);
        }

        metodo.Nombre = nombre;
        metodo.Activo = request.Activo;
        AplicarCuentaFinanciera(metodo, request);

        await _repository.UpdateMetodoPagoAsync(metodo);
        var response = MapMetodoPago(metodo, await _repository.ContarUsosMetodoPagoAsync(id));
        await _notificador.AvisarAsync("metodospago", "actualizado", response);
        return response;
    }

    public async Task DeleteMetodoPagoAsync(int id)
    {
        var metodo = await GetMetodoPagoOrThrowAsync(id);

        if (metodo.Tipo == TipoMetodoPago.Efectivo)
        {
            throw new BadRequestException("Efectivo es fijo: no se puede eliminar");
        }

        var usos = await _repository.ContarUsosMetodoPagoAsync(id);

        if (usos > 0)
        {
            throw new BadRequestException(
                $"El método de pago tiene {usos} documento(s). Desactívalo en vez de eliminarlo.");
        }

        await _repository.DeleteMetodoPagoAsync(metodo);
        await _notificador.AvisarAsync("metodospago", "eliminado", new { id });
    }


    // ------------------------------------------------------------ Auxiliares

    private async Task<MetodoPago> GetMetodoPagoOrThrowAsync(int id) =>
        await _repository.GetMetodoPagoAsync(id)
        ?? throw new NotFoundException($"No existe el método de pago {id}");

    /// <summary>No apunta a la Caja General: eso es Efectivo, y ese no se enlaza a nada.</summary>
    private async Task ValidarCuentaFinancieraAsync(int cuentaFinancieraId)
    {
        var cuenta = await _cuentas.GetOrThrowAsync(cuentaFinancieraId);
        if (cuenta.Naturaleza == NaturalezaCuenta.Caja)
        {
            throw new BadRequestException("Este método no puede apuntar a la Caja General");
        }
    }

    /// <summary>Efectivo no se enlaza a ninguna cuenta: el validador ya exige que venga vacío.</summary>
    private static void AplicarCuentaFinanciera(MetodoPago metodo, MetodoPagoRequestBase request)
    {
        metodo.Tipo = request.Tipo;
        metodo.CuentaFinancieraId = request.Tipo == TipoMetodoPago.Efectivo ? null : request.CuentaFinancieraId;
        metodo.Numero = request.Tipo == TipoMetodoPago.BilleteraDigital ? request.Numero!.Trim() : null;
    }

    private static MetodoPagoResponse MapMetodoPago(MetodoPago m, int usos) => new()
    {
        Id = m.Id,
        Nombre = m.Nombre,
        Tipo = m.Tipo,
        Numero = m.Numero,
        CuentaFinancieraId = m.CuentaFinancieraId,
        CuentaFinanciera = m.CuentaFinanciera?.Nombre,
        Activo = m.Activo,
        Usos = usos
    };
}
