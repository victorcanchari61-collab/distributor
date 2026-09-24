using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class GastoRecurrenteRequestValidator : AbstractValidator<GastoRecurrenteRequest>
{
    public GastoRecurrenteRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Ponle un nombre").MaximumLength(100);
        RuleFor(x => x.MotivoGastoId).GreaterThan(0).WithMessage("Elige la categoría del gasto");
        RuleFor(x => x.MontoEstimado).GreaterThan(0).WithMessage("El monto estimado tiene que ser mayor a cero");
        RuleFor(x => x.DiaVencimiento).InclusiveBetween(1, 31).WithMessage("El día de vencimiento va de 1 a 31");
    }
}

public class MovimientoOperativoRequestValidator : AbstractValidator<MovimientoOperativoRequest>
{
    public MovimientoOperativoRequestValidator()
    {
        RuleFor(x => x.CuentaFinancieraId).GreaterThan(0).WithMessage("Elige la cuenta");
        RuleFor(x => x.Tipo)
            .Must(t => t is TipoMovimientoOperativo.Ingreso or TipoMovimientoOperativo.Egreso)
            .WithMessage("El tipo debe ser INGRESO o EGRESO");
        RuleFor(x => x.MotivoGastoId).GreaterThan(0).WithMessage("Elige la categoría");
        RuleFor(x => x.Monto).GreaterThan(0).WithMessage("El monto tiene que ser mayor a cero");
        RuleFor(x => x.Descripcion).MaximumLength(250);
    }
}
