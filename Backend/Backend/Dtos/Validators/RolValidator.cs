using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class RolValidator : AbstractValidator<RolRequestBase>
{
    public RolValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(60);
        RuleFor(x => x.Descripcion).MaximumLength(250);
    }
}
