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
        // El nombre de usuario: con al menos una letra, para que nunca se confunda con un DNI (solo digitos)
        // ni con un correo (lleva arroba).
        RuleFor(x => x.NombreUsuario)
            .Matches("^(?=.*[A-Za-z])[A-Za-z0-9._-]{3,30}$")
            .When(x => !string.IsNullOrWhiteSpace(x.NombreUsuario))
            .WithMessage("El usuario debe tener de 3 a 30 caracteres —letras, números, punto, guion— y al menos una letra");
        // Sin correo, DNI ni usuario la cuenta no tendria con que iniciar sesion.
        RuleFor(x => x)
            .Must(x => !string.IsNullOrWhiteSpace(x.Email) || !string.IsNullOrWhiteSpace(x.Dni)
                       || !string.IsNullOrWhiteSpace(x.NombreUsuario))
            .WithName("Usuario")
            .WithMessage("Ingresa el usuario, el correo o el DNI: sin uno de los tres no podrá iniciar sesión.");
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
