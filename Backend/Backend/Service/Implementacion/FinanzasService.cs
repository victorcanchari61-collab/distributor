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
    private readonly IValidator<CreateMetodoPagoRequest> _createMetodoPago;
    private readonly IValidator<UpdateMetodoPagoRequest> _updateMetodoPago;
    private readonly INotificador _notificador;

    public FinanzasService(
        IFinanzasRepository repository,
        IValidator<CreateMetodoPagoRequest> createMetodoPago,
        IValidator<UpdateMetodoPagoRequest> updateMetodoPago,
        INotificador notificador)
    {
        _repository = repository;
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

        var metodo = new MetodoPago { Nombre = nombre, Activo = true };
        AplicarDatosBancarios(metodo, request);

        await _repository.AddMetodoPagoAsync(metodo);
        var response = MapMetodoPago(metodo, 0);
        await _notificador.AvisarAsync("metodospago", "creado", response);
        return response;
    }

    public async Task<MetodoPagoResponse> UpdateMetodoPagoAsync(int id, UpdateMetodoPagoRequest request)
    {
        await _updateMetodoPago.ValidateAndThrowAsync(request);

        var metodo = await GetMetodoPagoOrThrowAsync(id);
        var nombre = request.Nombre.Trim();

        if (await _repository.ExisteNombreMetodoPagoAsync(nombre, id))
        {
            throw new ConflictException("Ya existe un método de pago con ese nombre");
        }

        metodo.Nombre = nombre;
        metodo.Activo = request.Activo;
        AplicarDatosBancarios(metodo, request);

        await _repository.UpdateMetodoPagoAsync(metodo);
        var response = MapMetodoPago(metodo, await _repository.ContarUsosMetodoPagoAsync(id));
        await _notificador.AvisarAsync("metodospago", "actualizado", response);
        return response;
    }

    public async Task DeleteMetodoPagoAsync(int id)
    {
        var metodo = await GetMetodoPagoOrThrowAsync(id);
        var usos = await _repository.ContarUsosMetodoPagoAsync(id);

        if (usos > 0)
        {
            throw new BadRequestException(
                $"El método de pago tiene {usos} documento(s). Desactívalo en vez de eliminarlo.");
        }

        await _repository.DeleteMetodoPagoAsync(metodo);
        await _notificador.AvisarAsync("metodospago", "eliminado", new { id });
    }

    // -------------------------------------------------------- Arqueo de caja

    public async Task<ArqueoResumenResponse> GetResumenArqueoAsync(DateTime fecha)
    {
        var cobrado = await _repository.GetCobradoEfectivoAsync(fecha);
        var pagado = await _repository.GetPagadoEfectivoAsync(fecha);
        var arqueo = await _repository.GetArqueoAsync(fecha);

        return new ArqueoResumenResponse
        {
            Fecha = fecha.Date,
            CobradoEfectivo = cobrado,
            PagadoEfectivo = pagado,
            MontoEsperado = cobrado - pagado,
            Arqueo = arqueo is null ? null : MapArqueo(arqueo)
        };
    }

    public async Task<IEnumerable<ArqueoCajaResponse>> GetHistorialArqueoAsync()
    {
        var historial = await _repository.GetHistorialArqueoAsync();
        return historial.Select(MapArqueo);
    }

    public async Task<ArqueoCajaResponse> RegistrarArqueoAsync(RegistrarArqueoRequest request, int? usuarioId)
    {
        var cobrado = await _repository.GetCobradoEfectivoAsync(request.Fecha);
        var pagado = await _repository.GetPagadoEfectivoAsync(request.Fecha);

        var arqueo = new ArqueoCaja
        {
            Fecha = request.Fecha.Date,
            MontoEsperado = cobrado - pagado,
            MontoContado = request.MontoContado,
            Observacion = Limpiar(request.Observacion),
            UsuarioId = usuarioId
        };

        var guardado = await _repository.GuardarArqueoAsync(arqueo);
        var conUsuario = await _repository.GetArqueoAsync(guardado.Fecha) ?? guardado;

        var response = MapArqueo(conUsuario);
        await _notificador.AvisarAsync("arqueo", "registrado", response);
        return response;
    }

    private static ArqueoCajaResponse MapArqueo(ArqueoCaja a) => new()
    {
        Id = a.Id,
        Fecha = a.Fecha,
        MontoEsperado = a.MontoEsperado,
        MontoContado = a.MontoContado,
        Diferencia = Math.Round(a.MontoContado - a.MontoEsperado, 2),
        Observacion = a.Observacion,
        Usuario = a.Usuario?.Nombre,
        FechaCreacion = a.FechaCreacion
    };

    // ------------------------------------------------------------ Auxiliares

    private async Task<MetodoPago> GetMetodoPagoOrThrowAsync(int id) =>
        await _repository.GetMetodoPagoAsync(id)
        ?? throw new NotFoundException($"No existe el método de pago {id}");

    /// <summary>
    /// El efectivo no guarda banco ni cuenta: aunque llegaran en el request se
    /// descartan, para que cambiar de tipo no deje datos bancarios huerfanos.
    /// El CCI solo tiene sentido en transferencia, nunca en billetera digital.
    /// </summary>
    private static void AplicarDatosBancarios(MetodoPago metodo, MetodoPagoRequestBase request)
    {
        metodo.Tipo = request.Tipo;

        if (request.Tipo == TipoMetodoPago.Efectivo)
        {
            metodo.Banco = null;
            metodo.NumeroCuenta = null;
            metodo.Cci = null;
            metodo.Titular = null;
            return;
        }

        metodo.Banco = Limpiar(request.Banco);
        metodo.NumeroCuenta = Limpiar(request.NumeroCuenta);
        metodo.Cci = request.Tipo == TipoMetodoPago.Transferencia ? Limpiar(request.Cci) : null;
        metodo.Titular = Limpiar(request.Titular);
    }

    private static string? Limpiar(string? texto) =>
        string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static MetodoPagoResponse MapMetodoPago(MetodoPago m, int usos) => new()
    {
        Id = m.Id,
        Nombre = m.Nombre,
        Tipo = m.Tipo,
        Banco = m.Banco,
        NumeroCuenta = m.NumeroCuenta,
        Cci = m.Cci,
        Titular = m.Titular,
        Activo = m.Activo,
        Usos = usos
    };
}
