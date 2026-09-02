using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

/// <summary>
/// Reglas de la empresa emisora:
///
///   - Pueden registrarse varias empresas, pero solo UNA puede estar activa.
///   - La primera que se registra queda activa siempre.
///   - Activar una desactiva a la anterior, en una sola transaccion.
///   - No se puede desactivar la activa directamente: hay que activar otra.
///   - No se puede eliminar la empresa activa.
///   - Habilitada es otra cosa que Activa: una empresa deshabilitada se retira
///     de circulacion sin borrarla, y no se puede activar hasta rehabilitarla.
///   - La empresa activa no se puede deshabilitar.
/// </summary>
public class EmpresaService : IEmpresaService
{
    private readonly IEmpresaRepository _repository;
    private readonly IValidator<CreateEmpresaRequest> _createValidator;
    private readonly IValidator<UpdateEmpresaRequest> _updateValidator;
    private readonly INotificador _notificador;

    public EmpresaService(IEmpresaRepository repository,
        IValidator<CreateEmpresaRequest> createValidator,
        IValidator<UpdateEmpresaRequest> updateValidator,
        INotificador notificador)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
        _notificador = notificador;
    }

    public async Task<IEnumerable<EmpresaResponse>> GetAllAsync()
    {
        var empresas = await _repository.GetAllAsync();
        return empresas.OrderByDescending(e => e.Activa)
            .ThenBy(e => e.RazonSocial)
            .Select(MapToResponse);
    }

    public async Task<EmpresaResponse> GetByIdAsync(int id)
    {
        return MapToResponse(await GetOrThrowAsync(id));
    }

    public async Task<EmpresaResponse> GetActivaAsync()
    {
        var empresa = await _repository.GetActivaAsync()
            ?? throw new NotFoundException("No hay una empresa activa configurada");

        return MapToResponse(empresa);
    }

    public async Task<EmpresaResponse> CreateAsync(CreateEmpresaRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        if (await _repository.ExistsByRucAsync(request.Ruc))
        {
            throw new ConflictException("Ya existe una empresa con ese RUC");
        }

        // La primera empresa queda activa si o si: el sistema necesita una.
        var esPrimera = !await _repository.AnyAsync();

        var empresa = new Empresa
        {
            RazonSocial = request.RazonSocial,
            NombreComercial = request.NombreComercial,
            Ruc = request.Ruc,
            Direccion = request.Direccion,
            Departamento = request.Departamento,
            Provincia = request.Provincia,
            Distrito = request.Distrito,
            Telefono = request.Telefono,
            Email = request.Email,
            SitioWeb = NormalizarWeb(request.SitioWeb),
            RepresentanteLegal = request.RepresentanteLegal,
            Activa = false,
            Habilitada = true
        };

        await _repository.AddAsync(empresa);

        if (esPrimera || request.Activa)
        {
            await _repository.SetActivaAsync(empresa.Id);
            empresa.Activa = true;
        }

        var creada = MapToResponse(empresa);
        await _notificador.AvisarAsync("empresas", "creado", creada);
        return creada;
    }

    public async Task<EmpresaResponse> UpdateAsync(int id, UpdateEmpresaRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var empresa = await GetOrThrowAsync(id);

        if (await _repository.ExistsByRucAsync(request.Ruc, id))
        {
            throw new ConflictException("Ya existe una empresa con ese RUC");
        }

        // Apagar la activa dejaria al sistema sin empresa: se cambia activando otra.
        if (empresa.Activa && !request.Activa)
        {
            throw new BadRequestException(
                "No se puede desactivar la empresa activa. Activa otra empresa para reemplazarla");
        }

        empresa.RazonSocial = request.RazonSocial;
        empresa.NombreComercial = request.NombreComercial;
        empresa.Ruc = request.Ruc;
        empresa.Direccion = request.Direccion;
        empresa.Departamento = request.Departamento;
        empresa.Provincia = request.Provincia;
        empresa.Distrito = request.Distrito;
        empresa.Telefono = request.Telefono;
        empresa.Email = request.Email;
        empresa.SitioWeb = NormalizarWeb(request.SitioWeb);
        empresa.RepresentanteLegal = request.RepresentanteLegal;

        await _repository.UpdateAsync(empresa);

        if (request.Activa && !empresa.Activa)
        {
            await _repository.SetActivaAsync(empresa.Id);
            empresa.Activa = true;
        }

        var actualizada = MapToResponse(empresa);
        await _notificador.AvisarAsync("empresas", "actualizado", actualizada);
        return actualizada;
    }

    public async Task<EmpresaResponse> ActivarAsync(int id)
    {
        var empresa = await GetOrThrowAsync(id);

        if (!empresa.Habilitada)
        {
            throw new BadRequestException(
                "La empresa está deshabilitada. Habilítala antes de activarla");
        }

        if (!empresa.Activa)
        {
            await _repository.SetActivaAsync(empresa.Id);
            empresa.Activa = true;
            // Activar una empresa desactiva a la anterior: el frontend recarga
            // toda la lista con este mismo aviso, asi que no hace falta un
            // segundo evento para la empresa que quedo desactivada.
            await _notificador.AvisarAsync("empresas", "activado", MapToResponse(empresa));
        }

        return MapToResponse(empresa);
    }

    public async Task<EmpresaResponse> CambiarHabilitacionAsync(int id, bool habilitada)
    {
        var empresa = await GetOrThrowAsync(id);

        // Deshabilitar la que opera dejaria al sistema sin empresa.
        if (empresa.Activa && !habilitada)
        {
            throw new BadRequestException(
                "No se puede deshabilitar la empresa activa. Activa otra empresa primero");
        }

        if (empresa.Habilitada != habilitada)
        {
            empresa.Habilitada = habilitada;
            await _repository.UpdateAsync(empresa);
            await _notificador.AvisarAsync("empresas", "estado", MapToResponse(empresa));
        }

        return MapToResponse(empresa);
    }

    public async Task DeleteAsync(int id)
    {
        var empresa = await GetOrThrowAsync(id);

        if (empresa.Activa)
        {
            throw new ConflictException(
                "No se puede eliminar la empresa activa. Activa otra empresa antes de eliminarla");
        }

        await _repository.DeleteAsync(empresa);
        await _notificador.AvisarAsync("empresas", "eliminado", new { id });
    }

    /// <summary>
    /// Guarda el sitio web siempre con esquema, para que el enlace funcione al
    /// pincharlo. Si el usuario escribe "titanicd.pe" se guarda como
    /// "https://titanicd.pe".
    /// </summary>
    private static string? NormalizarWeb(string? web)
    {
        if (string.IsNullOrWhiteSpace(web)) return null;

        var limpio = web.Trim();
        return limpio.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
               limpio.StartsWith("https://", StringComparison.OrdinalIgnoreCase)
            ? limpio
            : $"https://{limpio}";
    }

    private async Task<Empresa> GetOrThrowAsync(int id)
    {
        return await _repository.GetByIdAsync(id)
            ?? throw new NotFoundException("Empresa no encontrada");
    }

    private static EmpresaResponse MapToResponse(Empresa empresa)
    {
        return new EmpresaResponse
        {
            Id = empresa.Id,
            RazonSocial = empresa.RazonSocial,
            NombreComercial = empresa.NombreComercial,
            Ruc = empresa.Ruc,
            Direccion = empresa.Direccion,
            Departamento = empresa.Departamento,
            Provincia = empresa.Provincia,
            Distrito = empresa.Distrito,
            Telefono = empresa.Telefono,
            Email = empresa.Email,
            SitioWeb = empresa.SitioWeb,
            RepresentanteLegal = empresa.RepresentanteLegal,
            Activa = empresa.Activa,
            Habilitada = empresa.Habilitada,
            FechaCreacion = empresa.FechaCreacion
        };
    }
}
