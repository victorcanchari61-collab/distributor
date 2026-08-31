using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class UpdateEmpresaRequestValidator : AbstractValidator<UpdateEmpresaRequest>
{
    public UpdateEmpresaRequestValidator()
    {
        Include(new EmpresaValidator());
    }
}
