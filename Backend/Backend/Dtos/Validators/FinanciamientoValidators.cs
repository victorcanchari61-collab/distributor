using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CrearFinanciamientoRequestValidator : AbstractValidator<CrearFinanciamientoRequest>
{
    public CrearFinanciamientoRequestValidator()
    {
        RuleFor(x => x.Acreedor).NotEmpty().WithMessage("Indica quién te prestó").MaximumLength(120);
        RuleFor(x => x.Descripcion).MaximumLength(250);
        RuleFor(x => x.MontoRecibido).GreaterThan(0).WithMessage("El monto recibido tiene que ser mayor a cero");
        RuleFor(x => x.TotalADevolver)
            .GreaterThanOrEqualTo(x => x.MontoRecibido)
            .When(x => x.TotalADevolver is not null)
            .WithMessage("Lo que se devuelve no puede ser menos de lo que se recibió");
        RuleFor(x => x.CuentaFinancieraId).GreaterThan(0).WithMessage("Elige a qué cuenta entró la plata");
    }
}

public class PagoFinanciamientoRequestValidator : AbstractValidator<PagoFinanciamientoRequest>
{
    public PagoFinanciamientoRequestValidator()
    {
        RuleFor(x => x.Monto).GreaterThan(0).WithMessage("El pago tiene que ser mayor a cero");
        RuleFor(x => x.CuentaFinancieraId).GreaterThan(0).WithMessage("Elige de qué cuenta sale el pago");
        RuleFor(x => x.Observacion).MaximumLength(250);
    }
}
