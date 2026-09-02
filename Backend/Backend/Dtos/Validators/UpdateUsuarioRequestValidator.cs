using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class UpdateUsuarioRequestValidator : AbstractValidator<UpdateUsuarioRequest>
{
    public UpdateUsuarioRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(100);
        RuleFor(x => x.RolId).GreaterThan(0).WithMessage("Selecciona un rol");
        RuleFor(x => x.Dni)
            .Matches("^[0-9]{8}$")
            .When(x => !string.IsNullOrWhiteSpace(x.Dni))
            .WithMessage("El DNI debe tener 8 dígitos");

        // Solo se valida si se envio: vacio significa "no cambiar la clave".
        RuleFor(x => x.Password)
            .MinimumLength(6).MaximumLength(100)
            .When(x => !string.IsNullOrWhiteSpace(x.Password));
    }
}
