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
    private readonly IUsuarioRepository _usuarios;
    private readonly IValidator<CreateClienteRequest> _createValidator;
    private readonly IValidator<UpdateClienteRequest> _updateValidator;
    private readonly IPermisoService _permisos;
    private readonly IUsuarioActual _usuarioActual;
    private readonly INotificador _notificador;

    public ClienteService(IClienteRepository repository,
        IMercadoRepository mercados,
        IRutaRepository rutas,
        IUbigeoRepository ubigeo,
        IUsuarioRepository usuarios,
        IValidator<CreateClienteRequest> createValidator,
        IValidator<UpdateClienteRequest> updateValidator,
        IPermisoService permisos,
        IUsuarioActual usuarioActual,
        INotificador notificador)
    {
        _repository = repository;
        _mercados = mercados;
        _rutas = rutas;
        _ubigeo = ubigeo;
        _usuarios = usuarios;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _permisos = permisos;
        _usuarioActual = usuarioActual;
        _notificador = notificador;
    }

    /*
     * El alcance en Clientes limita lo que se TOCA, no lo que se ve: el padron
     * completo hace falta para no dar de alta por segunda vez a alguien que ya
     * existe a nombre de otro vendedor.
     *
     * Se comprueba sobre el cliente ya guardado y no sobre el request: si no,
     * bastaria con mandar otro VendedorId para apropiarse de un cliente ajeno
     * y editarlo en la misma llamada.
     */
    private async Task ExigirAlcanceAsync(Cliente cliente)
    {
        if (_usuarioActual.Id is not int id) return;

        var alcance = await _permisos.AlcanceAsync(id, "maestros.clientes");
        if (alcance == AlcanceDatos.Todos) return;

        if (cliente.VendedorId != id)
        {
            throw new ForbiddenException("Solo puedes modificar los clientes que tienes asignados");
        }
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

    public async Task<PaginaResponse<ClienteResponse>> ListarAsync(ConsultaTablaRequest consulta)
    {
        var (items, total) = await _repository.ListarAsync(consulta);

        return new PaginaResponse<ClienteResponse>
        {
            Items = items.Select(MapToResponse).ToList(),
            Total = total,
            Pagina = consulta.PaginaSegura,
            PorPagina = consulta.PorPaginaSegura
        };
    }

    public Task<ResumenClientesResponse> GetResumenAsync() => _repository.ResumenAsync();

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
            await ResolverDistritoAsync(request), await ResolverVendedorAsync(request));

        await _repository.AddAsync(cliente);
        var response = MapToResponse(cliente);
        await _notificador.AvisarAsync("clientes", "creado", response);
        return response;
    }

    public async Task<ClienteResponse> UpdateAsync(int id, UpdateClienteRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var cliente = await GetOrThrowAsync(id);
        await ExigirAlcanceAsync(cliente);

        if (await _repository.ExistsByDocumentoAsync(request.Documento, id))
        {
            throw new ConflictException("Ya existe un cliente con ese documento");
        }

        Aplicar(cliente, request, await ResolverMercadoAsync(request), await ResolverRutaAsync(request),
            await ResolverDistritoAsync(request), await ResolverVendedorAsync(request));
        cliente.Activo = request.Activo;

        await _repository.UpdateAsync(cliente);
        var response = MapToResponse(cliente);
        await _notificador.AvisarAsync("clientes", "actualizado", response);
        return response;
    }

    public async Task<ClienteResponse> CambiarEstadoAsync(int id, bool activo)
    {
        var cliente = await GetOrThrowAsync(id);
        await ExigirAlcanceAsync(cliente);

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
        await ExigirAlcanceAsync(cliente);
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
                        await ResolverDistritoAsync(fila), await ResolverVendedorAsync(fila));
                    existente.Activo = true;
                    await _repository.UpdateAsync(existente);
                    resultado.Actualizados++;
                    continue;
                }

                var cliente = new Cliente();
                Aplicar(cliente, fila, await ResolverMercadoAsync(fila), await ResolverRutaAsync(fila),
                    await ResolverDistritoAsync(fila), await ResolverVendedorAsync(fila));
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
        fila.DistritoNombre = Limpiar(fila.DistritoNombre);
        fila.Telefono = Limpiar(fila.Telefono);
        fila.Email = Limpiar(fila.Email);
        fila.DiaVisita = Limpiar(fila.DiaVisita);
        fila.RutaNombre = Limpiar(fila.RutaNombre);
        fila.MercadoNombre = Limpiar(fila.MercadoNombre);
    }

    private static void Aplicar(Cliente cliente, ClienteRequestBase request, Mercado? mercado, Ruta? ruta,
        Distrito? distrito, Usuario? vendedor)
    {
        cliente.Documento = request.Documento.Trim();
        // Si el usuario eligio el tipo se respeta; si no (importacion), se deduce
        // del largo. Asi un codigo interno de 8 digitos no termina como DNI.
        cliente.TipoDoc = string.IsNullOrWhiteSpace(request.TipoDoc)
            ? TipoDocumento.Deducir(cliente.Documento)
            : request.TipoDoc.Trim().ToUpperInvariant();
        cliente.Nombre = request.Nombre.Trim();
        cliente.Direccion = Limpiar(request.Direccion);
        cliente.DistritoId = distrito?.Id;
        cliente.Distrito = distrito;
        cliente.Telefono = Limpiar(request.Telefono);
        cliente.Email = Limpiar(request.Email);
        cliente.DiaVisita = DiaSemana.Normalizar(request.DiaVisita);
        cliente.RutaId = ruta?.Id;
        cliente.Ruta = ruta;
        cliente.MercadoId = mercado?.Id;
        cliente.Mercado = mercado;
        // El 0 del formulario significa "sin asignar": se guarda como nulo.
        cliente.VendedorId = vendedor?.Id;
        cliente.Vendedor = vendedor;
    }

    /// <summary>
    /// Resuelve el vendedor: cualquier usuario activo, no solo los del rol
    /// Vendedor.
    ///
    /// Se comprueba que exista antes de guardar para que un id inventado
    /// devuelva un mensaje claro y no un error de base de datos.
    /// </summary>
    private async Task<Usuario?> ResolverVendedorAsync(ClienteRequestBase request)
    {
        // 0 es "sin asignar": es lo que manda el formulario cuando se deja vacío.
        if (request.VendedorId is not > 0) return null;

        var usuario = await _usuarios.GetByIdAsync(request.VendedorId.Value)
            ?? throw new BadRequestException("El vendedor indicado no existe");

        if (!usuario.Activo)
        {
            throw new BadRequestException("El vendedor indicado está desactivado");
        }

        return usuario;
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

    /// <summary>
    /// Resuelve el distrito del request contra el ubigeo oficial: si viene un
    /// id, valida que exista; si no, y viene un nombre (importación), busca
    /// uno igual sin importar mayúsculas — a diferencia de mercado y ruta, no
    /// se crea uno nuevo, porque el catálogo es fijo (INEI/RENIEC). Sin
    /// ninguno de los dos, o si el nombre no coincide con ninguno, no hay
    /// distrito — no es obligatorio.
    /// </summary>
    private async Task<Distrito?> ResolverDistritoAsync(ClienteRequestBase request)
    {
        if (request.DistritoId is int id)
        {
            return await _ubigeo.GetDistritoByIdAsync(id)
                ?? throw new BadRequestException("El distrito indicado no existe");
        }

        var nombre = Limpiar(request.DistritoNombre);
        if (nombre is null) return null;

        var existentes = await _ubigeo.GetDistritosAsync(null);
        return existentes.FirstOrDefault(d => d.Nombre.Equals(nombre, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>Texto util o null: recorta y descarta vacios y el literal "NULL".</summary>
    private static string? Limpiar(string? texto)
    {
        var limpio = texto?.Trim();
        if (string.IsNullOrEmpty(limpio)) return null;
        return limpio.Equals("NULL", StringComparison.OrdinalIgnoreCase) ? null : limpio;
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
            DistritoId = cliente.DistritoId,
            Distrito = cliente.Distrito?.Nombre,
            ProvinciaId = cliente.Distrito?.ProvinciaId,
            Provincia = cliente.Distrito?.Provincia?.Nombre,
            DepartamentoId = cliente.Distrito?.Provincia?.DepartamentoId,
            Departamento = cliente.Distrito?.Provincia?.Departamento?.Nombre,
            Telefono = cliente.Telefono,
            Email = cliente.Email,
            DiaVisita = cliente.DiaVisita,
            RutaId = cliente.RutaId,
            Ruta = cliente.Ruta?.Nombre,
            MercadoId = cliente.MercadoId,
            Mercado = cliente.Mercado?.Nombre,
            VendedorId = cliente.VendedorId,
            Vendedor = cliente.Vendedor?.Nombre,
            Activo = cliente.Activo,
            FechaCreacion = cliente.FechaCreacion
        };
    }
}
