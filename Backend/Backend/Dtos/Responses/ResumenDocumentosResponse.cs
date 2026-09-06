namespace Backend.Dtos.Responses;

/// <summary>
/// Contadores del listado completo de una familia de documentos de inventario
/// (ajustes, transferencias, recepciones), no de la página visible.
/// </summary>
public class ResumenDocumentosResponse
{
    public int Total { get; set; }
    public int Confirmados { get; set; }
    public int Anulados { get; set; }
}
