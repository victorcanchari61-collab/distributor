using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class RutaValidator<T> : AbstractValidator<T> where T : RutaRequestBase
{
    public RutaValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Falta el nombre").MaximumLength(80);
    }
}

public class CreateRutaRequestValidator : RutaValidator<CreateRutaRequest>;

public class UpdateRutaRequestValidator : RutaValidator<UpdateRutaRequest>;
