using Backend.Dtos.Requests;
using Backend.Models;
using FluentValidation;

namespace Backend.Dtos.Validators;

public class LineaVentaRequestValidator : AbstractValidator<LineaVentaRequest>
{
    public LineaVentaRequestValidator()
    {
        RuleFor(x => x.ProductoId).GreaterThan(0).WithMessage("Elige el producto");
        RuleFor(x => x.Cantidad).GreaterThan(0).WithMessage("La cantidad debe ser mayor que cero");
        RuleFor(x => x.PrecioUnitario).GreaterThan(0).WithMessage("Indica el precio de venta");
    }
}

public class CrearPedidoRequestValidator : AbstractValidator<CrearPedidoRequest>
{
    public CrearPedidoRequestValidator()
    {
        RuleFor(x => x.ClienteId).GreaterThan(0).WithMessage("Elige el cliente");
        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.AlmacenId)
            .NotNull().GreaterThan(0)
            .When(x => x.ReservaStock)
            .WithMessage("Elige el almacén para reservar el stock");
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaVentaRequestValidator());
    }
}

public class PagoVentaRequestValidator : AbstractValidator<PagoVentaRequest>
{
    public PagoVentaRequestValidator()
    {
        RuleFor(x => x.MetodoPagoId).GreaterThan(0).WithMessage("Elige el método de pago");
        RuleFor(x => x.Monto).GreaterThan(0).WithMessage("El monto debe ser mayor que cero");
    }
}

public class ConfirmarPedidoRequestValidator : AbstractValidator<ConfirmarPedidoRequest>
{
    public ConfirmarPedidoRequestValidator()
    {
        RuleFor(x => x.AlmacenId).GreaterThan(0).WithMessage("Elige el almacén");
    }
}

public class CrearNotaVentaRequestValidator : AbstractValidator<CrearNotaVentaRequest>
{
    public CrearNotaVentaRequestValidator()
    {
        RuleFor(x => x.ClienteId).GreaterThan(0).WithMessage("Elige el cliente");
        RuleFor(x => x.AlmacenId).GreaterThan(0).WithMessage("Elige el almacén");
        RuleFor(x => x.FormaPago)
            .Must(f => string.IsNullOrWhiteSpace(f) || FormaPagoVenta.Todas.Contains(f))
            .WithMessage("Forma de pago inválida");
        RuleForEach(x => x.Pagos).SetValidator(new PagoVentaRequestValidator());

        RuleFor(x => x.Observacion).MaximumLength(250);
        RuleFor(x => x.Detalle).NotEmpty().WithMessage("Agrega al menos un producto");
        RuleForEach(x => x.Detalle).SetValidator(new LineaVentaRequestValidator());
    }
}
