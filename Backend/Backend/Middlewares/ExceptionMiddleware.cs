using System.Text.Json;
using Backend.Exceptions;
using FluentValidation;

namespace Backend.Middlewares;

public class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _logger;

    public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (ValidationException ex)
        {
            await HandleAsync(context, StatusCodes.Status400BadRequest, "Error de validación",
                ex.Errors.Select(e => e.ErrorMessage));
        }
        catch (AppException ex)
        {
            await HandleAsync(context, ex.StatusCode, ex.Message, null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error no controlado");
            await HandleAsync(context, StatusCodes.Status500InternalServerError,
                "Ocurrió un error interno en el servidor", null);
        }
    }

    private static async Task HandleAsync(HttpContext context, int statusCode, string message,
        IEnumerable<string>? errors)
    {
        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";

        var response = new
        {
            statusCode,
            message,
            errors
        };

        await context.Response.WriteAsync(JsonSerializer.Serialize(response));
    }
}
