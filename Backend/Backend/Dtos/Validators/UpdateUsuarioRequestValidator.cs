using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class UpdateUsuarioRequestValidator : AbstractValidator<UpdateUsuarioRequest>
{
    public UpdateUsuarioRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(100);
        // El correo es opcional; si viene, tiene que ser un correo.
        RuleFor(x => x.Email).EmailAddress().MaximumLength(100).When(x => !string.IsNullOrWhiteSpace(x.Email));
        // Pero sin correo ni DNI la cuenta no tendria con que iniciar sesion.
        RuleFor(x => x)
            .Must(x => !string.IsNullOrWhiteSpace(x.Email) || !string.IsNullOrWhiteSpace(x.Dni))
            .WithName("Correo")
            .WithMessage("Ingresa el correo o el DNI: sin uno de los dos no podrá iniciar sesión.");
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
