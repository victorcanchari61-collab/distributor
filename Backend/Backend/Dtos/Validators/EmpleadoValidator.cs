using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class EmpleadoValidator : AbstractValidator<EmpleadoRequestBase>
{
    public EmpleadoValidator()
    {
        RuleFor(x => x.Documento)
            .NotEmpty().WithMessage("Falta el documento")
            .Matches("^[0-9A-Za-z-]{3,15}$").WithMessage("El documento tiene entre 3 y 15 caracteres");

        // Un empleado es una persona: RUC no aplica, y el carné de extranjería entra como CODIGO.
        RuleFor(x => x.TipoDoc)
            .Must(t => t is null || t is "DNI" or "CODIGO")
            .WithMessage("Tipo de documento no válido");

        RuleFor(x => x.Documento)
            .Length(8).When(x => x.TipoDoc == "DNI")
            .WithMessage("El DNI debe tener 8 dígitos");

        RuleFor(x => x.Nombres).NotEmpty().WithMessage("Faltan los nombres").MaximumLength(100);
        RuleFor(x => x.Apellidos).NotEmpty().WithMessage("Faltan los apellidos").MaximumLength(100);

        RuleFor(x => x.Telefono).MaximumLength(40);
        RuleFor(x => x.Direccion).MaximumLength(250);
        RuleFor(x => x.Cargo).MaximumLength(80);
        RuleFor(x => x.Area).MaximumLength(80);
        RuleFor(x => x.Observacion).MaximumLength(500);

        RuleFor(x => x.Email)
            .EmailAddress().When(x => !string.IsNullOrWhiteSpace(x.Email))
            .MaximumLength(100);

        // Cesar antes de entrar no es un caso raro: es un dato mal tecleado.
        RuleFor(x => x.FechaCese)
            .GreaterThanOrEqualTo(x => x.FechaIngreso!.Value)
            .When(x => x.FechaIngreso is not null && x.FechaCese is not null)
            .WithMessage("La fecha de cese no puede ser anterior a la de ingreso");
    }
}

public class CreateEmpleadoRequestValidator : AbstractValidator<CreateEmpleadoRequest>
{
    public CreateEmpleadoRequestValidator()
    {
        Include(new EmpleadoValidator());
    }
}

public class UpdateEmpleadoRequestValidator : AbstractValidator<UpdateEmpleadoRequest>
{
    public UpdateEmpleadoRequestValidator()
    {
        Include(new EmpleadoValidator());
    }
}
