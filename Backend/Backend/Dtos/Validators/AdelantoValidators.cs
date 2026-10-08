using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CrearAdelantoRequestValidator : AbstractValidator<CrearAdelantoRequest>
{
    public CrearAdelantoRequestValidator()
    {
        RuleFor(x => x.EmpleadoId).GreaterThan(0).WithMessage("Elige a quién se le da el adelanto");
        RuleFor(x => x.Monto).GreaterThan(0).WithMessage("El monto tiene que ser mayor a cero");
        RuleFor(x => x.CuentaFinancieraId).GreaterThan(0).WithMessage("Elige de qué cuenta sale la plata");
        RuleFor(x => x.CuotaSemanal).GreaterThan(0).When(x => x.CuotaSemanal is not null)
            .WithMessage("La cuota semanal tiene que ser mayor a cero");
        RuleFor(x => x.Observacion).MaximumLength(250);
    }
}

public class PlanAdelantoRequestValidator : AbstractValidator<PlanAdelantoRequest>
{
    public PlanAdelantoRequestValidator()
    {
        RuleFor(x => x.DescontarDesde).NotEmpty().WithMessage("Indica desde qué semana se descuenta");
        RuleFor(x => x.CuotaSemanal).GreaterThan(0).When(x => x.CuotaSemanal is not null)
            .WithMessage("La cuota semanal tiene que ser mayor a cero");
    }
}
