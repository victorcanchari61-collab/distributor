using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class BancoRequestValidator : AbstractValidator<BancoRequest>
{
    public BancoRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Ponle un nombre al banco").MaximumLength(60);
    }
}
