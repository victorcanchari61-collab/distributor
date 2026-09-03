using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class MetodoPagoValidator<T> : AbstractValidator<T> where T : MetodoPagoRequestBase
{
    public MetodoPagoValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(60);
    }
}

public class CreateMetodoPagoRequestValidator : MetodoPagoValidator<CreateMetodoPagoRequest>;

public class UpdateMetodoPagoRequestValidator : MetodoPagoValidator<UpdateMetodoPagoRequest>;
