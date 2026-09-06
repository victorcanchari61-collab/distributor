namespace Backend.Dtos.Responses;

public class DepartamentoResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
}

public class ProvinciaResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public int DepartamentoId { get; set; }
}

public class DistritoResponse
{
    public int Id { get; set; }
    public string Codigo { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public int ProvinciaId { get; set; }
    public int DepartamentoId { get; set; }
}
