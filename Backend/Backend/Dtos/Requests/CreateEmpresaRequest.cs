namespace Backend.Dtos.Requests;

public class CreateEmpresaRequest : EmpresaRequestBase
{
    /// <summary>
    /// Deja esta empresa como la activa y desactiva la que lo estuviera.
    /// La primera empresa registrada queda activa siempre.
    /// </summary>
    public bool Activa { get; set; }
}
