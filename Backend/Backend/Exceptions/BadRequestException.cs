namespace Backend.Exceptions;

public class BadRequestException : AppException
{
    public BadRequestException(string message) : base(StatusCodes.Status400BadRequest, message)
    {
    }
}
