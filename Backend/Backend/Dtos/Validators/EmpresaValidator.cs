using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class EmpresaValidator : AbstractValidator<EmpresaRequestBase>
{
    public EmpresaValidator()
    {
        RuleFor(x => x.RazonSocial).NotEmpty().MaximumLength(200);
        RuleFor(x => x.NombreComercial).NotEmpty().MaximumLength(150);
        RuleFor(x => x.Ruc).NotEmpty().Length(11).Matches("^[0-9]+$");
        RuleFor(x => x.Direccion).MaximumLength(250);
        RuleFor(x => x.Telefono).MaximumLength(20);
        RuleFor(x => x.Email).EmailAddress().When(x => !string.IsNullOrEmpty(x.Email)).MaximumLength(100);
        RuleFor(x => x.Departamento).MaximumLength(60);
        RuleFor(x => x.Provincia).MaximumLength(60);
        RuleFor(x => x.Distrito).MaximumLength(60);
        RuleFor(x => x.RepresentanteLegal).MaximumLength(150);

        // Se acepta con o sin http: al guardar se normaliza en el servicio.
        RuleFor(x => x.SitioWeb)
            .MaximumLength(150)
            .Matches(@"^(https?://)?([\w-]+\.)+[\w-]{2,}(/[^\s]*)?$")
            .When(x => !string.IsNullOrWhiteSpace(x.SitioWeb))
            .WithMessage("El sitio web no tiene un formato válido");
    }
}
