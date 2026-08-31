namespace Backend.Dtos.Requests;

public class UpdateEmpresaRequest : EmpresaRequestBase
{
    /// <summary>
    /// Solo se puede pasar a true. Para desactivar una empresa hay que activar
    /// otra, porque el sistema siempre opera con una.
    /// </summary>
    public bool Activa { get; set; }
}
