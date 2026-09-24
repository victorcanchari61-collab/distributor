using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class ConciliacionBancariaRequestValidator : AbstractValidator<ConciliacionBancariaRequest>
{
    public ConciliacionBancariaRequestValidator()
    {
        RuleFor(x => x.CuentaFinancieraId).GreaterThan(0).WithMessage("Elige la cuenta");
        RuleFor(x => x.Observacion).MaximumLength(250);
    }
}
