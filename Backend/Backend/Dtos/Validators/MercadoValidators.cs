using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class MercadoValidator<T> : AbstractValidator<T> where T : MercadoRequestBase
{
    public MercadoValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Falta el nombre").MaximumLength(80);
        RuleFor(x => x.Direccion).MaximumLength(250);
        RuleFor(x => x.Distrito).MaximumLength(80);
    }
}

public class CreateMercadoRequestValidator : MercadoValidator<CreateMercadoRequest>;

public class UpdateMercadoRequestValidator : MercadoValidator<UpdateMercadoRequest>;
