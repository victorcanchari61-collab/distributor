namespace Backend.Exceptions;

public class ConflictException : AppException
{
    public ConflictException(string message) : base(StatusCodes.Status409Conflict, message)
    {
    }
}
