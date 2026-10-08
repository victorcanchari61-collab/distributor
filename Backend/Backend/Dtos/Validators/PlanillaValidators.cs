using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class AjustePlanillaRequestValidator : AbstractValidator<AjustePlanillaRequest>
{
    public AjustePlanillaRequestValidator()
    {
        RuleFor(x => x.Bonos).GreaterThanOrEqualTo(0).WithMessage("El bono no puede ser negativo");
        RuleFor(x => x.OtrosDescuentos).GreaterThanOrEqualTo(0).WithMessage("El descuento no puede ser negativo");
        RuleFor(x => x.Nota).MaximumLength(250);
        RuleFor(x => x.Adelantos).GreaterThanOrEqualTo(0).When(x => x.Adelantos is not null)
            .WithMessage("El descuento de adelantos no puede ser negativo");
    }
}

public class PagarPlanillaRequestValidator : AbstractValidator<PagarPlanillaRequest>
{
    public PagarPlanillaRequestValidator()
    {
        RuleFor(x => x.CuentaFinancieraId).GreaterThan(0).WithMessage("Elige de qué cuenta sale el pago");
    }
}
