using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class PresentacionRequestValidator : AbstractValidator<PresentacionRequest>
{
    public PresentacionRequestValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(80);
        RuleFor(x => x.UnidadId).GreaterThan(0).WithMessage("Elige la unidad");

        // Un factor cero o negativo romperia toda conversion de stock.
        RuleFor(x => x.Factor)
            .GreaterThan(0).WithMessage("El factor debe ser mayor que cero");

        RuleFor(x => x.CodigoBarras).MaximumLength(40);
    }
}

public class ProductoValidator<T> : AbstractValidator<T> where T : ProductoRequestBase
{
    public ProductoValidator()
    {
        RuleFor(x => x.Codigo).NotEmpty().MaximumLength(30);
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(150);
        RuleFor(x => x.Descripcion).MaximumLength(500);
        RuleFor(x => x.UnidadBaseId)
            .GreaterThan(0).WithMessage("Elige la unidad base del producto");

        RuleFor(x => x.StockMinimo)
            .GreaterThanOrEqualTo(0).WithMessage("El stock mínimo no puede ser negativo");

        RuleFor(x => x.Contenido)
            .GreaterThan(0).When(x => x.Contenido.HasValue)
            .WithMessage("El contenido debe ser mayor que cero");

        // El contenido se lee junto a su unidad: "900 ML". Uno sin el otro no
        // dice nada.
        RuleFor(x => x.ContenidoUnidadId)
            .NotNull().When(x => x.Contenido.HasValue)
            .WithMessage("Indica la unidad del contenido");
    }
}

public class CreateProductoRequestValidator : ProductoValidator<CreateProductoRequest>
{
    public CreateProductoRequestValidator()
    {
        RuleForEach(x => x.Presentaciones).SetValidator(new PresentacionRequestValidator());
    }
}

public class UpdateProductoRequestValidator : ProductoValidator<UpdateProductoRequest>;
