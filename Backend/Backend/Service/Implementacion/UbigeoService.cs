using Backend.Dtos.Responses;
using Backend.Repository.Interfaces;
using Backend.Service.Interfaces;

namespace Backend.Service.Implementacion;

/// <summary>
/// Ubigeo (departamento/provincia/distrito): división política oficial del
/// Perú, precargada. Solo lectura — no hay alta, edición ni baja.
/// </summary>
public class UbigeoService : IUbigeoService
{
    private readonly IUbigeoRepository _repository;

    public UbigeoService(IUbigeoRepository repository)
    {
        _repository = repository;
    }

    public async Task<IEnumerable<DepartamentoResponse>> GetDepartamentosAsync()
    {
        var departamentos = await _repository.GetDepartamentosAsync();
        return departamentos.Select(d => new DepartamentoResponse
        {
            Id = d.Id,
            Codigo = d.Codigo,
            Nombre = d.Nombre
        });
    }

    public async Task<IEnumerable<ProvinciaResponse>> GetProvinciasAsync(int? departamentoId)
    {
        var provincias = await _repository.GetProvinciasAsync(departamentoId);
        return provincias.Select(p => new ProvinciaResponse
        {
            Id = p.Id,
            Codigo = p.Codigo,
            Nombre = p.Nombre,
            DepartamentoId = p.DepartamentoId
        });
    }

    public async Task<IEnumerable<DistritoResponse>> GetDistritosAsync(int? provinciaId)
    {
        var distritos = await _repository.GetDistritosAsync(provinciaId);
        return distritos.Select(d => new DistritoResponse
        {
            Id = d.Id,
            Codigo = d.Codigo,
            Nombre = d.Nombre,
            ProvinciaId = d.ProvinciaId,
            DepartamentoId = d.Provincia!.DepartamentoId
        });
    }
}
