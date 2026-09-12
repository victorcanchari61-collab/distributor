namespace Backend.Exceptions;

/// <summary>
/// Tiene sesión y el permiso de la acción, pero no sobre ESA fila.
///
/// Es un 403 y no un 404 a propósito: el registro existe y la persona sabe que
/// existe — lo tiene delante en el listado —, así que fingir que no está solo
/// haría parecer que el sistema perdió un dato.
/// </summary>
public class ForbiddenException : AppException
{
    public ForbiddenException(string message)
        : base(StatusCodes.Status403Forbidden, message)
    {
    }
}
