using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class AlmacenValidator<T> : AbstractValidator<T> where T : AlmacenRequestBase
{
    public AlmacenValidator()
    {
        RuleFor(x => x.Codigo).NotEmpty().MaximumLength(15);
        RuleFor(x => x.Nombre).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Direccion).MaximumLength(250);
    }
}

public class CreateAlmacenRequestValidator : AlmacenValidator<CreateAlmacenRequest>;

public class UpdateAlmacenRequestValidator : AlmacenValidator<UpdateAlmacenRequest>;

public class EntradaRequestValidator : AbstractValidator<EntradaRequest>
{
    public EntradaRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");

        RuleFor(x => x.Cantidad)
            .GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");

        // Cero es legítimo: mercadería de muestra o una bonificación.
        RuleFor(x => x.CostoTotal)
            .GreaterThanOrEqualTo(0).WithMessage("El costo no puede ser negativo");

        RuleFor(x => x.Flete)
            .GreaterThanOrEqualTo(0).WithMessage("El flete no puede ser negativo");

        RuleFor(x => x.Referencia).MaximumLength(60);

        RuleFor(x => x.Origen)
            .Must(o => OrigenCapa.Todos.Contains(o))
            .WithMessage("El origen debe ser SALDO_INICIAL, COMPRA o AJUSTE");
    }
}

public class SalidaRequestValidator : AbstractValidator<SalidaRequest>
{
    public SalidaRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
        RuleFor(x => x.Cantidad)
            .GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");
        RuleFor(x => x.Referencia).MaximumLength(60);
    }
}
