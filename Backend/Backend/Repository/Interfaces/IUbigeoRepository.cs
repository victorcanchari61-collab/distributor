using Backend.Models;

namespace Backend.Repository.Interfaces;

/// <summary>Lectura del ubigeo (departamento/provincia/distrito): dato de referencia, no se crea ni edita.</summary>
public interface IUbigeoRepository
{
    Task<IEnumerable<Departamento>> GetDepartamentosAsync();
    Task<IEnumerable<Provincia>> GetProvinciasAsync(int? departamentoId);
    Task<IEnumerable<Distrito>> GetDistritosAsync(int? provinciaId);
    Task<Distrito?> GetDistritoByIdAsync(int id);
}
