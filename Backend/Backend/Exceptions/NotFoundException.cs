namespace Backend.Exceptions;

public class NotFoundException : AppException
{
    public NotFoundException(string message) : base(StatusCodes.Status404NotFound, message)
    {
    }
}
