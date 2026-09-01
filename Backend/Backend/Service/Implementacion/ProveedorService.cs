using System.Text.RegularExpressions;
using Backend.Dtos.Requests;
using Backend.Dtos.Responses;
using Backend.Exceptions;
using Backend.Models;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;
using FluentValidation;

namespace Backend.Service.Implementacion;

public partial class ProveedorService : IProveedorService
{
    private readonly IProveedorRepository _repository;
    private readonly IValidator<CreateProveedorRequest> _createValidator;
    private readonly IValidator<UpdateProveedorRequest> _updateValidator;

    public ProveedorService(IProveedorRepository repository,
        IValidator<CreateProveedorRequest> createValidator,
        IValidator<UpdateProveedorRequest> updateValidator)
    {
        _repository = repository;
        _createValidator = createValidator;
        _updateValidator = updateValidator;
    }

    public async Task<IEnumerable<ProveedorResponse>> GetAllAsync()
    {
        var proveedores = await _repository.GetAllAsync();

        // Se devuelven tambien los inactivos: si no, un registro desactivado
        // desaparece de la pantalla y ya no hay forma de reactivarlo.
        return proveedores.OrderByDescending(p => p.Activo)
            .ThenBy(p => p.Nombre)
            .Select(MapToResponse);
    }

    public async Task<ProveedorResponse> GetByIdAsync(int id)
    {
        return MapToResponse(await GetOrThrowAsync(id));
    }

    public async Task<ProveedorResponse> CreateAsync(CreateProveedorRequest request)
    {
        await _createValidator.ValidateAndThrowAsync(request);

        if (await _repository.ExistsByDocumentoAsync(request.Documento))
        {
            throw new ConflictException("Ya existe un proveedor con ese documento");
        }

        var proveedor = new Proveedor();
        Aplicar(proveedor, request);

        await _repository.AddAsync(proveedor);
        return MapToResponse(proveedor);
    }

    public async Task<ProveedorResponse> UpdateAsync(int id, UpdateProveedorRequest request)
    {
        await _updateValidator.ValidateAndThrowAsync(request);

        var proveedor = await GetOrThrowAsync(id);

        if (await _repository.ExistsByDocumentoAsync(request.Documento, id))
        {
            throw new ConflictException("Ya existe un proveedor con ese documento");
        }

        Aplicar(proveedor, request);
        proveedor.Activo = request.Activo;

        await _repository.UpdateAsync(proveedor);
        return MapToResponse(proveedor);
    }

    public async Task<ProveedorResponse> CambiarEstadoAsync(int id, bool activo)
    {
        var proveedor = await GetOrThrowAsync(id);

        if (proveedor.Activo != activo)
        {
            proveedor.Activo = activo;
            await _repository.UpdateAsync(proveedor);
        }

        return MapToResponse(proveedor);
    }

    public async Task DeleteAsync(int id)
    {
        await _repository.DeleteAsync(await GetOrThrowAsync(id));
    }

    /// <summary>Alta masiva desde archivo, fila por fila. Ver ClienteService.</summary>
    public async Task<ImportarResponse> ImportarAsync(ImportarProveedoresRequest request)
    {
        var resultado = new ImportarResponse();
        var vistos = new HashSet<string>();

        for (var i = 0; i < request.Filas.Count; i++)
        {
            var fila = request.Filas[i];
            var numero = i + 1;
            var documento = fila.Documento?.Trim() ?? string.Empty;

            try
            {
                // Limpiar ANTES de validar: el archivo trae el rubro en la
                // columna de correo y celdas con el texto "NULL". Si se valida
                // primero, esas filas se rechazan por un correo que en
                // realidad no era un correo.
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
                            Motivo = "Ya existe un proveedor con ese documento"
                        });
                        continue;
                    }

                    Aplicar(existente, fila);
                    existente.Activo = true;
                    await _repository.UpdateAsync(existente);
                    resultado.Actualizados++;
                    continue;
                }

                var proveedor = new Proveedor();
                Aplicar(proveedor, fila);
                await _repository.AddAsync(proveedor);
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

        return resultado;
    }

    /// <summary>
    /// Deja la fila del archivo lista para validar: recorta espacios, descarta
    /// los "NULL" y saca de Email lo que no sea un correo, moviendolo a Rubro.
    /// </summary>
    private static void NormalizarFila(ProveedorRequestBase fila)
    {
        fila.Documento = fila.Documento?.Trim() ?? string.Empty;
        fila.Nombre = fila.Nombre?.Trim() ?? string.Empty;
        fila.NombreComercial = Limpiar(fila.NombreComercial);
        fila.Direccion = Limpiar(fila.Direccion);
        fila.Departamento = Limpiar(fila.Departamento);
        fila.Distrito = Limpiar(fila.Distrito);
        fila.Telefono = Limpiar(fila.Telefono);
        fila.Telefono2 = Limpiar(fila.Telefono2);
        fila.Rubro = Limpiar(fila.Rubro);

        var email = Limpiar(fila.Email);
        if (email is not null && !EsCorreo().IsMatch(email))
        {
            fila.Rubro ??= email;
            email = null;
        }

        fila.Email = email;
    }

    private static void Aplicar(Proveedor proveedor, ProveedorRequestBase request)
    {
        proveedor.Documento = request.Documento.Trim();
        proveedor.TipoDoc = TipoDocumento.Deducir(proveedor.Documento);
        proveedor.Nombre = request.Nombre.Trim();
        proveedor.NombreComercial = Limpiar(request.NombreComercial);
        proveedor.Direccion = Limpiar(request.Direccion);
        proveedor.Departamento = Limpiar(request.Departamento);
        proveedor.Distrito = Limpiar(request.Distrito);
        proveedor.Telefono = Limpiar(request.Telefono);
        proveedor.Telefono2 = Limpiar(request.Telefono2);
        proveedor.Rubro = Limpiar(request.Rubro);

        // Lo que no es un correo ya se movio a Rubro en NormalizarFila; aqui
        // se repite la guarda para las altas hechas a mano desde la pantalla.
        var email = Limpiar(request.Email);
        if (email is not null && !EsCorreo().IsMatch(email))
        {
            proveedor.Rubro ??= email;
            email = null;
        }

        proveedor.Email = email;
    }

    private static string? Limpiar(string? texto)
    {
        var limpio = texto?.Trim();
        if (string.IsNullOrEmpty(limpio)) return null;
        return limpio.Equals("NULL", StringComparison.OrdinalIgnoreCase) ? null : limpio;
    }

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex EsCorreo();

    private async Task<Proveedor> GetOrThrowAsync(int id)
    {
        return await _repository.GetByIdAsync(id)
            ?? throw new NotFoundException("Proveedor no encontrado");
    }

    private static ProveedorResponse MapToResponse(Proveedor proveedor)
    {
        return new ProveedorResponse
        {
            Id = proveedor.Id,
            Documento = proveedor.Documento,
            TipoDoc = proveedor.TipoDoc,
            Nombre = proveedor.Nombre,
            NombreComercial = proveedor.NombreComercial,
            Direccion = proveedor.Direccion,
            Departamento = proveedor.Departamento,
            Distrito = proveedor.Distrito,
            Telefono = proveedor.Telefono,
            Telefono2 = proveedor.Telefono2,
            Email = proveedor.Email,
            Rubro = proveedor.Rubro,
            Activo = proveedor.Activo,
            FechaCreacion = proveedor.FechaCreacion
        };
    }
}
