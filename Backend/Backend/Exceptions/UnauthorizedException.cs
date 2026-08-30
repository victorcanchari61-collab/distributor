namespace Backend.Exceptions;

public class UnauthorizedException : AppException
{
    public UnauthorizedException(string message) : base(StatusCodes.Status401Unauthorized, message)
    {
    }
}
