using Backend.Dtos.Requests;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class ListaPrecioValidator<T> : AbstractValidator<T> where T : ListaPrecioRequestBase
{
    public ListaPrecioValidator()
    {
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Descripcion).MaximumLength(250);
    }
}

public class CreateListaPrecioRequestValidator : ListaPrecioValidator<CreateListaPrecioRequest>;

public class UpdateListaPrecioRequestValidator : ListaPrecioValidator<UpdateListaPrecioRequest>;

public class GuardarPrecioRequestValidator : AbstractValidator<GuardarPrecioRequest>
{
    public GuardarPrecioRequestValidator()
    {
        RuleFor(x => x.PresentacionId)
            .GreaterThan(0).WithMessage("Elige la presentación");

        RuleFor(x => x.Precio)
            .GreaterThanOrEqualTo(0).WithMessage("El precio no puede ser negativo");

        RuleFor(x => x.CantidadMinima)
            .GreaterThan(0).WithMessage("La cantidad mínima debe ser mayor que cero");
    }
}

public class GuardarPreciosRequestValidator : AbstractValidator<GuardarPreciosRequest>
{
    public GuardarPreciosRequestValidator()
    {
        RuleForEach(x => x.Precios).SetValidator(new GuardarPrecioRequestValidator());
    }
}
