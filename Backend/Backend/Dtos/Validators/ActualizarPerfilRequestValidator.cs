using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class ActualizarPerfilRequestValidator : AbstractValidator<ActualizarPerfilRequest>
{
    public ActualizarPerfilRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(100);
        RuleFor(x => x.Dni)
            .Matches("^[0-9]{8}$")
            .When(x => !string.IsNullOrWhiteSpace(x.Dni))
            .WithMessage("El DNI debe tener 8 dígitos");
        RuleFor(x => x.Telefono).MaximumLength(20);
        RuleFor(x => x.Foto).MaximumLength(250);
    }
}
