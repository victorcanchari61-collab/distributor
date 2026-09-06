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
    private readonly IMercadoRepository _mercados;
    private readonly IRutaRepository _rutas;
    private readonly IUbigeoRepository _ubigeo;
    private readonly IValidator<CreateClienteRequest> _createValidator;
    private readonly IValidator<UpdateClienteRequest> _updateValidator;
    private readonly INotificador _notificador;

    public ClienteService(IClienteRepository repository,
        IMercadoRepository mercados,
        IRutaRepository rutas,
        IUbigeoRepository ubigeo,
        IValidator<CreateClienteRequest> createValidator,
        IValidator<UpdateClienteRequest> updateValidator,
        INotificador notificador)
    {
        _repository = repository;
        _mercados = mercados;
        _rutas = rutas;
        _ubigeo = ubigeo;
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
        Aplicar(cliente, request, await ResolverMercadoAsync(request), await ResolverRutaAsync(request),
            await ResolverDistritoAsync(request));

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

        Aplicar(cliente, request, await ResolverMercadoAsync(request), await ResolverRutaAsync(request),
            await ResolverDistritoAsync(request));
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

                    Aplicar(existente, fila, await ResolverMercadoAsync(fila), await ResolverRutaAsync(fila),
                        await ResolverDistritoAsync(fila));
                    existente.Activo = true;
                    await _repository.UpdateAsync(existente);
                    resultado.Actualizados++;
                    continue;
                }

                var cliente = new Cliente();
                Aplicar(cliente, fila, await ResolverMercadoAsync(fila), await ResolverRutaAsync(fila),
                    await ResolverDistritoAsync(fila));
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
        fila.RutaNombre = Limpiar(fila.RutaNombre);
        fila.MercadoNombre = Limpiar(fila.MercadoNombre);
    }

    private static void Aplicar(Cliente cliente, ClienteRequestBase request, Mercado? mercado, Ruta? ruta)
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
        cliente.RutaId = ruta?.Id;
        cliente.Ruta = ruta;
        cliente.MercadoId = mercado?.Id;
        cliente.Mercado = mercado;
    }

    /// <summary>
    /// Resuelve el mercado del request: si viene un id, valida que exista y
    /// esté activo; si no, y viene un nombre (importación), busca uno igual
    /// sin importar mayúsculas o lo crea. Sin ninguno de los dos, no hay
    /// mercado — no es obligatorio.
    /// </summary>
    private async Task<Mercado?> ResolverMercadoAsync(ClienteRequestBase request)
    {
        if (request.MercadoId is int id)
        {
            var mercado = await _mercados.GetByIdAsync(id)
                ?? throw new BadRequestException("El mercado indicado no existe");

            if (!mercado.Activo)
            {
                throw new BadRequestException("El mercado indicado está desactivado");
            }

            return mercado;
        }

        var nombre = Limpiar(request.MercadoNombre);
        if (nombre is null) return null;

        var existentes = await _mercados.GetAllAsync();
        var encontrado = existentes.FirstOrDefault(
            m => m.Nombre.Equals(nombre, StringComparison.OrdinalIgnoreCase));
        if (encontrado is not null) return encontrado;

        return await _mercados.AddAsync(new Mercado { Nombre = nombre, Activo = true });
    }

    /// <summary>
    /// Resuelve la ruta del request: si viene un id, valida que exista y esté
    /// activa; si no, y viene un nombre (importación), busca una igual sin
    /// importar mayúsculas o la crea. Sin ninguno de los dos, no hay ruta —
    /// no es obligatoria.
    /// </summary>
    private async Task<Ruta?> ResolverRutaAsync(ClienteRequestBase request)
    {
        if (request.RutaId is int id)
        {
            var ruta = await _rutas.GetByIdAsync(id)
                ?? throw new BadRequestException("La ruta indicada no existe");

            if (!ruta.Activo)
            {
                throw new BadRequestException("La ruta indicada está desactivada");
            }

            return ruta;
        }

        var nombre = Limpiar(request.RutaNombre);
        if (nombre is null) return null;

        var existentes = await _rutas.GetAllAsync();
        var encontrada = existentes.FirstOrDefault(
            r => r.Nombre.Equals(nombre, StringComparison.OrdinalIgnoreCase));
        if (encontrada is not null) return encontrada;

        return await _rutas.AddAsync(new Ruta { Nombre = nombre, Activo = true });
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
            RutaId = cliente.RutaId,
            Ruta = cliente.Ruta?.Nombre,
            MercadoId = cliente.MercadoId,
            Mercado = cliente.Mercado?.Nombre,
            Activo = cliente.Activo,
            FechaCreacion = cliente.FechaCreacion
        };
    }
}
