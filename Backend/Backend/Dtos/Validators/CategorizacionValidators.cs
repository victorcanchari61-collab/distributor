using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CategoriaClienteRequestValidator : AbstractValidator<CategoriaClienteRequest>
{
    public CategoriaClienteRequestValidator()
    {
        RuleFor(x => x.Codigo).NotEmpty().WithMessage("Falta el código de la categoría");
        RuleFor(x => x.Nombre).NotEmpty().WithMessage("Toda categoría necesita un nombre").MaximumLength(30);
        RuleFor(x => x.Color).Must(c => ColorCategoria.Todos.Contains(c))
            .WithMessage("Ese color no existe");
        RuleFor(x => x.Desde).GreaterThanOrEqualTo(0).WithMessage("Los montos tienen que ser desde 0");
    }
}

public class GuardarCategorizacionRequestValidator : AbstractValidator<GuardarCategorizacionRequest>
{
    public GuardarCategorizacionRequestValidator()
    {
        RuleFor(x => x.Ciclo).Must(c => CicloCategorizacion.Todos.Contains(c))
            .WithMessage("El ciclo tiene que ser mensual, trimestral, cuatrimestral o anual");
        RuleFor(x => x.Categorias).NotEmpty().WithMessage("Faltan las categorías");
        RuleForEach(x => x.Categorias).SetValidator(new CategoriaClienteRequestValidator());
    }
}
