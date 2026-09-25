using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CerrarCajaRequestValidator : AbstractValidator<CerrarCajaRequest>
{
    public CerrarCajaRequestValidator()
    {
        RuleFor(x => x.Billetes).GreaterThanOrEqualTo(0).WithMessage("Los billetes no pueden ser negativos");
        RuleFor(x => x.Monedas).GreaterThanOrEqualTo(0).WithMessage("Las monedas no pueden ser negativas");
        RuleFor(x => x.CuentaDestinoId).GreaterThan(0).WithMessage("Elige a quién le entregas lo contado");
        RuleFor(x => x.Observacion).MaximumLength(250);
    }
}
