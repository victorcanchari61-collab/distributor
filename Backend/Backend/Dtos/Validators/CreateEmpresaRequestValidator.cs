using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CreateEmpresaRequestValidator : AbstractValidator<CreateEmpresaRequest>
{
    public CreateEmpresaRequestValidator()
    {
        Include(new EmpresaValidator());
    }
}
