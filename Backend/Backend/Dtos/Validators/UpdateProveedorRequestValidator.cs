using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class UpdateProveedorRequestValidator : AbstractValidator<UpdateProveedorRequest>
{
    public UpdateProveedorRequestValidator()
    {
        Include(new ProveedorValidator());
    }
}
