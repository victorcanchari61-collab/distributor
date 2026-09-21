using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class LoginRequestValidator : AbstractValidator<LoginRequest>
{
    public LoginRequestValidator()
    {
        // Correo o DNI: ya no es siempre un correo.
        RuleFor(x => x.Email).NotEmpty().MaximumLength(100).WithMessage("Ingresa tu correo o tu DNI");
        RuleFor(x => x.Password).NotEmpty();
    }
}
