using Backend.Dtos.Requests;
using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

public interface IEmpresaService
{
    Task<IEnumerable<EmpresaResponse>> GetAllAsync();
    Task<EmpresaResponse> GetByIdAsync(int id);

    /// <summary>Empresa con la que opera el sistema.</summary>
    Task<EmpresaResponse> GetActivaAsync();

    Task<EmpresaResponse> CreateAsync(CreateEmpresaRequest request);
    Task<EmpresaResponse> UpdateAsync(int id, UpdateEmpresaRequest request);

    /// <summary>Activa una empresa y desactiva la que lo estuviera.</summary>
    Task<EmpresaResponse> ActivarAsync(int id);

    /// <summary>Habilita o retira una empresa sin eliminarla.</summary>
    Task<EmpresaResponse> CambiarHabilitacionAsync(int id, bool habilitada);

    /// <summary>
    /// Sube el certificado digital (.pem) de la empresa a la API de facturación, que lo guarda por RUC. Sin él no se
    /// pueden firmar comprobantes.
    /// </summary>
    Task<SubirCertificadoResponse> SubirCertificadoAsync(int id, string pem);

    Task DeleteAsync(int id);
}

/// <summary>Lo que pasó al subir el certificado: el mensaje de la API, sus advertencias y la empresa ya actualizada.</summary>
public class SubirCertificadoResponse
{
    public string Mensaje { get; set; } = string.Empty;
    public List<string> Advertencias { get; set; } = [];
    public EmpresaResponse Empresa { get; set; } = new();
}
