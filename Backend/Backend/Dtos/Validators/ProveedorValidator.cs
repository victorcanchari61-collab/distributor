using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class ProveedorValidator : AbstractValidator<ProveedorRequestBase>
{
    public ProveedorValidator()
    {
        RuleFor(x => x.Documento)
            .NotEmpty().WithMessage("Falta el documento")
            .Matches("^[0-9]{3,15}$").WithMessage("El documento debe tener entre 3 y 15 dígitos");

        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Falta la razón social").MaximumLength(200);
        RuleFor(x => x.NombreComercial).MaximumLength(150);
        RuleFor(x => x.Direccion).MaximumLength(250);
        RuleFor(x => x.Departamento).MaximumLength(80);
        RuleFor(x => x.Distrito).MaximumLength(80);
        RuleFor(x => x.Telefono).MaximumLength(40);
        RuleFor(x => x.Telefono2).MaximumLength(40);
        RuleFor(x => x.Rubro).MaximumLength(120);
        RuleFor(x => x.Email)
            .EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email))
            .MaximumLength(100);
    }
}
