using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CrearAsistenciaRequestValidator : AbstractValidator<CrearAsistenciaRequest>
{
    public CrearAsistenciaRequestValidator()
    {
        RuleFor(x => x.EmpleadoId).GreaterThan(0).WithMessage("Elige el empleado");

        RuleFor(x => x.Fecha)
            .LessThanOrEqualTo(_ => Zona.Hoy)
            .WithMessage("No se puede marcar asistencia de un día que no ha llegado");

        RuleFor(x => x.Estado)
            .Must(e => EstadoAsistencia.Todos.Contains(e))
            .WithMessage("Estado no válido");

        RuleFor(x => x.Observacion).MaximumLength(300);
    }
}

public class EditarAsistenciaRequestValidator : AbstractValidator<EditarAsistenciaRequest>
{
    public EditarAsistenciaRequestValidator()
    {
        RuleFor(x => x.Estado)
            .Must(e => EstadoAsistencia.Todos.Contains(e))
            .WithMessage("Estado no válido");

        RuleFor(x => x.Observacion).MaximumLength(300);
    }
}

public class MarcarDiaAsistenciaRequestValidator : AbstractValidator<MarcarDiaAsistenciaRequest>
{
    public MarcarDiaAsistenciaRequestValidator()
    {
        RuleFor(x => x.Fecha)
            .LessThanOrEqualTo(_ => Zona.Hoy)
            .WithMessage("No se puede marcar asistencia de un día que no ha llegado");

        RuleFor(x => x.Marcas).NotEmpty().WithMessage("Marca al menos a un empleado");

        RuleFor(x => x.Marcas)
            .Must(m => m.Select(x => x.EmpleadoId).Distinct().Count() == m.Count)
            .WithMessage("Un empleado aparece dos veces en la lista");

        RuleForEach(x => x.Marcas).ChildRules(marca =>
        {
            marca.RuleFor(m => m.EmpleadoId).GreaterThan(0).WithMessage("Falta el empleado");
            marca.RuleFor(m => m.Estado)
                .Must(e => EstadoAsistencia.Todos.Contains(e))
                .WithMessage("Estado no válido");
            marca.RuleFor(m => m.Observacion).MaximumLength(300);
        });
    }
}
