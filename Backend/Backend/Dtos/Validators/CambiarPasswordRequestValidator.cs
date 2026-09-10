using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CambiarPasswordRequestValidator : AbstractValidator<CambiarPasswordRequest>
{
    public CambiarPasswordRequestValidator()
    {
        RuleFor(x => x.PasswordActual).NotEmpty().WithMessage("Ingresa tu contraseña actual");

        RuleFor(x => x.PasswordNueva)
            .NotEmpty().WithMessage("Ingresa la nueva contraseña")
            .MinimumLength(6).WithMessage("La nueva contraseña debe tener al menos 6 caracteres")
            .MaximumLength(100)
            .NotEqual(x => x.PasswordActual)
            .WithMessage("La nueva contraseña debe ser distinta a la actual");
    }
}
