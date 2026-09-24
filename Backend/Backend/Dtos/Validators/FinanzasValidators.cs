using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class MetodoPagoValidator<T> : AbstractValidator<T> where T : MetodoPagoRequestBase
{
    public MetodoPagoValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(60);
        RuleFor(x => x.Tipo)
            .Must(t => TipoMetodoPago.Todos.Contains(t))
            .WithMessage("El tipo debe ser EFECTIVO, BILLETERA_DIGITAL o TRANSFERENCIA");

        // El efectivo no apunta a ninguna cuenta fija (se resuelve segun quien
        // cobra); los demas SI necesitan saber a que cuenta va la plata.
        RuleFor(x => x.CuentaFinancieraId)
            .NotNull().WithMessage("Elige a qué cuenta financiera va este método")
            .When(x => x.Tipo != TipoMetodoPago.Efectivo);

        RuleFor(x => x.CuentaFinancieraId)
            .Null().WithMessage("Efectivo no se enlaza a ninguna cuenta")
            .When(x => x.Tipo == TipoMetodoPago.Efectivo);
    }
}

public class CreateMetodoPagoRequestValidator : MetodoPagoValidator<CreateMetodoPagoRequest>;

public class UpdateMetodoPagoRequestValidator : MetodoPagoValidator<UpdateMetodoPagoRequest>;
