using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class ClienteValidator : AbstractValidator<ClienteRequestBase>
{
    public ClienteValidator()
    {
        // El documento no siempre es RUC: hay DNI y codigos internos del
        // negocio, asi que se acepta cualquier numero de 3 a 15 digitos.
        RuleFor(x => x.Documento)
            .NotEmpty().WithMessage("Falta el documento")
            .Matches("^[0-9]{3,15}$").WithMessage("El documento debe tener entre 3 y 15 dígitos");

        // El tipo elegido manda sobre el largo: un DNI son 8 digitos y un RUC 11.
        RuleFor(x => x.TipoDoc)
            .Must(t => t is null || t is "DNI" or "RUC" or "CODIGO")
            .WithMessage("Tipo de documento no válido");

        RuleFor(x => x.Documento)
            .Length(8).When(x => x.TipoDoc == "DNI")
            .WithMessage("El DNI debe tener 8 dígitos");

        RuleFor(x => x.Documento)
            .Length(11).When(x => x.TipoDoc == "RUC")
            .WithMessage("El RUC debe tener 11 dígitos");

        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Falta el nombre").MaximumLength(150);
        RuleFor(x => x.Direccion).MaximumLength(250);
        RuleFor(x => x.Distrito).MaximumLength(80);
        RuleFor(x => x.Telefono).MaximumLength(40);
        RuleFor(x => x.DiaVisita).MaximumLength(20);
        RuleFor(x => x.Ruta).MaximumLength(20);
        RuleFor(x => x.PuntoReparto).MaximumLength(80);
        RuleFor(x => x.Email)
            .EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email))
            .MaximumLength(100);
    }
}
