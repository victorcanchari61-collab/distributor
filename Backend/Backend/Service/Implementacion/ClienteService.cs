using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

public class ClienteService : IClienteService
{
    private readonly IClienteRepository _repository;
    private readonly IValidator<CreateClienteRequest> _createValidator;
    private readonly IValidator<UpdateClienteRequest> _updateValidator;
    private readonly INotificador _notificador;

    public ClienteService(IClienteRepository repository,
        IValidator<CreateClienteRequest> createValidator,
        IValidator<UpdateClienteRequest> updateValidator,
        INotificador notificador)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<ClienteResponse>> GetAllAsync()
    {
        var clientes = await _repository.GetAllAsync();
        // Se devuelven tambien los inactivos: si no, un registro desactivado
        // desaparece de la pantalla y ya no hay forma de reactivarlo.
        return clientes.OrderByDescending(c => c.Activo)
            .ThenBy(c => c.Nombre)
            .Select(MapToResponse);
    }

    public async Task<ClienteResponse> GetByIdAsync(int id)
    {
        return MapToResponse(await GetOrThrowAsync(id));
    }

    public async Task<ClienteResponse> CreateAsync(CreateClienteRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        if (await _repository.ExistsByDocumentoAsync(request.Documento))
        {
            throw new ConflictException("Ya existe un cliente con ese documento");
        }

        var cliente = new Cliente();
        Aplicar(cliente, request);

        await _repository.AddAsync(cliente);
        var response = MapToResponse(cliente);
        await _notificador.AvisarAsync("clientes", "creado", response);
        return response;
    }

    public async Task<ClienteResponse> UpdateAsync(int id, UpdateClienteRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var cliente = await GetOrThrowAsync(id);

        if (await _repository.ExistsByDocumentoAsync(request.Documento, id))
        {
            throw new ConflictException("Ya existe un cliente con ese documento");
        }

        Aplicar(cliente, request);
        cliente.Activo = request.Activo;

        await _repository.UpdateAsync(cliente);
        var response = MapToResponse(cliente);
        await _notificador.AvisarAsync("clientes", "actualizado", response);
        return response;
    }

    public async Task<ClienteResponse> CambiarEstadoAsync(int id, bool activo)
    {
        var cliente = await GetOrThrowAsync(id);

        if (cliente.Activo != activo)
        {
            cliente.Activo = activo;
            await _repository.UpdateAsync(cliente);
            await _notificador.AvisarAsync("clientes", "estado", MapToResponse(cliente));
        }

        return MapToResponse(cliente);
    }

    public async Task DeleteAsync(int id)
    {
        var cliente = await GetOrThrowAsync(id);
        await _repository.DeleteAsync(cliente);
        await _notificador.AvisarAsync("clientes", "eliminado", new { id });
    }

    /// <summary>
    /// Alta masiva desde archivo.
    ///
    /// Cada fila va por su cuenta: una mala no tumba a las buenas, y el
    /// resultado dice el numero de fila para que el usuario sepa cual corregir
    /// en su Excel.
    /// </summary>
    public async Task<ImportarResponse> ImportarAsync(ImportarClientesRequest request)
    {
        var resultado = new ImportarResponse();

        // Documentos repetidos DENTRO del propio archivo: sin esto, la segunda
        // fila repetida se guardaria como si nada, porque la primera aun no
        // estaba en base cuando se valido.
        var vistos = new HashSet<string>();

        for (var i = 0; i < request.Filas.Count; i++)
        {
            var fila = request.Filas[i];
            var numero = i + 1;
            var documento = fila.Documento?.Trim() ?? string.Empty;

            try
            {
                // Limpiar antes de validar: el archivo trae espacios de sobra
                // y celdas con el texto "NULL", que de otro modo se toman como
                // un correo invalido y tumban la fila.
                NormalizarFila(fila);
                await _createValidator.ValidateAndThrowAsync(fila);

                if (!vistos.Add(documento))
                {
                    resultado.Omitidos++;
                    resultado.Errores.Add(new ImportarFilaError
                    {
                        Fila = numero,
                        Documento = documento,
                        Motivo = "El documento se repite dentro del archivo"
                    });
                    continue;
                }

                var existente = await _repository.GetByDocumentoAsync(documento);

                if (existente is not null)
                {
                    if (!request.ActualizarExistentes)
                    {
                        resultado.Omitidos++;
                        resultado.Errores.Add(new ImportarFilaError
                        {
                            Fila = numero,
                            Documento = documento,
                            Motivo = "Ya existe un cliente con ese documento"
                        });
                        continue;
                    }

                    Aplicar(existente, fila);
                    existente.Activo = true;
                    await _repository.UpdateAsync(existente);
                    resultado.Actualizados++;
                    continue;
                }

                var cliente = new Cliente();
                Aplicar(cliente, fila);
                await _repository.AddAsync(cliente);
                resultado.Creados++;
            }
            catch (ValidationException ex)
            {
                resultado.Omitidos++;
                resultado.Errores.Add(new ImportarFilaError
                {
                    Fila = numero,
                    Documento = documento,
                    Motivo = string.Join(" ", ex.Errors.Select(e => e.ErrorMessage))
                });
            }
        }

        // Un aviso, no uno por fila: una importacion mueve cientos de
        // registros de golpe, y el frontend solo necesita saber "recarga la
        // lista", no cual de las 500 filas cambio.
        if (resultado.Creados > 0 || resultado.Actualizados > 0)
        {
            await _notificador.AvisarAsync("clientes", "importado", resultado);
        }

        return resultado;
    }

    /// <summary>Deja la fila del archivo lista para validar.</summary>
    private static void NormalizarFila(ClienteRequestBase fila)
    {
        fila.Documento = fila.Documento?.Trim() ?? string.Empty;
        fila.Nombre = fila.Nombre?.Trim() ?? string.Empty;
        fila.Direccion = Limpiar(fila.Direccion);
        fila.Distrito = Limpiar(fila.Distrito);
        fila.Telefono = Limpiar(fila.Telefono);
        fila.Email = Limpiar(fila.Email);
        fila.DiaVisita = Limpiar(fila.DiaVisita);
        fila.Ruta = Limpiar(fila.Ruta);
        fila.Mercado = Limpiar(fila.Mercado);
    }

    private static void Aplicar(Cliente cliente, ClienteRequestBase request)
    {
        cliente.Documento = request.Documento.Trim();
        // Si el usuario eligio el tipo se respeta; si no (importacion), se deduce
        // del largo. Asi un codigo interno de 8 digitos no termina como DNI.
        cliente.TipoDoc = string.IsNullOrWhiteSpace(request.TipoDoc)
            ? TipoDocumento.Deducir(cliente.Documento)
            : request.TipoDoc.Trim().ToUpperInvariant();
        cliente.Nombre = request.Nombre.Trim();
        cliente.Direccion = Limpiar(request.Direccion);
        cliente.Distrito = Limpiar(request.Distrito);
        cliente.Telefono = Limpiar(request.Telefono);
        cliente.Email = Limpiar(request.Email);
        cliente.DiaVisita = NormalizarDia(request.DiaVisita);
        cliente.Ruta = Limpiar(request.Ruta);
        cliente.Mercado = Limpiar(request.Mercado);
    }

    /// <summary>Texto util o null: recorta y descarta vacios y el literal "NULL".</summary>
    private static string? Limpiar(string? texto)
    {
        var limpio = texto?.Trim();
        if (string.IsNullOrEmpty(limpio)) return null;
        return limpio.Equals("NULL", StringComparison.OrdinalIgnoreCase) ? null : limpio;
    }

    /// <summary>
    /// El dia de visita viene como MARTES, Martes o MIÉRCOLES segun quien lo
    /// escribio. Se guarda siempre en mayusculas y sin tilde, para poder
    /// agrupar por dia sin sorpresas.
    /// </summary>
    private static string? NormalizarDia(string? dia)
    {
        var limpio = Limpiar(dia);
        if (limpio is null) return null;

        var mayus = limpio.ToUpperInvariant()
            .Replace('Á', 'A').Replace('É', 'E').Replace('Í', 'I')
            .Replace('Ó', 'O').Replace('Ú', 'U');

        return mayus;
    }

    private async Task<Cliente> GetOrThrowAsync(int id)
    {
        return await _repository.GetByIdAsync(id)
            ?? throw new NotFoundException("Cliente no encontrado");
    }

    private static ClienteResponse MapToResponse(Cliente cliente)
    {
        return new ClienteResponse
        {
            Id = cliente.Id,
            Documento = cliente.Documento,
            TipoDoc = cliente.TipoDoc,
            Nombre = cliente.Nombre,
            Direccion = cliente.Direccion,
            Distrito = cliente.Distrito,
            Telefono = cliente.Telefono,
            Email = cliente.Email,
            DiaVisita = cliente.DiaVisita,
            Ruta = cliente.Ruta,
            Mercado = cliente.Mercado,
            Activo = cliente.Activo,
            FechaCreacion = cliente.FechaCreacion
        };
    }
}
