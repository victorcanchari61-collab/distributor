using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CrearGestionRequestValidator : AbstractValidator<CrearGestionRequest>
{
    public CrearGestionRequestValidator()
    {
        RuleFor(x => x.Tipo).Must(t => TipoGestion.Todos.Contains(t))
            .WithMessage("Elige cómo fue el contacto: llamada, visita, WhatsApp u otro");
        RuleFor(x => x.Resultado).Must(r => ResultadoGestion.Todos.Contains(r))
            .WithMessage("Elige en qué quedó el contacto");
        RuleFor(x => x.Nota).NotEmpty().WithMessage("Anota qué se habló con el cliente")
            .MaximumLength(500);
        RuleFor(x => x.ProximaAccion).MaximumLength(150);

        // La acción sin fecha se olvida, y la fecha sin acción no dice qué hacer.
        RuleFor(x => x.ProximaFecha).NotNull().When(x => !string.IsNullOrWhiteSpace(x.ProximaAccion))
            .WithMessage("Indica el día de la próxima acción");
        RuleFor(x => x.ProximaAccion).NotEmpty().When(x => x.ProximaFecha is not null)
            .WithMessage("Indica qué hay que hacer ese día");
    }
}

public class GuardarCategorizacionRequestValidator : AbstractValidator<GuardarCategorizacionRequest>
{
    public GuardarCategorizacionRequestValidator()
    {
        RuleFor(x => x.Ciclo).Must(c => CicloCategorizacion.Todos.Contains(c))
            .WithMessage("Elige el ciclo: mensual, trimestral, cuatrimestral o anual");

        RuleFor(x => x.Categorias).NotNull().Must(c => c.Count == 6)
            .WithMessage("Tienen que ser las seis categorías, de la A a la F");

        RuleForEach(x => x.Categorias).ChildRules(c =>
        {
            c.RuleFor(x => x.Nombre).NotEmpty().WithMessage("Toda categoría necesita un nombre").MaximumLength(30);
            c.RuleFor(x => x.Color).Must(color => ColorCategoria.Todos.Contains(color))
                .WithMessage("Ese color no existe");
            c.RuleFor(x => x.Desde).GreaterThanOrEqualTo(0).WithMessage("El monto no puede ser negativo");
        });
    }
}
