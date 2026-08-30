using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class ClienteValidator : AbstractValidator<ClienteRequestBase>
{
    public ClienteValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(150);
        RuleFor(x => x.Ruc).NotEmpty().Length(11).Matches("^[0-9]+$");
        RuleFor(x => x.Direccion).MaximumLength(250);
        RuleFor(x => x.Telefono).MaximumLength(20);
        RuleFor(x => x.Email).EmailAddress().When(x => !string.IsNullOrEmpty(x.Email)).MaximumLength(100);
    }
}
