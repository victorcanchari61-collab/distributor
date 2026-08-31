using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CreateRolRequestValidator : AbstractValidator<CreateRolRequest>
{
    public CreateRolRequestValidator()
    {
        Include(new RolValidator());
    }
}
