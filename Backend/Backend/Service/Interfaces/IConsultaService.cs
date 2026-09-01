using Backend.Dtos.Responses;

namespace Backend.Service.Interfaces;

/// <summary>Consultas a fuentes externas (SUNAT y RENIEC vía apisperu).</summary>
public interface IConsultaService
{
    Task<ConsultaRucResponse> ConsultarRucAsync(string ruc);
    Task<ConsultaDniResponse> ConsultarDniAsync(string dni);
}
