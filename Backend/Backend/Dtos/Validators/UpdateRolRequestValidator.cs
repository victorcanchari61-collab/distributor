using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class UpdateRolRequestValidator : AbstractValidator<UpdateRolRequest>
{
    public UpdateRolRequestValidator()
    {
        Include(new RolValidator());
    }
}
