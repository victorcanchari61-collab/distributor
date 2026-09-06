using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CreateMercadoRequestValidator : AbstractValidator<CreateMercadoRequest>
{
    public CreateMercadoRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Falta el nombre").MaximumLength(80);
    }
}

public class UpdateMercadoRequestValidator : AbstractValidator<UpdateMercadoRequest>
{
    public UpdateMercadoRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Falta el nombre").MaximumLength(80);
    }
}
