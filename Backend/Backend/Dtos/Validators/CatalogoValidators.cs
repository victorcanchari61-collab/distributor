using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class CategoriaValidator<T> : AbstractValidator<T> where T : CategoriaRequestBase
{
    public CategoriaValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Descripcion).MaximumLength(250);
    }
}

public class CreateCategoriaRequestValidator : CategoriaValidator<CreateCategoriaRequest>;

public class UpdateCategoriaRequestValidator : CategoriaValidator<UpdateCategoriaRequest>;

public class MarcaValidator<T> : AbstractValidator<T> where T : MarcaRequestBase
{
    public MarcaValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(80);
    }
}

public class CreateMarcaRequestValidator : MarcaValidator<CreateMarcaRequest>;

public class UpdateMarcaRequestValidator : MarcaValidator<UpdateMarcaRequest>;

public class UnidadMedidaValidator<T> : AbstractValidator<T> where T : UnidadMedidaRequestBase
{
    public UnidadMedidaValidator()
    {
        RuleFor(x => x.Codigo).NotEmpty().MaximumLength(10);
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(60);
        RuleFor(x => x.Tipo)
            .Must(t => TipoUnidad.Todos.Contains(t))
            .WithMessage("El tipo debe ser CONTEO, PESO o VOLUMEN");
    }
}

public class CreateUnidadMedidaRequestValidator : UnidadMedidaValidator<CreateUnidadMedidaRequest>;

public class UpdateUnidadMedidaRequestValidator : UnidadMedidaValidator<UpdateUnidadMedidaRequest>;
