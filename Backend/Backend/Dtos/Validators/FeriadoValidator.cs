using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class FeriadoRequestValidator : AbstractValidator<FeriadoRequest>
{
    public FeriadoRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Falta el nombre").MaximumLength(100);
    }
}
