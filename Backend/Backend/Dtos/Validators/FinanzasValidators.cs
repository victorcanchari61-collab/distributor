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

        // El efectivo no pide banco ni cuenta: no hay a donde depositar.
        RuleFor(x => x.Banco)
            .NotEmpty().WithMessage("Indica el banco")
            .When(x => x.Tipo == TipoMetodoPago.Transferencia);

        RuleFor(x => x.NumeroCuenta)
            .NotEmpty().WithMessage("Indica el número de cuenta o de celular")
            .When(x => x.Tipo is TipoMetodoPago.Transferencia or TipoMetodoPago.BilleteraDigital);

        RuleFor(x => x.Banco).MaximumLength(60);
        RuleFor(x => x.NumeroCuenta).MaximumLength(30);
        RuleFor(x => x.Cci).MaximumLength(30);
        RuleFor(x => x.Titular).MaximumLength(120);
    }
}

public class CreateMetodoPagoRequestValidator : MetodoPagoValidator<CreateMetodoPagoRequest>;

public class UpdateMetodoPagoRequestValidator : MetodoPagoValidator<UpdateMetodoPagoRequest>;
